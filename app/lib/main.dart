import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

/// نقطة الدخول.
///
/// التطبيق يفتح نافذة واحدة فقط: منع النسخ المتعددة مطبّق في طبقة ويندوز
/// الأصلية (windows/runner/main.cpp) قبل إنشاء أي نافذة.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.bootstrap();
  runApp(ConvertApp(state: state));
}

class ConvertApp extends StatelessWidget {
  const ConvertApp({super.key, required this.state});

  final AppState state;

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
          home: AppShell(state: state),
        );
      },
    );
  }
}
