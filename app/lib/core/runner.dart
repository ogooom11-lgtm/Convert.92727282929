/// نتيجة استدعاء عملية خارجية.
class ProcessOutcome {
  ProcessOutcome({
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
    required this.timedOut,
    required this.cancelled,
    required this.duration,
  });

  final int exitCode;
  final String stdoutText;
  final String stderrText;
  final bool timedOut;
  final bool cancelled;
  final Duration duration;

  bool get ok => !timedOut && !cancelled && exitCode == 0;

  /// آخر جزء من رسالة الخطأ — ما يُعرض للمستخدم (٤٠٠ حرف كما في الخطة).
  String get errorExcerpt {
    final raw = stderrText.trim().isEmpty ? stdoutText.trim() : stderrText.trim();
    if (raw.isEmpty) return 'خرجت الأداة بالرمز $exitCode بلا رسالة.';
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final joined = lines.join(' • ');
    return joined.length <= 400 ? joined : joined.substring(joined.length - 400);
  }
}
