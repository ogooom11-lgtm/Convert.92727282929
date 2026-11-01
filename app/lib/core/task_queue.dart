import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'capabilities.dart';
import 'command_builder.dart';
import 'process_runner.dart';
import 'tool_registry.dart';

enum TaskState { queued, running, done, failed, cancelled }

/// مهمة واحدة في الطابور.
class ConvertTask {
  ConvertTask({
    required this.id,
    required this.operation,
    required this.inputs,
    required this.options,
    required this.outputFolder,
  });

  final int id;
  final ConvertOperation operation;
  final List<String> inputs;
  final Map<OptionField, String> options;
  final String outputFolder;

  TaskState state = TaskState.queued;
  String outputPath = '';
  String error = '';
  Duration elapsed = Duration.zero;
  String lastLine = '';

  String get title => inputs.length == 1
      ? CommandBuilder.baseName(inputs.first)
      : '${CommandBuilder.baseName(inputs.first)} +${inputs.length - 1}';

  bool get isFinished =>
      state == TaskState.done ||
      state == TaskState.failed ||
      state == TaskState.cancelled;

  bool get isOk => state == TaskState.done;
}

/// طابور المهام — مهمة واحدة في كل مرة، بلا توازٍ.
///
/// الأدوات الثقيلة (LibreOffice وFFmpeg) تستهلك كل الذاكرة تقريبًا؛
/// التوازي هنا لا يضيف سرعة، بل يضيف أعطالًا.
class TaskQueue extends ChangeNotifier {
  TaskQueue({
    required this.registry,
    required this.builder,
    ProcessRunner? runner,
  }) : _runner = runner ?? ProcessRunner();

  final ToolRegistry registry;
  final CommandBuilder builder;
  final ProcessRunner _runner;

  final List<ConvertTask> _tasks = [];
  int _nextId = 1;
  bool _isRunning = false;
  ConvertTask? _active;

  List<ConvertTask> get tasks => List.unmodifiable(_tasks);
  bool get isRunning => _isRunning;
  ConvertTask? get active => _active;

  int get queuedCount =>
      _tasks.where((t) => t.state == TaskState.queued).length;
  int get doneCount => _tasks.where((t) => t.state == TaskState.done).length;
  int get failedCount =>
      _tasks.where((t) => t.state == TaskState.failed).length;

  /// يُستدعى عند انتهاء كل مهمة — للتنبيهات.
  void Function(ConvertTask task)? onTaskFinished;

  void enqueue(
    ConvertOperation operation,
    List<String> inputs, {
    required Map<OptionField, String> options,
    required String outputFolder,
  }) {
    final task = ConvertTask(
      id: _nextId++,
      operation: operation,
      inputs: List.unmodifiable(inputs),
      options: Map.unmodifiable(options),
      outputFolder: outputFolder,
    );
    _tasks.insert(0, task);
    notifyListeners();
    unawaited(_pump());
  }

  /// إضافة دفعة من المهام (ملفات متعددة بنفس العملية).
  void enqueueMany(
    ConvertOperation operation,
    List<String> inputs, {
    required Map<OptionField, String> options,
    required String outputFolder,
  }) {
    for (final input in inputs) {
      final task = ConvertTask(
        id: _nextId++,
        operation: operation,
        inputs: [input],
        options: Map.unmodifiable(options),
        outputFolder: outputFolder,
      );
      _tasks.insert(0, task);
    }
    notifyListeners();
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();
    try {
      while (true) {
        final next = _nextQueued();
        if (next == null) break;
        _active = next;
        notifyListeners();
        await _execute(next);
        _active = null;
        notifyListeners();
      }
    } finally {
      _isRunning = false;
      _active = null;
      notifyListeners();
    }
  }

  ConvertTask? _nextQueued() {
    // ننفّذ الأقدم أولًا (الطابور FIFO، والعرض الأحدث في الأعلى).
    ConvertTask? candidate;
    for (final task in _tasks) {
      if (task.state == TaskState.queued) {
        if (candidate == null || task.id < candidate.id) candidate = task;
      }
    }
    return candidate;
  }

  Future<void> _execute(ConvertTask task) async {
    task.state = TaskState.running;
    notifyListeners();

    final built = builder.build(
      operation: task.operation,
      inputs: task.inputs,
      options: task.options,
      outputFolder: task.outputFolder,
    );

    if (built.plan == null) {
      task.state = TaskState.failed;
      task.error = built.error ?? 'تعذّر تجهيز الأمر.';
      onTaskFinished?.call(task);
      notifyListeners();
      return;
    }

    final plan = built.plan!;
    final result = await _runner.run(
      plan.executable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      onLine: (line) {
        task.lastLine = line.length > 120 ? line.substring(0, 120) : line;
      },
    );
    task.elapsed = result.outcome.duration;

    if (result.outcome.cancelled) {
      task.state = TaskState.cancelled;
      task.error = 'أُلغي بواسطتك.';
    } else if (result.outcome.timedOut) {
      task.state = TaskState.failed;
      task.error = 'توقفت العملية بعد ${result.outcome.duration.inMinutes} دقيقة '
          '(مهلة الأدوات الثقيلة).';
    } else if (result.outcome.exitCode != 0) {
      task.state = TaskState.failed;
      task.error = result.outcome.errorExcerpt;
    } else {
      final produced = _collectOutput(plan, task);
      if (produced == null) {
        task.state = TaskState.failed;
        task.error = 'انتهت الأداة بنجاح لكن لم يُعثر على الملف الناتج. '
            'تحقق من رسالة الأداة: ${result.outcome.errorExcerpt}';
      } else {
        task.state = TaskState.done;
        task.outputPath = produced;
      }
    }

    // تنظيف المجلدات المؤقتة دائمًا — نجحت العملية أو فشلت.
    for (final dir in plan.cleanupTempDirs) {
      try {
        final directory = Directory(dir);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      } on FileSystemException {
        // تجاهل: ملف مقفل من الأداة.
      }
    }

    if (task.state != TaskState.done) {
      // لا نترك ملفات نصف مكتملة.
      _cleanupPartial(plan);
    }

    onTaskFinished?.call(task);
    notifyListeners();
  }

  String? _collectOutput(CommandPlan plan, ConvertTask task) {
    final staging = plan.stagingDir;
    if (staging != null) {
      final dir = Directory(staging);
      if (!dir.existsSync()) return null;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => !f.path.endsWith('.lock'))
          .toList();
      if (files.isEmpty) return null;
      final produced = files.first;
      try {
        produced.copySync(plan.outputPath);
        return plan.outputPath;
      } on FileSystemException {
        return null;
      }
    }
    if (plan.outputIsFolder) {
      return Directory(plan.outputPath).existsSync() ? plan.outputPath : null;
    }
    return File(plan.outputPath).existsSync() ? plan.outputPath : null;
  }

  void _cleanupPartial(CommandPlan plan) {
    try {
      if (plan.outputIsFolder) return;
      final file = File(plan.outputPath);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // لا نُسقط الطابور بسبب ملف مقفل.
    }
  }

  /// إلغاء المهمة الجارية (البديل الصحيح للإيقاف المؤقت).
  void cancelActive() {
    _runner.cancel();
  }

  /// إلغاء كل ما في الانتظار.
  void cancelQueued() {
    for (final task in _tasks) {
      if (task.state == TaskState.queued) {
        task.state = TaskState.cancelled;
        task.error = 'أُلغيت قبل البدء.';
      }
    }
    notifyListeners();
  }

  void cancelTask(ConvertTask task) {
    if (task == _active) {
      _runner.cancel();
      return;
    }
    if (task.state == TaskState.queued) {
      task.state = TaskState.cancelled;
      task.error = 'أُلغيت قبل البدء.';
      notifyListeners();
    }
  }

  /// إعادة محاولة مهمة فاشلة بنفس الإعدادات.
  void retry(ConvertTask task) {
    if (task.state != TaskState.failed && task.state != TaskState.cancelled) {
      return;
    }
    final copy = ConvertTask(
      id: _nextId++,
      operation: task.operation,
      inputs: task.inputs,
      options: task.options,
      outputFolder: task.outputFolder,
    );
    _tasks.insert(0, copy);
    notifyListeners();
    unawaited(_pump());
  }

  void clearFinished() {
    _tasks.removeWhere((t) => t.isFinished && t != _active);
    notifyListeners();
  }

  void removeTask(ConvertTask task) {
    if (task == _active) {
      cancelTask(task);
      return;
    }
    _tasks.remove(task);
    notifyListeners();
  }
}
