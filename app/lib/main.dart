import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

/// نقطة الدخول.
///
/// التطبيق يفتح نافذة واحدة فقط: منع النسخ المتعددة مطبّق في طبقة ويندوز
/// الأصلية (windows/runner/main.cpp) قبل إنشاء أي نافذة.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.bootstrap();
  runApp(ConvertApp(state: state, initialSection: _sectionFromArgs(args)));
}

/// يدعم `convert.exe --section=queue|tools|settings|workspace`
/// (يُستخدم في لقطات الواجهة والاختبارات الآلية).
AppSection? _sectionFromArgs(List<String> args) {
  for (final arg in args) {
    if (!arg.startsWith('--section=')) continue;
    final value = arg.substring('--section='.length).trim();
    for (final section in AppSection.values) {
      if (section.name == value) return section;
    }
  }
  return null;
}

class ConvertApp extends StatelessWidget {
  const ConvertApp({super.key, required this.state, this.initialSection});

  final AppState state;
  final AppSection? initialSection;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state.settings,
      builder: (context, _) {
        final accent = state.settings.accentColor;
        return MaterialApp(
          title: 'تحويل — Convert',
          debugShowCheckedModeBanner: false,
          themeMode: state.settings.themeMode,
          theme: buildTheme(Brightness.light, accent),
          darkTheme: buildTheme(Brightness.dark, accent),
          locale: const Locale('ar'),
          builder: (context, child) {
            // اتجاه الواجهة من اليمين إلى اليسار، وخط عربي موحّد.
            // (Directionality يُضبط من AppShell بعد أن يعرف الثيم الحالي.)
            return MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AppShell(state: state, initialSection: initialSection),
        );
      },
    );
  }
}
