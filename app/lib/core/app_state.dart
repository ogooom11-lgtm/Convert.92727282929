import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'capabilities.dart';
import 'command_builder.dart';
import 'desktop_channel.dart';
import 'file_entry.dart';
import 'platform.dart';
import 'task_queue.dart';
import 'tool_registry.dart';

/// حالة التطبيق كاملة: الملفات، الاختيار، الطابور، الأدوات، الإعدادات.
class AppState extends ChangeNotifier {
  AppState._(this.settings);

  final AppSettings settings;
  final ToolRegistry registry = ToolRegistry();
  final DesktopBridge bridge = DesktopBridge();
  late final TaskQueue queue = TaskQueue(
    registry: registry,
    builder: CommandBuilder(
      registry: registry,
      outputDirResolver: _defaultOutputDir,
    ),
  );

  final List<FileEntry> _files = [];
  final Set<String> _paths = {};
  ConvertOperation? _operation;
  final Map<OptionField, String> _options = {};
  String? _customOutputFolder;
  bool _scanning = true;
  int _healthCheckTick = 0;

  static Future<AppState> bootstrap() async {
    final settings = await AppSettings.load();
    final state = AppState._(settings);
    await state._init();
    return state;
  }

  Future<void> _init() async {
    bridge.onFilesDropped = addPaths;
    await refreshTools();
  }

  // ── الملفات ────────────────────────────────────────────────────
  List<FileEntry> get files => List.unmodifiable(_files);
  bool get hasFiles => _files.isNotEmpty;
  bool get isScanning => _scanning;

  /// الفئة الغالبة — أول ملف مُضاف.
  FileCategory? get activeCategory =>
      _files.isEmpty ? null : _files.first.category;

  /// العمليات المتاحة للاختيار الحالي (بحسب الأدوات الجاهزة).
  List<ConvertOperation> get availableOperations {
    final category = activeCategory;
    if (category == null) return const [];
    return registry.availableOperationsFor(category).where((op) {
      if (op.id == 'archive-zip' ||
          op.id == 'archive-7z' ||
          op.id == 'pdf-merge' ||
          op.id == 'video-merge' ||
          op.id == 'images-pdf') {
        // العمليات الجماعية تحتاج ملفين على الأقل.
        return _files.length >= 2;
      }
      if (op.multiInput) return _files.length >= 1;
      return true;
    }).toList(growable: false);
  }

  ConvertOperation? get operation => _operation;
  Map<OptionField, String> get options => Map.unmodifiable(_options);

  /// عدد العمليات الممكنة حاليًا (للإحصاءات).
  int get operationsAvailableCount {
    final category = activeCategory;
    if (category == null) return 0;
    return registry.availableOperationsFor(category).length;
  }

  int get readyTools => registry.readyCount;
  int get totalTools => registry.totalCount;

  String get outputFolder => _customOutputFolder ??
      (settings.saveBesideSource ? '' : settings.outputFolder);

  bool get outputIsCustom => outputFolder.isNotEmpty;

  String get outputFolderLabel {
    if (outputFolder.isNotEmpty) return outputFolder;
    if (_files.isEmpty) return 'بجوار كل ملف أصلي';
    return _files.first.folder;
  }

  /// إضافة مسارات (من السحب أو من زر الاختيار).
  /// تعيد عدد الملفات التي أُضيفت وعدد التي رُفضت.
  ({int added, int rejected, int duplicates}) addPaths(
    List<String> paths, {
    bool replace = false,
  }) {
    if (replace) clearFiles(notify: false);
    var added = 0;
    var rejected = 0;
    var duplicates = 0;
    for (final path in paths) {
      // سحب مجلد: نضيف ملفاته المدعومة (مستوى واحد).
      if (Directory(path).existsSync()) {
        try {
          for (final entity in Directory(path).listSync()) {
            if (entity is! File) continue;
            final entry = FileEntry.fromPath(entity.path);
            if (entry == null) {
              rejected++;
              continue;
            }
            if (_paths.contains(entry.path)) {
              duplicates++;
              continue;
            }
            _paths.add(entry.path);
            _files.add(entry);
            added++;
          }
        } on FileSystemException {
          rejected++;
        }
        continue;
      }
      final entry = FileEntry.fromPath(path);
      if (entry == null) {
        rejected++;
        continue;
      }
      if (_paths.contains(entry.path)) {
        duplicates++;
        continue;
      }
      _paths.add(entry.path);
      _files.add(entry);
      added++;
    }

    if (added > 0) {
      _pruneSelection();
    }
    notifyListeners();
    return (added: added, rejected: rejected, duplicates: duplicates);
  }

  void removeFile(FileEntry entry) {
    _files.remove(entry);
    _paths.remove(entry.path);
    _pruneSelection();
    notifyListeners();
  }

  void clearFiles({bool notify = true}) {
    _files.clear();
    _paths.clear();
    _operation = null;
    _options.clear();
    if (notify) notifyListeners();
  }

  /// إعادة ترتيب الملفات (يؤثر على ترتيب الدمج).
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final entry = _files.removeAt(oldIndex);
    _files.insert(newIndex, entry);
    notifyListeners();
  }

  /// إبقاء الاختيار متسقًا مع الملفات الموجودة.
  void _pruneSelection() {
    final category = activeCategory;
    if (category == null) {
      _operation = null;
      _options.clear();
      return;
    }
    final available = availableOperations;
    if (_operation != null && !available.any((op) => op.id == _operation!.id)) {
      _operation = available.isNotEmpty ? available.first : null;
      _options.clear();
    }
    if (_operation == null && available.isNotEmpty) {
      _operation = available.first;
    }
  }

  void selectOperation(ConvertOperation operation) {
    _operation = operation;
    _options.removeWhere((field, _) =>
        operation.option == null || operation.option!.field != field);
    notifyListeners();
  }

  void setOption(OptionField field, String value) {
    _options[field] = value;
    notifyListeners();
  }

  Future<void> setOutputFolder(String folder) async {
    _customOutputFolder = folder.isEmpty ? null : folder;
    notifyListeners();
    await settings.setOutputFolder(folder);
  }

  Future<void> chooseOutputFolder() async {
    final folder = await bridge.pickFolder();
    if (folder != null && folder.isNotEmpty) {
      await setOutputFolder(folder);
    }
  }

  String _defaultOutputDir() {
    final custom = outputFolder;
    if (custom.isNotEmpty) return custom;
    if (_files.isEmpty) return Directory.current.path;
    return '${_files.first.folder}${Platform.pathSeparator}Convert-out';
  }

  /// مجلد النتائج الفعلي لهذه الدفعة.
  String effectiveOutputDir() => _defaultOutputDir();

  // ── التسجيل في الطابور ────────────────────────────────────────
  /// يعيد عدد المهام التي أُضيفت، أو رسالة خطأ.
  ({int count, String? error}) submit() {
    final op = _operation;
    if (op == null) return (count: 0, error: 'اختر عملية أولًا.');
    if (_files.isEmpty) return (count: 0, error: 'أضف ملفًا واحدًا على الأقل.');

    if (!registry.isOperationReady(op)) {
      return (
        count: 0,
        error: 'الأداة المطلوبة (${op.tool.label}) غير متاحة. '
            'ضع ملفاتها في مجلد الأدوات ثم أعد الفحص.'
      );
    }

    // التحقق من امتدادات العمليات التي تتطلب ناتجًا محددًا.
    final dir = _defaultOutputDir();
    final inputs = _files.map((f) => f.path).toList(growable: false);

    if (op.multiInput && !op.supportsBatch) {
      if (op.id == 'pdf-merge' || op.id == 'video-merge' || op.id == 'images-pdf') {
        if (inputs.length < 2) {
          return (count: 0, error: 'هذه العملية تحتاج ملفين على الأقل.');
        }
      }
      if (op.requiresAllSameCategory) {
        final category = _files.first.category;
        if (_files.any((f) => f.category != category)) {
          return (
            count: 0,
            error: 'كل الملفات يجب أن تكون من نفس النوع (${category.label}).'
          );
        }
      }
      queue.enqueue(
        op,
        inputs,
        options: _options,
        outputFolder: dir,
      );
      return (count: 1, error: null);
    }

    if (op.supportsBatch && inputs.length > 1) {
      queue.enqueueMany(op, inputs, options: _options, outputFolder: dir);
      return (count: inputs.length, error: null);
    }

    queue.enqueue(op, inputs, options: _options, outputFolder: dir);
    return (count: 1, error: null);
  }

  // ── الأدوات ───────────────────────────────────────────────────
  Future<void> refreshTools() async {
    _scanning = true;
    _healthCheckTick++;
    notifyListeners();
    await registry.scan();
    _scanning = false;
    _pruneSelection();
    notifyListeners();
  }

  Future<void> setThemeMode(mode) async {
    await settings.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setAccent(int color) async {
    await settings.setAccent(color);
    notifyListeners();
  }

  Future<void> setSaveBesideSource(bool value) async {
    await settings.setSaveBesideSource(value);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    await settings.setNotifications(value);
    notifyListeners();
  }

  int get healthCheckTick => _healthCheckTick;

  String get toolsDir => PlatformInfo.resolveToolsDir();

  String get dataDir => PlatformInfo.resolveDataDir();

  /// عمليات جاهزة الآن — لعرض الحالة في الشريط الجانبي.
  Set<ToolId> get readyToolIds => ToolId.values
      .where((tool) => registry.isToolReady(tool))
      .toSet();
}
