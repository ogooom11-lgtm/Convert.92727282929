import 'dart:io';

import 'package:flutter/material.dart';

import 'capabilities.dart';
import 'command_builder.dart';

/// ملف مُضاف إلى الجلسة الحالية.
class FileEntry {
  FileEntry({
    required this.path,
    required this.category,
    required this.sizeBytes,
  });

  final String path;
  final FileCategory category;
  final int sizeBytes;

  String get name => path.split(RegExp(r'[\\/]')).last;
  String get baseName => CommandBuilder.baseName(path);
  String get extension => CommandBuilder.extensionOf(path);
  String get folder => File(path).parent.path;

  /// هل يمكن دمج هذا المدخل مع غيره في عملية واحدة؟
  bool get canBatch => true;

  String get readableSize {
    const units = ['بايت', 'كيلوبايت', 'ميغابايت', 'غيغابايت', 'تيرابايت'];
    double size = sizeBytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final digits = size >= 100 || unit == 0 ? 0 : 1;
    return '${size.toStringAsFixed(digits)} ${units[unit]}';
  }

  static FileEntry? fromPath(String rawPath) {
    try {
      final file = File(rawPath);
      if (!file.existsSync()) return null;
      final extension = CommandBuilder.extensionOf(rawPath);
      final category = categoryOf(extension);
      if (category == null) return null;
      return FileEntry(
        path: file.path,
        category: category,
        sizeBytes: file.lengthSync(),
      );
    } on FileSystemException {
      return null;
    }
  }

  /// أيقونة الفئة.
  IconData get icon => switch (category) {
        FileCategory.document => Icons.description_rounded,
        FileCategory.spreadsheet => Icons.table_chart_rounded,
        FileCategory.presentation => Icons.slideshow_rounded,
        FileCategory.pdf => Icons.picture_as_pdf_rounded,
        FileCategory.image => Icons.image_rounded,
        FileCategory.vector => Icons.polyline_rounded,
        FileCategory.video => Icons.movie_rounded,
        FileCategory.audio => Icons.graphic_eq_rounded,
        FileCategory.archive => Icons.folder_zip_rounded,
      };

  /// لون الفئة — تمييز بصري سريع.
  Color get color => switch (category) {
        FileCategory.document => const Color(0xFF4F8BF9),
        FileCategory.spreadsheet => const Color(0xFF2EB67D),
        FileCategory.presentation => const Color(0xFFF2994A),
        FileCategory.pdf => const Color(0xFFE05555),
        FileCategory.image => const Color(0xFF9B6BF2),
        FileCategory.vector => const Color(0xFF38BDF8),
        FileCategory.video => const Color(0xFFF472B6),
        FileCategory.audio => const Color(0xFF22C1A0),
        FileCategory.archive => const Color(0xFFD1A24C),
      };
}
