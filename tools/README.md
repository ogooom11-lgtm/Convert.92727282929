# مجلد الأدوات

هذا المجلد يجب أن يحتوي الملفات التنفيذية للأدوات السبع. **لا تُرفع إلى Git**
(انظر `.gitignore`) لأن حجمها ~٧٠٠–٨٥٠ م.ب.

## الملفات المطلوبة

```
tools/
├── ffmpeg.exe        ← FFmpeg (gyan.dev build, essentials)
├── ffprobe.exe       ← يأتي مع FFmpeg
├── magick.exe        ← ImageMagick (Portable Q16 x64) + ملفات DLL المجاورة
├── soffice.exe       ← LibreOffice (مع مجلد program)
├── 7z.exe            ← 7-Zip (Extra)
├── 7z.dll            ← إلزامي مع 7z.exe
├── qpdf.exe          ← qpdf (msvc64)
├── gswin64c.exe      ← Ghostscript
└── pdftotext.exe     ← Poppler + كل DLLs من Library\bin
```

يمكن وضعها داخل مجلدات فرعية (مثل `tools/bin/`) — التطبيق يبحث متكررًا.

## إعداد إلزامي

عدّل `policy.xml` في ImageMagick لتسمح بقراءة وكتابة `PDF` و`PS` و`EPS`،
وإلا ستفشل «PDF → صور» و«EPS → PDF» بلا رسالة واضحة.

التفاصيل الكاملة في [../docs/الأدوات.md](../docs/الأدوات.md).
