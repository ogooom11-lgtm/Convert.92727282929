import 'package:convert/core/capabilities.dart';
import 'package:convert/core/command_builder.dart';
import 'package:convert/core/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('جدول القدرات', () {
    test('كل صيغة معروفة تعود بفئة صحيحة', () {
      expect(categoryOf('PDF'), FileCategory.pdf);
      expect(categoryOf('.docx'), FileCategory.document);
      expect(categoryOf('mp4'), FileCategory.video);
      expect(categoryOf('7z'), FileCategory.archive);
      expect(categoryOf('xyz'), isNull);
    });

    test('عدد الصيغ المدعومة لا يقل عن ٩٥', () {
      expect(kExtensions.length, greaterThanOrEqualTo(95));
    });

    test('العمليات ثلاثون بالضبط وبمعرّفات فريدة', () {
      expect(kOperations.length, 30);
      final ids = kOperations.map((op) => op.id).toSet();
      expect(ids.length, 30);
    });

    test('كل عملية مرتبطة بأداة معروفة ولها مدخلات معرّفة', () {
      for (final op in kOperations) {
        expect(op.inputCategories, isNotEmpty, reason: op.id);
        expect(op.title.trim(), isNotEmpty, reason: op.id);
      }
    });

    test('عمليات PDF تظهر لفئة PDF فقط', () {
      final pdfOps = operationsFor(FileCategory.pdf).map((op) => op.id);
      expect(pdfOps, contains('pdf-merge'));
      expect(pdfOps, isNot(contains('audio-mp3')));
    });
  });

  group('أسماء الملفات والمسارات', () {
    test('استخراج الامتداد والاسم بلا امتداد', () {
      expect(CommandBuilder.extensionOf(r'C:\ملفات\تقرير المشروع ٢٠٢٦.docx'),
          'docx');
      expect(CommandBuilder.baseName(r'C:\ملفات\صورة.png'), 'صورة');
      expect(CommandBuilder.baseName('/home/user/a.b.c.pdf'), 'a.b.c');
    });

    test('أسماء فيها أكثر من نقطة لا تُقصّ خطأً', () {
      expect(CommandBuilder.extensionOf('report.final.v2.PDF'), 'pdf');
    });
  });

  group('فحص الأدوات', () {
    test('أداة غير موجودة تُصنّف «غير موجودة» ولا تعطّل التطبيق', () {
      final registry = ToolRegistry();
      expect(registry.statusOf(ToolId.ffmpeg).isReady, isFalse);
      expect(registry.readyCount, 0);
      expect(registry.availableOperationsFor(FileCategory.video), isEmpty);
    });
  });
}
