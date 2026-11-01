import 'dart:io';

/// إعداد إلزامي في ImageMagick: بناءات ويندوز تحجب قراءة وكتابة PDF وPS
/// لأسباب أمنية. بدون هذا التعديل تفشل عمليات «PDF → صور» و«EPS/PS/AI → PDF»
/// بلا رسالة واضحة.
///
/// التطبيق يصلح الملف تلقائيًا عند أول فحص — فالخصوصية والأمان هنا لا
/// يقتضيان تعطيل كل الحمايات، بل السماح للصيغ الخمس فقط.
class ImageMagickPolicy {
  /// الصيغ التي تحتاجها العمليات الثلاثون.
  static const List<String> allowedCoders = [
    'PS',
    'PS2',
    'PS3',
    'EPS',
    'PDF',
    'XPS',
  ];

  /// نتيجة المحاولة.
  final bool changed;
  final bool ok;
  final String message;
  final String? policyPath;

  const ImageMagickPolicy({
    required this.changed,
    required this.ok,
    required this.message,
    this.policyPath,
  });

  /// يبحث عن policy.xml بجوار الأداة وفي المسارات المعتادة، ثم يزيل الحجب
  /// عن الصيغ الخمس فقط. لا يمسّ أي قاعدة أخرى.
  static ImageMagickPolicy ensure({
    required String magickExecutable,
    bool dryRun = false,
  }) {
    final file = _locatePolicy(magickExecutable);
    if (file == null) {
      // لا يوجد ملف سياسة = لا حجب افتراضيًا في بعض البناءات.
      return const ImageMagickPolicy(
        changed: false,
        ok: true,
        message: 'لا يوجد policy.xml — لا حجب مطبّق.',
      );
    }

    final original = file.readAsStringSync();
    final result = rewrite(original);
    if (!result.changed) {
      return ImageMagickPolicy(
        changed: false,
        ok: result.blockedNow,
        message: result.blockedNow
            ? 'سياسة ImageMagick ما زالت تحجب PDF/PS.'
            : 'سياسة ImageMagick تسمح بـ PDF/PS أصلًا.',
        policyPath: file.path,
      );
    }

    if (!dryRun) {
      try {
        final backup = File('${file.path}.bak');
        if (!backup.existsSync()) backup.writeAsStringSync(original);
        file.writeAsStringSync(result.content);
      } on FileSystemException catch (error) {
        return ImageMagickPolicy(
          changed: false,
          ok: false,
          message: 'تعذّر تعديل policy.xml (صلاحيات؟): ${error.message}',
          policyPath: file.path,
        );
      }
    }

    return ImageMagickPolicy(
      changed: !dryRun,
      ok: true,
      message: 'أُصلحت سياسة ImageMagick: PDF وPS مسموحان الآن.',
      policyPath: file.path,
    );
  }

  /// التعديل النصي نفسه (نقيّة، قابلة للاختبار بلا ملفات).
  static ({String content, bool changed, bool blockedNow}) rewrite(
    String content,
  ) {
    final buffer = StringBuffer();
    var changed = false;
    var blockedNow = false;

    final pattern = RegExp(r'<policy\b[^>]*/>', multiLine: true, dotAll: true);
    var last = 0;
    for (final match in pattern.allMatches(content)) {
      buffer.write(content.substring(last, match.start));
      last = match.end;
      final element = match.group(0)!;

      final isCoderOrDelegate =
          element.contains('domain="coder"') || element.contains('domain="delegate"');
      final blocks = element.contains('rights="none"');
      final patternMatch = RegExp(r'pattern="([^"]*)"').firstMatch(element);
      final coders = patternMatch?.group(1) ?? '';

      if (!isCoderOrDelegate || !blocks) {
        buffer.write(element);
        continue;
      }

      final patterns = _parsePattern(coders);
      final touched = patterns.where(allowedCoders.contains).toList();
      if (touched.isEmpty) {
        buffer.write(element);
        if (coders.contains('{PS') || coders.toUpperCase().contains('PDF')) {
          blockedNow = true;
        }
        continue;
      }

      changed = true;
      final remaining = patterns.where((p) => !allowedCoders.contains(p)).toList();
      if (remaining.isEmpty) {
        // كل المحجوب في هذا العنصر مسموح الآن ← نحذف العنصر.
        buffer.write('<!-- Convert: PDF/PS/EPS مسموح -->');
      } else {
        // نُبقي بقية الحجب ونزيل الصيغ المسموحة فقط.
        final newPattern = remaining.length == 1
            ? remaining.first
            : '{${remaining.join(',')}}';
        buffer.write(element.replaceFirst(
          RegExp(r'pattern="[^"]*"'),
          'pattern="$newPattern"',
        ));
      }
    }
    buffer.write(content.substring(last));

    return (
      content: buffer.toString(),
      changed: changed,
      blockedNow: blockedNow && !changed,
    );
  }

  /// يفهم الصيغتين: `{PS,PDF}` و`PS` و`{*.ps,*.pdf}`.
  static List<String> _parsePattern(String pattern) {
    final cleaned = pattern.replaceAll('{', '').replaceAll('}', '');
    return cleaned
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) {
          var name = part.replaceAll('*', '');
          if (name.startsWith('.')) name = name.substring(1);
          return name.toUpperCase();
        })
        .toList();
  }

  static File? _locatePolicy(String executable) {
    final dir = File(executable).parent;
    final candidates = <String>[
      '${dir.path}${Platform.pathSeparator}policy.xml',
      '${dir.path}${Platform.pathSeparator}..${Platform.pathSeparator}etc'
          '${Platform.pathSeparator}ImageMagick-7${Platform.pathSeparator}policy.xml',
      '${dir.path}${Platform.pathSeparator}config${Platform.pathSeparator}policy.xml',
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) return file;
    }
    // بحث محدود داخل مجلد الأداة (نسخة محمولة قد تضع config في مجلد فرعي).
    try {
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File &&
            entity.uri.pathSegments.last.toLowerCase() == 'policy.xml') {
          return entity;
        }
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }
}
