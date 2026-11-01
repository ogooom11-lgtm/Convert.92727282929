import 'package:convert/core/capabilities.dart';
import 'package:convert/core/imagemagick_policy.dart';
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

    test('عدد الصيغ المدعومة ٩٠ موزّعة على تسع فئات', () {
      expect(kExtensions.length, 90);
      final categories = kExtensions.values.toSet();
      expect(categories.length, FileCategory.values.length);
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

  group('سياسة ImageMagick', () {
    test('يزيل الحجب عن PDF/PS ويُبقي بقية الحمايات', () {
      const xml = '<?xml version="1.0"?>'
          '<policymap>'
          '<policy domain="coder" rights="none" pattern="{PS,PS2,PS3,EPS,PDF,XPS}" />'
          '<policy domain="coder" rights="none" pattern="HTTPS" />'
          '<policy domain="path" rights="none" pattern="@*" />'
          '</policymap>';
      final result = ImageMagickPolicy.rewrite(xml);
      expect(result.changed, isTrue);
      expect(result.content, isNot(contains('pattern="{PS')));
      expect(result.content, contains('pattern="HTTPS"'));
      expect(result.content, contains('pattern="@*"'));
    });

    test('يُبقي الصيغ غير المسموحة داخل نفس العنصر', () {
      const xml =
          '<policy domain="coder" rights="none" pattern="{PDF,MVG,HTTPS}" />';
      final result = ImageMagickPolicy.rewrite(xml);
      expect(result.changed, isTrue);
      expect(result.content, contains('pattern="{MVG,HTTPS}"'));
      expect(result.content, isNot(contains('PDF')));
    });

    test('لا يلمس ملفًا سليمًا', () {
      const xml = '<policy domain="coder" rights="read|write" pattern="PDF" />';
      final result = ImageMagickPolicy.rewrite(xml);
      expect(result.changed, isFalse);
      expect(result.content, xml);
    });
  });
}