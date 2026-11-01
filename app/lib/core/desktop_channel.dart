import 'dart:io';

import 'package:flutter/services.dart';

/// الجسر مع نافذة ويندوز الأصلية (Runner).
///
/// يستخدم للأشياء التي لا تعمل من Dart: سحب الملفات من المستكشف، فتح
/// مجلد النتائج، اختيار مجلد، ولون شريط العنوان.
class DesktopBridge {
  DesktopBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('convert/desktop') {
    _channel.setMethodCallHandler(_handleCall);
  }

  final MethodChannel _channel;

  /// يُستدعى عند إفلات ملفات فوق النافذة.
  void Function(List<String> paths)? onFilesDropped;

  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method == 'droppedFiles') {
      final raw = call.arguments;
      if (raw is List) {
        final paths = raw
            .whereType<String>()
            .where((p) => p.trim().isNotEmpty)
            .toList(growable: false);
        if (paths.isNotEmpty) onFilesDropped?.call(paths);
      }
    }
    return null;
  }

  bool get _supported => Platform.isWindows;

  Future<void> setCaptionColor(int r, int g, int b) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setCaptionColor', {
        'r': r,
        'g': g,
        'b': b,
      });
    } on PlatformException {
      // تجاهل: اللون تحسين بصري فقط.
    } on MissingPluginException {
      // تشغيل على نظام آخر أثناء الاختبار.
    }
  }

  /// يفتح الملف/المجلد بالبرنامج الافتراضي.
  Future<bool> openPath(String path) => _invoke('openPath', path);

  /// يفتح مستكشف ويندوز مع تحديد الملف.
  Future<bool> revealPath(String path) => _invoke('revealPath', path);

  Future<bool> _invoke(String method, String path) async {
    if (!_supported) return false;
    try {
      final result = await _channel.invokeMethod<Object?>(method, {'path': path});
      if (result is int) return result > 32;
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// نافذة اختيار مجلد أصلية. تعيد null إن أُلغيت.
  Future<String?> pickFolder({String title = 'اختر مجلد النتائج'}) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('pickFolder', {'title': title});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
