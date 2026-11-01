import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// نافذة اختيار ملفات أصلية من ويندوز.
///
/// تعيد null إن أُلغيت العملية، وقائمة فارغة إن فشل الاختيار.
Future<List<String>?> pickFilesWithSystemDialog() async {
  try {
    const typeGroup = XTypeGroup(
      label: 'كل الملفات المدعومة',
      extensions: <String>[
        'doc', 'docx', 'docm', 'dot', 'dotx', 'rtf', 'odt', 'txt', 'html',
        'htm', 'xls', 'xlsx', 'xlsm', 'xlsb', 'csv', 'tsv', 'ods', 'ppt',
        'pptx', 'pptm', 'pps', 'ppsx', 'odp', 'pdf', 'jpg', 'jpeg', 'png',
        'gif', 'webp', 'bmp', 'tif', 'tiff', 'ico', 'tga', 'jp2', 'jxl',
        'exr', 'hdr', 'psd', 'ppm', 'pgm', 'pbm', 'svg', 'eps', 'ps', 'ai',
        'mp4', 'avi', 'mkv', 'mov', 'webm', 'wmv', 'flv', 'mpeg', 'mpg',
        'm4v', '3gp', 'ts', 'vob', 'ogv', 'mxf', 'asf', 'mp3', 'wav', 'aac',
        'flac', 'm4a', 'ogg', 'opus', 'wma', 'aiff', 'aif', 'amr', 'ac3',
        'alac', 'ape', 'caf', 'mp2', 'zip', '7z', 'rar', 'tar', 'gz', 'tgz',
        'bz2', 'tbz2', 'xz', 'txz', 'cab', 'iso',
      ],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    return files.map((file) => file.path).toList(growable: false);
  } on PlatformException {
    return const [];
  } catch (_) {
    return const [];
  }
}

/// المسار المطلق لمجلد المستخدم — لتقديم وجهة افتراضية نظيفة.
String defaultDocumentsDir() {
  final env = Platform.environment;
  final home = env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
  final documents = Directory('$home${Platform.pathSeparator}Documents');
  if (documents.existsSync()) return documents.path;
  return home;
}
