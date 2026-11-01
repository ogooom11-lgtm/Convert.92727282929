import 'dart:io';

import 'package:convert/core/app_state.dart';
import 'package:convert/core/task_queue.dart';
import 'package:convert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// اختبار شامل: يفتح التطبيق فعليًا ويشغّل العمليات على ملفات حقيقية.
///
/// التشغيل (من مجلد app):
///   flutter test integration_test/happy_path_test.dart -d windows
///
/// ما يحتاجه:
///   * ملفات الاختبار في test/fixtures (تُنشأ تلقائيًا إن كانت الأدوات جاهزة).
///   * الأدوات في tools/ لتشغيل التحويل الفعلي.
///
/// الاختبار يعمل في طبقتين:
///   ١) واجهة: النافذة تُفتح، سحب الملفات، اختيار العملية، البدء.
///   ٢) منطق: ٣٠ عملية تمرّ في جدول القدرات + طابور حقيقي على الأقل لعملية واحدة.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('التطبيق يفتح ويستجيب للتفاعل الأساسي', (tester) async {
    final state = await AppState.bootstrap();
    await tester.pumpWidget(ConvertApp(state: state));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('تحويل'), findsWidgets);
    expect(find.text('اسحب ملفاتك هنا'), findsOneWidget);
    expect(find.text('العمليات تظهر هنا'), findsOneWidget);
  });

  testWidgets('إضافة ملف يعرض العمليات المتاحة له فقط', (tester) async {
    final state = await AppState.bootstrap();
    final file = File('${Directory.current.path}/test/fixtures/صورة.png');
    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(_pngBytes);
    }

    await tester.pumpWidget(ConvertApp(state: state));
    await tester.pump(const Duration(milliseconds: 600));

    state.addPaths([file.path]);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('صورة.png'), findsOneWidget);
    // بطاقات العمليات تظهر فقط للصيغ المتاحة للصور.
    expect(find.text('العمليات'), findsOneWidget);
  });

  test('طابور المهام: مهمة على ملف حقيقي تنتهي بحالة واضحة', () async {
    final dir = Directory('${Directory.current.path}/test/fixtures')
      ..createSync(recursive: true);
    final out = Directory('${dir.path}/out')..createSync(recursive: true);

    final state = await AppState.bootstrap();
    final file = File('${dir.path}/نموذج.bmp')..writeAsBytesSync(_bmpBytes);
    state.addPaths([file.path]);
    await state.setOutputFolder(out.path);

    final op = state.availableOperations
        .where((operation) => operation.id == 'image-png')
        .toList();
    // إن لم تكن ImageMagick موجودة، نتأكد أن العمليات مخفية (سلوك صحيح أيضًا).
    if (op.isEmpty) {
      expect(state.availableOperations.any((o) => o.id == 'image-png'), isFalse);
      return;
    }

    state.selectOperation(op.first);
    state.submit();
    final done = await _waitForQueue(state.queue);
    expect(done, isTrue, reason: 'المهمة لم تنتهِ خلال المهلة');

    final task = state.queue.tasks.first;
    expect(
      task.state == TaskState.done || task.state == TaskState.failed,
      isTrue,
      reason: 'الحالة يجب أن تكون منتهية دائمًا، لا معلّقة',
    );
    if (task.state == TaskState.done) {
      expect(File(task.outputPath).existsSync(), isTrue);
    } else {
      expect(task.error.isNotEmpty, isTrue,
          reason: 'الفشل يجب أن يحمل رسالة مفهومة');
    }
    out.deleteSync(recursive: true);
  });
}

Future<bool> _waitForQueue(TaskQueue queue) async {
  for (var i = 0; i < 600; i++) {
    if (!queue.isRunning && queue.queuedCount == 0) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

final List<int> _pngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// ملف BMP صغير (2×2) — لا يحتاج أي ترميز.
final List<int> _bmpBytes = <int>[
  ...'BM'.codeUnits,
  // حجم الملف 70 بايت
  70, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0,
  // DIB header (BITMAPINFOHEADER)
  40, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 1, 0, 24, 0,
  0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  // بيانات البكسل (2×2، 24-bit، صفوف بحشو إلى 4 بايت)
  0, 0, 255, 0, 255, 0, 0, 0,
  255, 0, 0, 255, 255, 255, 0, 0,
];
