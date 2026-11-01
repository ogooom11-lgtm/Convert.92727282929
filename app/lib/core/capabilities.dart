/// فئات الملفات المدعومة.
enum FileCategory {
  document('مستندات'),
  spreadsheet('جداول'),
  presentation('عروض'),
  pdf('PDF'),
  image('صور'),
  vector('فيكتور'),
  video('فيديو'),
  audio('صوت'),
  archive('أرشيف');

  const FileCategory(this.label);
  final String label;
}

/// الأدوات السبع.
enum ToolId {
  ffmpeg('FFmpeg', 'ffmpeg.exe'),
  ffprobe('FFprobe', 'ffprobe.exe'),
  imagemagick('ImageMagick', 'magick.exe'),
  libreoffice('LibreOffice', 'soffice.exe'),
  sevenZip('7-Zip', '7z.exe'),
  qpdf('qpdf', 'qpdf.exe'),
  ghostscript('Ghostscript', 'gswin64c.exe'),
  poppler('Poppler', 'pdftotext.exe');

  const ToolId(this.label, this.executable);
  final String label;
  final String executable;
}

/// امتداد → فئة. أي امتداد غير مذكور هنا = غير مدعوم (قاعدة الخطة).
const Map<String, FileCategory> kExtensions = {
  // مستندات
  'doc': FileCategory.document,
  'docx': FileCategory.document,
  'docm': FileCategory.document,
  'dot': FileCategory.document,
  'dotx': FileCategory.document,
  'rtf': FileCategory.document,
  'odt': FileCategory.document,
  'txt': FileCategory.document,
  'html': FileCategory.document,
  'htm': FileCategory.document,
  // جداول
  'xls': FileCategory.spreadsheet,
  'xlsx': FileCategory.spreadsheet,
  'xlsm': FileCategory.spreadsheet,
  'xlsb': FileCategory.spreadsheet,
  'csv': FileCategory.spreadsheet,
  'tsv': FileCategory.spreadsheet,
  'ods': FileCategory.spreadsheet,
  // عروض
  'ppt': FileCategory.presentation,
  'pptx': FileCategory.presentation,
  'pptm': FileCategory.presentation,
  'pps': FileCategory.presentation,
  'ppsx': FileCategory.presentation,
  'odp': FileCategory.presentation,
  // PDF
  'pdf': FileCategory.pdf,
  // صور
  'jpg': FileCategory.image,
  'jpeg': FileCategory.image,
  'png': FileCategory.image,
  'gif': FileCategory.image,
  'webp': FileCategory.image,
  'bmp': FileCategory.image,
  'tif': FileCategory.image,
  'tiff': FileCategory.image,
  'ico': FileCategory.image,
  'tga': FileCategory.image,
  'jp2': FileCategory.image,
  'jxl': FileCategory.image,
  'exr': FileCategory.image,
  'hdr': FileCategory.image,
  'psd': FileCategory.image,
  'ppm': FileCategory.image,
  'pgm': FileCategory.image,
  'pbm': FileCategory.image,
  // فيكتور
  'svg': FileCategory.vector,
  'eps': FileCategory.vector,
  'ps': FileCategory.vector,
  'ai': FileCategory.vector,
  // فيديو
  'mp4': FileCategory.video,
  'avi': FileCategory.video,
  'mkv': FileCategory.video,
  'mov': FileCategory.video,
  'webm': FileCategory.video,
  'wmv': FileCategory.video,
  'flv': FileCategory.video,
  'mpeg': FileCategory.video,
  'mpg': FileCategory.video,
  'm4v': FileCategory.video,
  '3gp': FileCategory.video,
  'ts': FileCategory.video,
  'vob': FileCategory.video,
  'ogv': FileCategory.video,
  'mxf': FileCategory.video,
  'asf': FileCategory.video,
  // صوت
  'mp3': FileCategory.audio,
  'wav': FileCategory.audio,
  'aac': FileCategory.audio,
  'flac': FileCategory.audio,
  'm4a': FileCategory.audio,
  'ogg': FileCategory.audio,
  'opus': FileCategory.audio,
  'wma': FileCategory.audio,
  'aiff': FileCategory.audio,
  'aif': FileCategory.audio,
  'amr': FileCategory.audio,
  'ac3': FileCategory.audio,
  'alac': FileCategory.audio,
  'ape': FileCategory.audio,
  'caf': FileCategory.audio,
  'mp2': FileCategory.audio,
  // أرشيف
  'zip': FileCategory.archive,
  '7z': FileCategory.archive,
  'rar': FileCategory.archive,
  'tar': FileCategory.archive,
  'gz': FileCategory.archive,
  'tgz': FileCategory.archive,
  'bz2': FileCategory.archive,
  'tbz2': FileCategory.archive,
  'xz': FileCategory.archive,
  'txz': FileCategory.archive,
  'cab': FileCategory.archive,
  'iso': FileCategory.archive,
};

/// أنواع الحقول الإضافية التي قد تحتاجها عملية ما (حقل واحد كحد أقصى).
enum OptionField {
  none,
  pageRange,
  password,
  startTime,
  duration,
}

enum OptionKind { text, password, duration }

class OperationOption {
  const OperationOption({
    required this.field,
    required this.label,
    required this.hint,
    this.kind = OptionKind.text,
  });
  final OptionField field;
  final String label;
  final String hint;
  final OptionKind kind;
}

/// عملية واحدة من العمليات الثلاثين.
class ConvertOperation {
  const ConvertOperation({
    required this.id,
    required this.title,
    required this.description,
    required this.tool,
    required this.inputCategories,
    required this.outputLabel,
    required this.outputExtension,
    this.option,
    this.multiInput = false,
    this.outputFolder = false,
    this.supportsBatch = true,
    this.requiresAllSameCategory = true,
  });

  final String id;
  final String title;
  final String description;
  final ToolId tool;
  final List<FileCategory> inputCategories;
  final String outputLabel;

  /// الامتداد المتوقع للناتج؛ فارغ للأرشيف (مجلد) أو للمخرجات المتعددة.
  final String outputExtension;
  final OperationOption? option;

  /// هل تقبل أكثر من ملف كمدخل؟ (دمج PDF، دمج المقاطع، ضغط عدة ملفات)
  final bool multiInput;

  /// هل الناتج مجلد وليس ملفًا؟
  final bool outputFolder;

  /// هل يمكن تطبيقها على كل ملف على حدة في طابور؟
  final bool supportsBatch;
  final bool requiresAllSameCategory;
}

/// جدول القدرات — مصدر الحقيقة الوحيد.
/// لا توجد عملية خارج هذه القائمة، ولا صيغة تُقبل إن لم تكن في [kExtensions].
const List<ConvertOperation> kOperations = [
  // ── ١–٦ المستندات والجداول والعروض ───────────────────────────────
  ConvertOperation(
    id: 'doc-pdf',
    title: 'مستند → PDF',
    description: 'تحويل Word أو RTF أو ODT أو HTML إلى PDF جاهز للمشاركة.',
    tool: ToolId.libreoffice,
    inputCategories: [FileCategory.document],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
  ),
  ConvertOperation(
    id: 'doc-docx',
    title: 'مستند → DOCX',
    description: 'توحيد الصيغة إلى Word الحديثة DOCX.',
    tool: ToolId.libreoffice,
    inputCategories: [FileCategory.document],
    outputLabel: 'DOCX',
    outputExtension: 'docx',
  ),
  ConvertOperation(
    id: 'doc-txt',
    title: 'مستند → TXT',
    description: 'استخراج النص العادي بترميز UTF-8.',
    tool: ToolId.libreoffice,
    inputCategories: [FileCategory.document],
    outputLabel: 'TXT',
    outputExtension: 'txt',
  ),
  ConvertOperation(
    id: 'sheet-pdf',
    title: 'جدول → PDF',
    description: 'كل أوراق العمل في ملف PDF واحد.',
    tool: ToolId.libreoffice,
    inputCategories: [FileCategory.spreadsheet],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
  ),
  ConvertOperation(
    id: 'sheet-csv',
    title: 'جدول → CSV',
    description: 'تصدير بترميز UTF-8 وفاصلة عادية.',
    tool: ToolId.libreoffice,
    inputCategories: [FileCategory.spreadsheet],
    outputLabel: 'CSV',
    outputExtension: 'csv',
  ),
  ConvertOperation(
    id: 'slides-pdf',
    title: 'عرض → PDF',
    description: 'كل الشرائح في ملف واحد بحجم ثابت.',
    tool: ToolId.libreoffice,
    inputCategories: [FileCategory.presentation],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
  ),

  // ── ٧–١٢ الصور والفيكتور ────────────────────────────────────────
  ConvertOperation(
    id: 'image-jpg',
    title: 'صورة → JPG مضغوط',
    description: 'تصغير إلى 1920px، جودة 82، بلا بيانات وصفية.',
    tool: ToolId.imagemagick,
    inputCategories: [FileCategory.image, FileCategory.vector],
    outputLabel: 'JPG',
    outputExtension: 'jpg',
  ),
  ConvertOperation(
    id: 'image-webp',
    title: 'صورة → WEBP',
    description: 'صيغة حديثة أخف بنحو ٣٠٪ من JPG بجودة 85.',
    tool: ToolId.imagemagick,
    inputCategories: [FileCategory.image],
    outputLabel: 'WEBP',
    outputExtension: 'webp',
  ),
  ConvertOperation(
    id: 'image-png',
    title: 'صورة → PNG',
    description: 'بلا فقدان، مع الحفاظ على الشفافية.',
    tool: ToolId.imagemagick,
    inputCategories: [FileCategory.image, FileCategory.vector],
    outputLabel: 'PNG',
    outputExtension: 'png',
  ),
  ConvertOperation(
    id: 'images-pdf',
    title: 'صور → PDF',
    description: 'صفحة لكل صورة بالترتيب الذي تختاره.',
    tool: ToolId.imagemagick,
    inputCategories: [FileCategory.image],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
    multiInput: true,
    supportsBatch: false,
  ),
  ConvertOperation(
    id: 'svg-png',
    title: 'SVG → PNG',
    description: 'دقة 300 مع خلفية شفافة.',
    tool: ToolId.imagemagick,
    inputCategories: [FileCategory.vector],
    outputLabel: 'PNG',
    outputExtension: 'png',
  ),
  ConvertOperation(
    id: 'eps-pdf',
    title: 'EPS / PS / AI → PDF',
    description: 'مع قص حدود الصفحة للفيكتور.',
    tool: ToolId.ghostscript,
    inputCategories: [FileCategory.vector],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
  ),

  // ── ١٣–١٩ PDF ──────────────────────────────────────────────────
  ConvertOperation(
    id: 'pdf-merge',
    title: 'دمج PDF',
    description: 'ملف واحد بترتيب الاختيار نفسه.',
    tool: ToolId.qpdf,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
    multiInput: true,
    supportsBatch: false,
  ),
  ConvertOperation(
    id: 'pdf-extract',
    title: 'استخراج صفحات',
    description: 'مثال النطاق: 1-5 أو 2,4,7-9.',
    tool: ToolId.qpdf,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
    option: OperationOption(
      field: OptionField.pageRange,
      label: 'نطاق الصفحات',
      hint: 'مثال: 1-5 أو 2,4,7-9',
    ),
  ),
  ConvertOperation(
    id: 'pdf-compress',
    title: 'ضغط PDF',
    description: 'جودة /ebook — أصغر حجم مع نص واضح.',
    tool: ToolId.ghostscript,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
  ),
  ConvertOperation(
    id: 'pdf-images',
    title: 'PDF → صور PNG',
    description: 'صورة لكل صفحة بدقة 150dpi.',
    tool: ToolId.imagemagick,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'صور PNG',
    outputExtension: 'png',
  ),
  ConvertOperation(
    id: 'pdf-text',
    title: 'PDF → نص',
    description: 'استخراج النص مع حفاظ التنسيق.',
    tool: ToolId.poppler,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'TXT',
    outputExtension: 'txt',
  ),
  ConvertOperation(
    id: 'pdf-encrypt',
    title: 'تشفير PDF',
    description: 'AES-256 بكلمة مرور تختارها.',
    tool: ToolId.qpdf,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'PDF مشفّر',
    outputExtension: 'pdf',
    option: OperationOption(
      field: OptionField.password,
      label: 'كلمة المرور',
      hint: 'تُستخدم للمستخدم والمالك',
      kind: OptionKind.password,
    ),
  ),
  ConvertOperation(
    id: 'pdf-decrypt',
    title: 'فك تشفير PDF',
    description: 'بكلمة المرور الصحيحة فقط.',
    tool: ToolId.qpdf,
    inputCategories: [FileCategory.pdf],
    outputLabel: 'PDF',
    outputExtension: 'pdf',
    option: OperationOption(
      field: OptionField.password,
      label: 'كلمة المرور الحالية',
      hint: 'كلمة مرور الملف',
      kind: OptionKind.password,
    ),
  ),

  // ── ٢٠–٢٧ الفيديو والصوت ───────────────────────────────────────
  ConvertOperation(
    id: 'video-mp4',
    title: 'فيديو → MP4 مضغوط',
    description: 'H.264 بجودة CRF 23 وصوت AAC 128k — متوافق مع كل شيء.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.video],
    outputLabel: 'MP4',
    outputExtension: 'mp4',
  ),
  ConvertOperation(
    id: 'video-gif',
    title: 'فيديو → GIF',
    description: '12 إطارًا/ث وعرض 640px.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.video],
    outputLabel: 'GIF',
    outputExtension: 'gif',
  ),
  ConvertOperation(
    id: 'video-thumb',
    title: 'صورة مصغّرة للفيديو',
    description: 'إطار عند الثانية ٥ كصورة PNG.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.video],
    outputLabel: 'PNG',
    outputExtension: 'png',
  ),
  ConvertOperation(
    id: 'media-trim',
    title: 'قص مقطع',
    description: 'دقيقة واحدة بلا إعادة ترميز — سريع جدًا.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.video, FileCategory.audio],
    outputLabel: 'نفس الصيغة',
    outputExtension: '',
    option: OperationOption(
      field: OptionField.startTime,
      label: 'وقت البداية',
      hint: 'mm:ss أو hh:mm:ss',
      kind: OptionKind.duration,
    ),
  ),
  ConvertOperation(
    id: 'video-audio',
    title: 'استخراج الصوت',
    description: 'من الفيديو إلى MP3 بجودة 192k.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.video],
    outputLabel: 'MP3',
    outputExtension: 'mp3',
  ),
  ConvertOperation(
    id: 'video-merge',
    title: 'دمج مقاطع',
    description: 'دمج سريع بنفس الترميز — مقاطع متشابهة الإعدادات.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.video],
    outputLabel: 'MP4',
    outputExtension: 'mp4',
    multiInput: true,
    supportsBatch: false,
  ),
  ConvertOperation(
    id: 'audio-mp3',
    title: 'صوت → MP3',
    description: 'جودة 192k مناسبة للموسيقى.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.audio],
    outputLabel: 'MP3',
    outputExtension: 'mp3',
  ),
  ConvertOperation(
    id: 'audio-wav',
    title: 'صوت → WAV',
    description: 'PCM 16-bit بلا ضغط.',
    tool: ToolId.ffmpeg,
    inputCategories: [FileCategory.audio],
    outputLabel: 'WAV',
    outputExtension: 'wav',
  ),

  // ── ٢٨–٣٠ الأرشيف ──────────────────────────────────────────────
  ConvertOperation(
    id: 'archive-zip',
    title: 'إنشاء ZIP',
    description: 'مستوى ضغط 5 — متوافق مع كل الأنظمة.',
    tool: ToolId.sevenZip,
    inputCategories: FileCategory.values,
    outputLabel: 'ZIP',
    outputExtension: 'zip',
    multiInput: true,
    supportsBatch: false,
    requiresAllSameCategory: false,
  ),
  ConvertOperation(
    id: 'archive-7z',
    title: 'إنشاء 7Z',
    description: 'مستوى ضغط 5 — أصغر حجمًا من ZIP.',
    tool: ToolId.sevenZip,
    inputCategories: FileCategory.values,
    outputLabel: '7Z',
    outputExtension: '7z',
    multiInput: true,
    supportsBatch: false,
    requiresAllSameCategory: false,
  ),
  ConvertOperation(
    id: 'archive-extract',
    title: 'استخراج أرشيف',
    description: 'إلى مجلد باسم الأرشيف داخل مجلد النتائج.',
    tool: ToolId.sevenZip,
    inputCategories: [FileCategory.archive],
    outputLabel: 'مجلد',
    outputExtension: '',
    outputFolder: true,
  ),
];

ConvertOperation? operationById(String id) {
  for (final op in kOperations) {
    if (op.id == id) return op;
  }
  return null;
}

FileCategory? categoryOf(String extension) =>
    kExtensions[extension.toLowerCase().replaceAll('.', '')];

/// العمليات المتاحة لفئة معيّنة.
List<ConvertOperation> operationsFor(FileCategory category) => kOperations
    .where((op) => op.inputCategories.contains(category))
    .toList(growable: false);
