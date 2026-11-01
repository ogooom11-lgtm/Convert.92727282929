import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'platform.dart';

/// إعدادات التطبيق — ملف JSON واحد في مجلد بيانات المستخدم.
///
/// لا قاعدة بيانات، لا اتصال بالشبكة، لا شيء يُرسل خارج الجهاز.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._file, this._data);

  static const defaultAccent = 0xFF7C5CFF;
  static const accents = <int>[
    0xFF7C5CFF,
    0xFF22D3EE,
    0xFF34D399,
    0xFFF59E0B,
    0xFFF472B6,
    0xFF8B5CF6,
    0xFF60A5FA,
    0xFFEF4444,
  ];

  final File _file;
  Map<String, dynamic> _data;

  static Future<AppSettings> load() async {
    final dir = Directory(PlatformInfo.resolveDataDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}${Platform.pathSeparator}settings.json');
    Map<String, dynamic> data = {};
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        data = {};
      }
    }
    final settings = AppSettings._(file, data);
    await settings._applyStartupDefaults();
    return settings;
  }

  /// أول تشغيل: الوضع «حسب النظام» كما اختاره المستخدم.
  Future<void> _applyStartupDefaults() async {
    if (_data.containsKey('themeMode')) return;
    _data['themeMode'] = ThemeMode.system.name;
    _data['accent'] = defaultAccent;
    _data['saveBesideSource'] = true;
    _data['outputFolder'] = '';
    _data['notifications'] = true;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _file.writeAsString(jsonEncode(_data), flush: true);
    } on FileSystemException {
      // لا نُسقط التطبيق إن تعذّر الحفظ.
    }
  }

  ThemeMode get themeMode {
    final raw = _data['themeMode'] as String? ?? ThemeMode.system.name;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _data['themeMode'] = mode.name;
    notifyListeners();
    await _persist();
  }

  int get accent => (_data['accent'] as num?)?.toInt() ?? defaultAccent;

  Future<void> setAccent(int color) async {
    _data['accent'] = color;
    notifyListeners();
    await _persist();
  }

  Color get accentColor => Color(accent);

  bool get saveBesideSource => _data['saveBesideSource'] as bool? ?? true;

  Future<void> setSaveBesideSource(bool value) async {
    _data['saveBesideSource'] = value;
    notifyListeners();
    await _persist();
  }

  String get outputFolder => _data['outputFolder'] as String? ?? '';

  Future<void> setOutputFolder(String path) async {
    _data['outputFolder'] = path;
    notifyListeners();
    await _persist();
  }

  bool get notifications => _data['notifications'] as bool? ?? true;

  Future<void> setNotifications(bool value) async {
    _data['notifications'] = value;
    notifyListeners();
    await _persist();
  }

  String get settingsPath => _file.path;
}
