import 'dart:convert';
import 'dart:io';

import 'capabilities.dart';
import 'platform.dart';
import 'process_runner.dart';

enum ToolState { checking, ready, missing, broken }

/// حالة أداة واحدة بعد الفحص.
class ToolStatus {
  ToolStatus({
    required this.id,
    required this.state,
    this.executablePath = '',
    this.detail = '',
  });

  final ToolId id;
  final ToolState state;
  final String executablePath;
  final String detail;

  bool get isReady => state == ToolState.ready;
  String get message => switch (state) {
        ToolState.checking => 'جارٍ الفحص…',
        ToolState.ready => detail.isEmpty ? 'جاهزة' : detail,
        ToolState.missing => 'غير موجودة في مجلد tools',
        ToolState.broken => detail.isEmpty ? 'لا تعمل' : detail,
      };
}

/// فاحص الأدوات.
///
/// عند الإقلاع يبحث عن الملفات التنفيذية الثمانية (سبع أدوات + ffprobe)
/// داخل مجلد tools، ويشغّل أمر إصدار لكل واحدة. أي أداة لا تعمل تُخفى
/// عملياتها من الواجهة — فلا وعود كاذبة.
class ToolRegistry {
  ToolRegistry({ProcessRunner? runner}) : _runner = runner ?? ProcessRunner();

  final ProcessRunner _runner;
  final Map<ToolId, ToolStatus> _statuses = {
    for (final tool in ToolId.values)
      tool: ToolStatus(id: tool, state: ToolState.checking),
  };

  String toolsDir = '';

  Map<ToolId, ToolStatus> get statuses => Map.unmodifiable(_statuses);

  ToolStatus statusOf(ToolId tool) =>
      _statuses[tool] ?? ToolStatus(id: tool, state: ToolState.missing);

  bool isToolReady(ToolId tool) => statusOf(tool).isReady;

  /// بحث داخل مجلد الأدوات — يتحمّل البناءات المحمولة التي تضع الملفات
  /// داخل مجلدات فرعية (bin أو gs-bin أو poppler-bin…).
  ///
  /// الترتيب: الجذر أولًا، ثم اسم مجلد مرجَّح لكل أداة، ثم بحث عميق.
  String? _locate(ToolId tool, String root) {
    final executable = tool.executable;
    final sep = Platform.pathSeparator;
    final direct = File('$root$sep$executable');
    if (direct.existsSync()) return direct.path;

    final dir = Directory(root);
    if (!dir.existsSync()) return null;

    // مجلدات تُفضَّل عند التكرار (Ghostscript وPoppler يأتيان داخل مجلدات).
    final preferred = _preferredHint(tool);
    if (preferred != null) {
      final hinted = Directory('$root$sep$preferred');
      if (hinted.existsSync()) {
        final found = _search(hinted, executable);
        if (found != null) return found;
      }
    }

    return _search(dir, executable);
  }

  String? _preferredHint(ToolId tool) => switch (tool) {
        ToolId.ghostscript => 'gs-bin',
        ToolId.poppler => 'poppler-bin',
        _ => null,
      };

  String? _search(Directory dir, String executable) {
    try {
      final entities = dir.listSync(recursive: true, followLinks: false)
        ..sort((a, b) => a.path.length.compareTo(b.path.length));
      for (final entity in entities) {
        if (entity is File &&
            entity.uri.pathSegments.isNotEmpty &&
            entity.uri.pathSegments.last.toLowerCase() ==
                executable.toLowerCase()) {
          return entity.path;
        }
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }

  Future<void> scan({void Function(ToolId tool, ToolStatus status)? onUpdate}) async {
    toolsDir = PlatformInfo.resolveToolsDir();

    await Future.wait(ToolId.values.map((tool) async {
      final path = _locate(tool, toolsDir);
      if (path == null) {
        _statuses[tool] = ToolStatus(id: tool, state: ToolState.missing);
        onUpdate?.call(tool, _statuses[tool]!);
        return;
      }

      final args = _versionArgs(tool);
      final result = await _runner.run(path, args, timeout: const Duration(seconds: 25));
      final output = '${result.stdoutText} ${result.stderrText}'.trim();
      String detail;
      ToolState state;
      if (result.outcome.timedOut) {
        state = ToolState.broken;
        detail = 'لم تستجب خلال ٢٥ ثانية';
      } else if (result.outcome.exitCode != 0 && output.isEmpty) {
        state = ToolState.broken;
        detail = 'رمز خروج ${result.outcome.exitCode}';
      } else {
        state = ToolState.ready;
        detail = _firstMeaningfulLine(output);
      }
      _statuses[tool] = ToolStatus(
        id: tool,
        state: state,
        executablePath: path,
        detail: detail,
      );
      onUpdate?.call(tool, _statuses[tool]!);
    }));
  }

  List<String> _versionArgs(ToolId tool) {
    switch (tool) {
      case ToolId.ffmpeg:
      case ToolId.ffprobe:
        return ['-hide_banner', '-version'];
      case ToolId.imagemagick:
        return ['-version'];
      case ToolId.libreoffice:
        return ['--version'];
      case ToolId.sevenZip:
        return ['i'];
      case ToolId.qpdf:
        return ['--version'];
      case ToolId.ghostscript:
        // إصدار Ghostscript يخرج على stderr مع رمز نجاح.
        return ['--version'];
      case ToolId.poppler:
        return ['-v'];
    }
  }

  String _firstMeaningfulLine(String text) {
    if (text.isEmpty) return '';
    final lines = const LineSplitter()
        .convert(text)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    return lines.first.length > 60 ? lines.first.substring(0, 60) : lines.first;
  }

  /// هل العملية جاهزة؟ (أداتها موجودة وتعمل)
  bool isOperationReady(ConvertOperation op) => isToolReady(op.tool);

  /// العمليات المتاحة الآن لفئة معيّنة.
  List<ConvertOperation> availableOperationsFor(FileCategory category) =>
      operationsFor(category).where(isOperationReady).toList(growable: false);

  /// الأدوات الناقصة كقائمة نصية موجزة.
  List<ToolId> get missingTools => _statuses.entries
      .where((e) => !e.value.isReady)
      .map((e) => e.key)
      .toList(growable: false);

  /// ملخص قصير لشاشة الإعدادات.
  int get readyCount => _statuses.values.where((s) => s.isReady).length;
  int get totalCount => ToolId.values.length;
}
