import 'dart:io';

import 'capabilities.dart';
import 'platform.dart';
import 'process_runner.dart';
import 'tool_registry.dart';

/// نتيجة تجربة حقيقية لأداة واحدة.
class SelfTestResult {
  const SelfTestResult({
    required this.tool,
    required this.ok,
    required this.message,
    required this.duration,
  });

  final ToolId tool;
  final bool ok;
  final String message;
  final Duration duration;
}

/// «فحص شامل»: بدل الاعتماد على رقم الإصدار فقط، نجعل كل أداة تُنتج ملفًا
/// حقيقيًا من ملف حقيقي. هذه أقوى طريقة لمعرفة أن الحزمة تعمل كاملة:
/// إن نجح الفحص فالعمليات ستنجح.
///
/// كل الأدوات تُجرَّب على ملفات مؤقتة تُنشأ هنا وتُحذف بعدها.
class SelfTest {
  SelfTest({required this.registry, ProcessRunner? runner})
      : _runner = runner ?? ProcessRunner();

  final ToolRegistry registry;
  final ProcessRunner _runner;

  /// مجلد مؤقت للفحص.
  Directory? _dir;

  Future<List<SelfTestResult>> runAll({
    void Function(SelfTestResult result)? onResult,
    int index = 0,
  }) async {
    final results = <SelfTestResult>[];
    final temp = Directory.systemTemp.createTempSync('convert-selftest');
    _dir = temp;
    try {
      final checks = <Future<SelfTestResult> Function()>[
        () => _checkImageMagick(temp),
        () => _checkGhostscript(temp),
        () => _checkQpdf(temp),
        () => _checkPoppler(temp),
        () => _checkFFmpeg(temp),
        () => _checkSevenZip(temp),
        () => _checkLibreOffice(temp),
        () => _checkFfprobe(temp),
      ];
      for (final check in checks) {
        final result = await check();
        results.add(result);
        onResult?.call(result);
        index++;
      }
    } finally {
      _safeDelete(temp);
      _dir = null;
    }
    return results;
  }

  String _exe(ToolId tool) {
    final path = registry.statusOf(tool).executablePath;
    return path.isNotEmpty ? path : tool.executable;
  }

  String _p(String dir, String name) =>
      '$dir${Platform.pathSeparator}$name';

  Future<SelfTestResult> _measure(
    ToolId tool,
    Future<({bool ok, String message})> Function() body,
  ) async {
    if (!registry.isToolReady(tool)) {
      return SelfTestResult(
        tool: tool,
        ok: false,
        message: 'الأداة غير متوفرة',
        duration: Duration.zero,
      );
    }
    final watch = Stopwatch()..start();
    try {
      final outcome = await body();
      watch.stop();
      return SelfTestResult(
        tool: tool,
        ok: outcome.ok,
        message: outcome.message,
        duration: watch.elapsed,
      );
    } catch (error) {
      watch.stop();
      return SelfTestResult(
        tool: tool,
        ok: false,
        message: 'خطأ غير متوقع: $error',
        duration: watch.elapsed,
      );
    }
  }

  // ── ImageMagick: صورة → JPG ─────────────────────────────────────
  Future<SelfTestResult> _checkImageMagick(Directory dir) {
    return _measure(ToolId.imagemagick, () async {
      final input = File(_p(dir.path, 'اختبار.png'))
        ..writeAsBytesSync(kTinyPng);
      final output = _p(dir.path, 'نتيجة.jpg');
      final result = await _runner.run(
        _exe(ToolId.imagemagick),
        [input.path, '-resize', '64x64>', '-strip', '-quality', '82', output],
        timeout: const Duration(seconds: 90),
      );
      final ok = result.outcome.ok && File(output).existsSync();
      return (
        ok: ok,
        message: ok
            ? 'صورة PNG عربية الاسم → JPG ✓'
            : _short(result.outcome.errorExcerpt),
      );
    });
  }

  // ── Ghostscript: PostScript → PDF ───────────────────────────────
  Future<SelfTestResult> _checkGhostscript(Directory dir) {
    return _measure(ToolId.ghostscript, () async {
      final input = File(_p(dir.path, 'اختبار.ps'))
        ..writeAsStringSync(_samplePostScript);
      final output = _p(dir.path, 'نتيجة-gs.pdf');
      final result = await _runner.run(
        _exe(ToolId.ghostscript),
        [
          '-sDEVICE=pdfwrite',
          '-dNOPAUSE',
          '-dBATCH',
          '-dQUIET',
          '-sOutputFile=$output',
          input.path,
        ],
        timeout: const Duration(seconds: 120),
      );
      final ok = result.outcome.ok &&
          File(output).existsSync() &&
          File(output).lengthSync() > 200;
      return (
        ok: ok,
        message: ok ? 'PS → PDF ✓' : _short(result.outcome.errorExcerpt),
      );
    });
  }

  // ── qpdf: فحص سلامة PDF ─────────────────────────────────────────
  Future<SelfTestResult> _checkQpdf(Directory dir) {
    return _measure(ToolId.qpdf, () async {
      final input = File(_p(dir.path, 'نموذج.pdf'))
        ..writeAsBytesSync(buildTinyPdf(text: 'Convert check'));
      final result = await _runner.run(
        _exe(ToolId.qpdf),
        ['--check', input.path],
        timeout: const Duration(seconds: 90),
      );
      // --check يعيد رمز 3 لأخطاء تحذيرية؛ نكتفي بأن الملف قُرئ فعلًا.
      final output = '${result.stdoutText} ${result.stderrText}';
      final ok = !result.outcome.timedOut &&
          output.toLowerCase().contains('pdf version');
      return (
        ok: ok,
        message: ok ? 'قراءة PDF والتحقق منه ✓' : _short(output),
      );
    });
  }

  // ── Poppler: PDF → نص ───────────────────────────────────────────
  Future<SelfTestResult> _checkPoppler(Directory dir) {
    return _measure(ToolId.poppler, () async {
      final input = File(_p(dir.path, 'نص.pdf'))..writeAsBytesSync(buildTinyPdf(text: 'Convert check'));
      final output = _p(dir.path, 'نص.txt');
      final result = await _runner.run(
        _exe(ToolId.poppler),
        ['-layout', '-enc', 'UTF-8', input.path, output],
        timeout: const Duration(seconds: 90),
      );
      final ok = result.outcome.ok && File(output).existsSync();
      return (
        ok: ok,
        message: ok ? 'PDF → نص ✓' : _short(result.outcome.errorExcerpt),
      );
    });
  }

  // ── FFmpeg: توليد فيديو ثم استخراج صوت ─────────────────────────
  Future<SelfTestResult> _checkFFmpeg(Directory dir) {
    return _measure(ToolId.ffmpeg, () async {
      final video = _p(dir.path, 'مقطع.mp4');
      final made = await _runner.run(
        _exe(ToolId.ffmpeg),
        [
          '-y',
          '-f', 'lavfi',
          '-i', 'testsrc=size=128x128:rate=10:duration=1',
          '-f', 'lavfi',
          '-i', 'sine=frequency=440:duration=1',
          '-c:v', 'libx264',
          '-preset', 'ultrafast',
          '-c:a', 'aac',
          '-shortest',
          video,
        ],
        timeout: const Duration(seconds: 180),
      );
      if (!made.outcome.ok || !File(video).existsSync()) {
        return (
          ok: false,
          message: 'توليد فيديو تجريبي فشل: ${_short(made.outcome.errorExcerpt)}',
        );
      }
      final audio = _p(dir.path, 'صوت.mp3');
      final extracted = await _runner.run(
        _exe(ToolId.ffmpeg),
        ['-y', '-i', video, '-vn', '-c:a', 'libmp3lame', '-b:a', '192k', audio],
        timeout: const Duration(seconds: 120),
      );
      final ok = extracted.outcome.ok && File(audio).existsSync();
      return (
        ok: ok,
        message: ok
            ? 'H.264/AAC ثم MP3 ✓'
            : _short(extracted.outcome.errorExcerpt),
      );
    });
  }

  // ── FFprobe ─────────────────────────────────────────────────────
  Future<SelfTestResult> _checkFfprobe(Directory dir) {
    return _measure(ToolId.ffprobe, () async {
      final video = File(_p(dir.path, 'مقطع.mp4'));
      if (!video.existsSync()) {
        return (ok: false, message: 'ملف الفيديو التجريبي غير موجود');
      }
      final result = await _runner.run(
        _exe(ToolId.ffprobe),
        [
          '-v', 'error',
          '-show_entries', 'stream=codec_type',
          '-of', 'csv=p=0',
          video.path,
        ],
        timeout: const Duration(seconds: 60),
      );
      final ok = result.outcome.ok && result.stdoutText.contains('video');
      return (
        ok: ok,
        message: ok ? 'قراءة وسوم الفيديو ✓' : _short(result.outcome.errorExcerpt),
      );
    });
  }

  // ── 7-Zip: ضغط ثم استخراج ──────────────────────────────────────
  Future<SelfTestResult> _checkSevenZip(Directory dir) {
    return _measure(ToolId.sevenZip, () async {
      final source = Directory(_p(dir.path, 'ملفات'))..createSync();
      File(_p(source.path, 'أ.txt')).writeAsStringSync('الفكرة: كل شيء محلي.');
      File(_p(source.path, 'ب.txt')).writeAsStringSync('بلا إنترنت.');

      final archive = _p(dir.path, 'أرشيف.7z');
      final packed = await _runner.run(
        _exe(ToolId.sevenZip),
        ['a', '-y', '-mx=1', archive, 'ملفات'],
        workingDirectory: dir.path,
        timeout: const Duration(seconds: 120),
      );
      if (!packed.outcome.ok || !File(archive).existsSync()) {
        return (
          ok: false,
          message: 'الضغط فشل: ${_short(packed.outcome.errorExcerpt)}',
        );
      }
      final target = Directory(_p(dir.path, 'مستخرج'))..createSync();
      final extracted = await _runner.run(
        _exe(ToolId.sevenZip),
        ['x', '-y', '-o${target.path}', archive],
        timeout: const Duration(seconds: 120),
      );
      final restored = File(_p('${target.path}${Platform.pathSeparator}ملفات', 'أ.txt'));
      final ok = extracted.outcome.ok &&
          restored.existsSync() &&
          restored.readAsStringSync().contains('محلي');
      return (
        ok: ok,
        message: ok
            ? 'ضغط 7Z ثم استخراج ✓'
            : 'الاستخراج فشل: ${_short(extracted.outcome.errorExcerpt)}',
      );
    });
  }

  // ── LibreOffice: نص عربي → PDF ─────────────────────────────────
  Future<SelfTestResult> _checkLibreOffice(Directory dir) {
    return _measure(ToolId.libreoffice, () async {
      final work = Directory(_p(dir.path, 'لو'))
        ..createSync(recursive: true);
      final outDir = Directory(_p(work.path, 'خارج'))..createSync();
      final profile = Directory(_p(work.path, 'ملف-تعريف'))..createSync();
      final input = File(_p(work.path, 'تقرير.txt'))
        ..writeAsStringSync('تحويل — فحص شامل\nالسطر الثاني بالعربية.\n');

      final result = await _runner.run(
        _exe(ToolId.libreoffice),
        [
          '--headless',
          '--norestore',
          '--nolockcheck',
          '-env:UserInstallation=${Uri.directory(profile.path)}',
          '--convert-to',
          'pdf',
          '--outdir',
          outDir.path,
          input.path,
        ],
        timeout: const Duration(seconds: 240),
      );
      final produced = Directory(outDir.path)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .toList();
      final ok = result.outcome.ok && produced.isNotEmpty;
      return (
        ok: ok,
        message: ok
            ? 'نص عربي → PDF ✓'
            : _short(result.outcome.errorExcerpt),
      );
    });
  }

  String _short(String text) {
    final value = text.trim();
    if (value.isEmpty) return 'فشل بلا رسالة';
    return value.length <= 180 ? value : value.substring(0, 180);
  }

  void _safeDelete(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ملفات مقفلة من أداة ما زالت تُغلق نفسها.
    }
  }

  /// مجلد الفحص المؤقت (للتنظيف اليدوي إن لزم).
  String? get workDir => _dir?.path;

  /// نص عربي مبسّط يُستخدم في الفحص.
  static const String sampleText = 'تحويل — فحص شامل';
}

/// PNG شفاف 1×1 — أصغر ملف صالح للفحص.
const List<int> kTinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x81, 0x00, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// يبني PDF صالحًا من صفحة واحدة فيها نص — للتحقق من qpdf وPoppler.
///
/// يُبنى في وقت التشغيل لأن جدول xref يحتاج إزاحات بايت دقيقة.
List<int> buildTinyPdf({String text = 'Convert self test'}) {
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final stream = 'BT /F1 18 Tf 20 100 Td ($text) Tj ET';
  objects.add('<< /Length ${stream.length} >>\nstream\n$stream\nendstream');

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xrefOffset = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n');
  buffer.write('startxref\n$xrefOffset\n%%EOF\n');
  return buffer.toString().codeUnits;
}

/// ملف PostScript بسيط يُنتج صفحة A4 فيها كلمة واحدة.
const String _samplePostScript = '''
%!PS-Adobe-3.0
%%Pages: 1
/Helvetica findfont 24 scalefont setfont
72 720 moveto
(Convert self-test) show
showpage
''';
