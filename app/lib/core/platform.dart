import 'dart:io';

/// طبقة رقيقة فوق نظام التشغيل.
///
/// كل ما تحتاجه الواجهة من ويندوز يمر من هنا: مسار مجلد الأدوات، مجلد
/// بيانات المستخدم، فحص التبعيات. المنطق نفسه لا يعتمد على نظام بعينه
/// لتسهيل الاختبار.
class PlatformInfo {
  static bool get isWindows => Platform.isWindows;

  static String get _sep => Platform.pathSeparator;

  /// مجلد الأدوات: بجوار الملف التنفيذي أولًا، ثم جذر المشروع أثناء التطوير.
  static String resolveToolsDir() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$exeDir${_sep}tools',
      '${Directory.current.path}${_sep}tools',
      '${Directory.current.path}${_sep}..${_sep}tools',
    ];
    for (final candidate in candidates) {
      if (Directory(candidate).existsSync()) return candidate;
    }
    return candidates.first;
  }

  /// مجلد بيانات المستخدم (إعدادات) — لا يُكتب شيء بجوار التطبيق.
  static String resolveDataDir() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return '$appData${_sep}Convert';
      }
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return '$home${_sep}.convert';
  }
}
