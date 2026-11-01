import 'dart:io';

import 'capabilities.dart';
import 'tool_registry.dart';

/// خطة تنفيذ عملية واحدة: البرنامج + المعاملات + مكان الناتج.
///
/// المعاملات قائمة منفصلة دائمًا — لا سطر أوامر نصي — كي تعمل المسارات
/// العربية والمسافات بلا أي هروب يدوي.
class CommandPlan {
  CommandPlan({
    required this.tool,
    required this.executable,
    required this.arguments,
    required this.outputPath,
    this.workingDirectory,
    this.outputIsFolder = false,
    this.cleanupTempDirs = const [],
    this.expectedBaseName = '',
    this.stagingDir,
  });

  final ToolId tool;
  final String executable;
  final List<String> arguments;

  /// الملف المتوقع (أو المجلد المتوقع) بعد التنفيذ.
  final String outputPath;
  final String? workingDirectory;
  final bool outputIsFolder;

  /// مجلدات مؤقتة تُحذف بعد انتهاء المهمة.
  final List<String> cleanupTempDirs;

  /// اسم الملف بلا امتداد — يُستخدم للبحث عن الناتج إن غيّرته الأداة.
  final String expectedBaseName;

  /// إن كانت الأداة تكتب في مجلد وسيط (LibreOffice)، هنا مساره:
  /// بعد النجاح يُنقل الناتج إلى [outputPath].
  final String? stagingDir;
}

/// يبني الأوامر من جدول العمليات والأدوات المتاحة.
class CommandBuilder {
  CommandBuilder({
    required this.registry,
    required this.outputDirResolver,
    this.tempDirResolver,
  });

  final ToolRegistry registry;
  final String Function() outputDirResolver;
  final String Function()? tempDirResolver;

  static String _sep() => Platform.pathSeparator;

  String _exe(ToolId tool) {
    final status = registry.statusOf(tool);
    return status.executablePath.isNotEmpty ? status.executablePath : tool.executable;
  }

  /// اسم الملف بلا امتداد.
  static String baseName(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static String extensionOf(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  /// مسار فريد لا يستبدل ملفًا موجودًا: «اسم (1).ext».
  static String uniquePath(String dir, String base, String extension) {
    final sep = _sep();
    final ext = extension.isEmpty ? '' : '.$extension';
    var candidate = '$dir$sep$base$ext';
    var counter = 1;
    while (File(candidate).existsSync() || Directory(candidate).existsSync()) {
      candidate = '$dir$sep$base ($counter)$ext';
      counter++;
    }
    return candidate;
  }

  static String _suffixFor(String opId) => switch (opId) {
        'pdf-compress' => '-compressed',
        'pdf-extract' => '-pages',
        'pdf-encrypt' => '-encrypted',
        'pdf-decrypt' => '-decrypted',
        'pdf-merge' => '-merged',
        'images-pdf' => '-images',
        'video-thumb' => '-thumb',
        'media-trim' => '-clip',
        'video-merge' => '-merged',
        'video-audio' => '',
        'archive-zip' => '',
        'archive-7z' => '',
        _ => '',
      };

  /// يبني الخطة. يعيد null مع سبب عند فشل التحقق.
  ({CommandPlan? plan, String? error}) build({
    required ConvertOperation operation,
    required List<String> inputs,
    required Map<OptionField, String> options,
    String? outputFolder,
  }) {
    if (inputs.isEmpty) {
      return (plan: null, error: 'لم تُضف أي ملف.');
    }
    for (final input in inputs) {
      if (!File(input).existsSync() && !Directory(input).existsSync()) {
        return (plan: null, error: 'الملف غير موجود: ${baseName(input)}');
      }
    }

    final outDir = outputFolder ?? outputDirResolver();
    try {
      Directory(outDir).createSync(recursive: true);
    } on FileSystemException catch (error) {
      return (plan: null, error: 'تعذّر إنشاء مجلد النتائج: ${error.message}');
    }

    final first = inputs.first;
    final base = baseName(first);
    final suffix = _suffixFor(operation.id);

    final validation = _validateOptions(operation, options);
    if (validation != null) return (plan: null, error: validation);

    switch (operation.id) {
      // ── LibreOffice ─────────────────────────────────────────────
      case 'doc-pdf':
      case 'doc-docx':
      case 'doc-txt':
      case 'sheet-pdf':
      case 'sheet-csv':
      case 'slides-pdf':
        return _libreOfficePlan(operation, inputs, outDir, base);

      // ── ImageMagick ─────────────────────────────────────────────
      case 'image-jpg': {
        final out = uniquePath(outDir, '$base$suffix', 'jpg');
        return (
          plan: CommandPlan(
            tool: ToolId.imagemagick,
            executable: _exe(ToolId.imagemagick),
            arguments: [
              first,
              '-auto-orient',
              '-resize',
              '1920x1920>',
              '-strip',
              '-quality',
              '82',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'image-webp': {
        final out = uniquePath(outDir, '$base$suffix', 'webp');
        return (
          plan: CommandPlan(
            tool: ToolId.imagemagick,
            executable: _exe(ToolId.imagemagick),
            arguments: [first, '-auto-orient', '-quality', '85', out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'image-png': {
        final out = uniquePath(outDir, '$base$suffix', 'png');
        return (
          plan: CommandPlan(
            tool: ToolId.imagemagick,
            executable: _exe(ToolId.imagemagick),
            arguments: [first, '-auto-orient', out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'images-pdf': {
        final out = uniquePath(outDir, '$base$suffix', 'pdf');
        return (
          plan: CommandPlan(
            tool: ToolId.imagemagick,
            executable: _exe(ToolId.imagemagick),
            arguments: [...inputs, out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'svg-png': {
        final out = uniquePath(outDir, '$base$suffix', 'png');
        return (
          plan: CommandPlan(
            tool: ToolId.imagemagick,
            executable: _exe(ToolId.imagemagick),
            arguments: [
              '-background',
              'none',
              '-density',
              '300',
              first,
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'pdf-images': {
        final out = uniquePath(outDir, '$base$suffix', 'png');
        final pattern = out.replaceFirst(RegExp(r'\.png$'), '-%02d.png');
        return (
          plan: CommandPlan(
            tool: ToolId.imagemagick,
            executable: _exe(ToolId.imagemagick),
            arguments: ['-density', '150', first, pattern],
            outputPath: Directory(outDir).path,
            outputIsFolder: true,
            expectedBaseName: base,
          ),
          error: null
        );
      }

      // ── Ghostscript ─────────────────────────────────────────────
      case 'eps-pdf':
      case 'pdf-compress': {
        final out = uniquePath(outDir, '$base$suffix', 'pdf');
        return (
          plan: CommandPlan(
            tool: ToolId.ghostscript,
            executable: _exe(ToolId.ghostscript),
            arguments: [
              if (operation.id == 'eps-pdf') '-dEPSCrop',
              if (operation.id == 'pdf-compress') ...['-dPDFSETTINGS=/ebook'],
              '-sDEVICE=pdfwrite',
              '-dNOPAUSE',
              '-dBATCH',
              '-sOutputFile=$out',
              first,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }

      // ── qpdf ────────────────────────────────────────────────────
      case 'pdf-merge': {
        final out = uniquePath(outDir, '$base$suffix', 'pdf');
        return (
          plan: CommandPlan(
            tool: ToolId.qpdf,
            executable: _exe(ToolId.qpdf),
            arguments: ['--empty', '--pages', ...inputs, '--', out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'pdf-extract': {
        final range = options[OptionField.pageRange]?.trim() ?? '1-5';
        final out = uniquePath(outDir, '$base$suffix', 'pdf');
        return (
          plan: CommandPlan(
            tool: ToolId.qpdf,
            executable: _exe(ToolId.qpdf),
            arguments: [first, '--pages', '.', range, '--', out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'pdf-encrypt': {
        final password = options[OptionField.password] ?? '';
        final out = uniquePath(outDir, '$base$suffix', 'pdf');
        return (
          plan: CommandPlan(
            tool: ToolId.qpdf,
            executable: _exe(ToolId.qpdf),
            arguments: [
              '--encrypt',
              password,
              password,
              '256',
              '--',
              first,
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'pdf-decrypt': {
        final password = options[OptionField.password] ?? '';
        final out = uniquePath(outDir, '$base$suffix', 'pdf');
        return (
          plan: CommandPlan(
            tool: ToolId.qpdf,
            executable: _exe(ToolId.qpdf),
            arguments: ['--password=$password', '--decrypt', first, out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }

      // ── Poppler ─────────────────────────────────────────────────
      case 'pdf-text': {
        final out = uniquePath(outDir, '$base$suffix', 'txt');
        return (
          plan: CommandPlan(
            tool: ToolId.poppler,
            executable: _exe(ToolId.poppler),
            arguments: ['-layout', '-enc', 'UTF-8', first, out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }

      // ── FFmpeg ──────────────────────────────────────────────────
      case 'video-mp4': {
        final out = uniquePath(outDir, '$base$suffix', 'mp4');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              '-i',
              first,
              '-c:v',
              'libx264',
              '-crf',
              '23',
              '-preset',
              'medium',
              '-c:a',
              'aac',
              '-b:a',
              '128k',
              '-movflags',
              '+faststart',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'video-gif': {
        final out = uniquePath(outDir, '$base$suffix', 'gif');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              '-i',
              first,
              '-vf',
              'fps=12,scale=640:-1:flags=lanczos',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'video-thumb': {
        final out = uniquePath(outDir, '$base$suffix', 'png');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              '-ss',
              '00:00:05',
              '-i',
              first,
              '-frames:v',
              '1',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'media-trim': {
        final start = options[OptionField.startTime]?.trim();
        final ext = extensionOf(first);
        final out = uniquePath(outDir, '$base$suffix', ext.isEmpty ? 'mp4' : ext);
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              if (start != null && start.isNotEmpty) ...['-ss', start],
              '-t',
              '00:01:00',
              '-i',
              first,
              '-c',
              'copy',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'video-audio': {
        final out = uniquePath(outDir, '$base$suffix', 'mp3');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              '-i',
              first,
              '-vn',
              '-c:a',
              'libmp3lame',
              '-b:a',
              '192k',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'video-merge': {
        final tempDir = _makeTempDir('convert-merge');
        if (tempDir == null) {
          return (plan: null, error: 'تعذّر إنشاء مجلد مؤقت للدمج.');
        }
        final listFile = File('$tempDir${_sep()}list.txt');
        final buffer = StringBuffer();
        for (final input in inputs) {
          // صيغة ffmpeg: file 'path' — الشرطة المفردة داخل المسار تُهرَّب.
          final escaped = input.replaceAll("'", r"'\''");
          buffer.writeln("file '$escaped'");
        }
        listFile.writeAsStringSync(buffer.toString());
        final out = uniquePath(outDir, '$base$suffix', 'mp4');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              '-f',
              'concat',
              '-safe',
              '0',
              '-i',
              listFile.path,
              '-c',
              'copy',
              out,
            ],
            outputPath: out,
            cleanupTempDirs: [tempDir],
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'audio-mp3': {
        final out = uniquePath(outDir, '$base$suffix', 'mp3');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: [
              '-y',
              '-i',
              first,
              '-vn',
              '-c:a',
              'libmp3lame',
              '-b:a',
              '192k',
              out,
            ],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'audio-wav': {
        final out = uniquePath(outDir, '$base$suffix', 'wav');
        return (
          plan: CommandPlan(
            tool: ToolId.ffmpeg,
            executable: _exe(ToolId.ffmpeg),
            arguments: ['-y', '-i', first, '-vn', '-c:a', 'pcm_s16le', out],
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }

      // ── 7-Zip ───────────────────────────────────────────────────
      case 'archive-zip':
      case 'archive-7z': {
        final ext = operation.id == 'archive-7z' ? '7z' : 'zip';
        final out = uniquePath(outDir, base.isEmpty ? 'archive' : base, ext);
        final commonParent = _commonParent(inputs);
        final relative = inputs
            .map((path) => _relativeTo(commonParent, path))
            .toList(growable: false);
        return (
          plan: CommandPlan(
            tool: ToolId.sevenZip,
            executable: _exe(ToolId.sevenZip),
            arguments: [
              'a',
              '-y',
              '-mx=5',
              out,
              ...relative,
            ],
            workingDirectory: commonParent,
            outputPath: out,
            expectedBaseName: base,
          ),
          error: null
        );
      }
      case 'archive-extract': {
        final folder = uniquePath(outDir, base, '');
        return (
          plan: CommandPlan(
            tool: ToolId.sevenZip,
            executable: _exe(ToolId.sevenZip),
            arguments: ['x', '-y', '-o$folder', first],
            outputPath: folder,
            outputIsFolder: true,
            expectedBaseName: base,
          ),
          error: null
        );
      }
    }

    return (plan: null, error: 'العملية غير معروفة.');
  }

  ({CommandPlan? plan, String? error}) _libreOfficePlan(
    ConvertOperation operation,
    List<String> inputs,
    String outDir,
    String base,
  ) {
    final profileDir = _makeTempDir('convert-lo');
    if (profileDir == null) {
      return (plan: null, error: 'تعذّر إنشاء ملف تعريف مؤقت لـ LibreOffice.');
    }
    final String target;
    final String extension;
    switch (operation.id) {
      case 'doc-txt':
        target = 'txt:Text (encoded):UTF8';
        extension = 'txt';
        break;
      case 'sheet-csv':
        target = 'csv:Text - txt - csv (StarCalc):44,34,76';
        extension = 'csv';
        break;
      case 'doc-docx':
        target = 'docx';
        extension = 'docx';
        break;
      default:
        target = 'pdf';
        extension = 'pdf';
    }

    // مجلد إخراج مؤقت ثم نقل الناتج باسم فريد — يمنع تصادم الأسماء
    // ويضمن ألا نستبدل ملف المستخدم.
    final staging = _makeTempDir('convert-out');
    if (staging == null) {
      return (plan: null, error: 'تعذّر إنشاء مجلد مؤقت للناتج.');
    }

    final out = uniquePath(outDir, '$base', extension);
    // LibreOffice لا يقبل «اسم الهدف»؛ نطلب مجلدًا ثم ننقل.
    // نعتمد على اسم الملف الأصلي نفسه داخل مجلد التسجيل.
    return (
      plan: CommandPlan(
        tool: ToolId.libreoffice,
        executable: _exe(ToolId.libreoffice),
        arguments: [
          '--headless',
          '--norestore',
          '--nofirststartwizard',
          '--nolockcheck',
          '-env:UserInstallation=${Uri.directory(profileDir)}',
          '--convert-to',
          target,
          '--outdir',
          staging,
          ...inputs,
        ],
        outputPath: out,
        cleanupTempDirs: [profileDir, staging],
        expectedBaseName: base,
        stagingDir: staging,
      ),
      error: null
    );
  }

  String? _validateOptions(
    ConvertOperation operation,
    Map<OptionField, String> options,
  ) {
    final option = operation.option;
    if (option == null) return null;
    final value = options[option.field]?.trim() ?? '';
    switch (option.field) {
      case OptionField.pageRange:
        if (value.isEmpty) return null; // الافتراضي 1-5
        if (!RegExp(r'^\d+(\s*-\s*\d+)?(,\s*\d+(\s*-\s*\d+)?)*$').hasMatch(value)) {
          return 'نطاق الصفحات غير صالح. مثال صحيح: 1-5 أو 2,4,7-9';
        }
        return null;
      case OptionField.password:
        if (value.isEmpty) return 'أدخل كلمة المرور أولًا.';
        return null;
      case OptionField.startTime:
        if (value.isEmpty) return null;
        if (!RegExp(r'^\d{1,2}(:\d{1,2}){0,2}(\.\d+)?$').hasMatch(value)) {
          return 'وقت البداية غير صالح. مثال صحيح: 00:30 أو 1:02:15';
        }
        return null;
      case OptionField.duration:
      case OptionField.none:
        return null;
    }
  }

  String? _makeTempDir(String prefix) {
    try {
      final root = tempDirResolver?.call();
      final dir = root == null
          ? Directory.systemTemp.createTempSync(prefix)
          : Directory(root).createTempSync(prefix);
      return dir.path;
    } on FileSystemException {
      return null;
    }
  }

  /// المجلد الأب المشترك لكل المدخلات (لأوامر 7-Zip النسبية).
  String _commonParent(List<String> inputs) {
    final parents = inputs.map((p) => File(p).parent.path).toList();
    var common = parents.first;
    for (final dir in parents.skip(1)) {
      while (!dir.startsWith(common)) {
        final parent = Directory(common).parent.path;
        if (parent == common) break;
        common = parent;
      }
    }
    return common;
  }

  String _relativeTo(String parent, String path) {
    final normalizedParent =
        parent.endsWith(_sep()) ? parent : '$parent${_sep()}';
    if (path.startsWith(normalizedParent)) {
      return path.substring(normalizedParent.length);
    }
    return path;
  }

  /// بعد التنفيذ: قد تُنتج الأداة اسمًا مختلفًا (LibreOffice مثلًا) —
  /// نبحث عن أحدث ملف بالامتداد المطلوب داخل مجلد الإخراج.
  String? harvestOutput(CommandPlan plan, DateTime startedAt) {
    if (plan.outputPath.isEmpty) return null;
    if (plan.outputIsFolder && Directory(plan.outputPath).existsSync()) {
      return plan.outputPath;
    }
    if (File(plan.outputPath).existsSync()) return plan.outputPath;

    // LibreOffice يكتب في مجلد مؤقت ثم يُنقل: نتعامل مع هذه الحالة في
    // TaskQueue عبر حقن مسار التسجيل في الإعدادات.
    return null;
  }
}
