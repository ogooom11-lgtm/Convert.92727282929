import 'package:flutter/material.dart';

/// لوحة الألوان والخطوط — مصدر واحد لكل شكل في التطبيق.
class AppColors {
  const AppColors._();

  // الوضع الداكن
  static const darkBg = Color(0xFF090B11);
  static const darkSurface = Color(0xFF12151F);
  static const darkSurfaceAlt = Color(0xFF181D2B);
  static const darkBorder = Color(0x1AFFFFFF);
  static const darkText = Color(0xFFF3F5FA);
  static const darkMuted = Color(0xFF96A0B5);

  // الوضع الفاتح
  static const lightBg = Color(0xFFEEF0F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFE3E7F0);
  static const lightBorder = Color(0x1F1B2240);
  static const lightText = Color(0xFF111629);
  static const lightMuted = Color(0xFF606B83);

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const info = Color(0xFF60A5FA);
}

/// ألوان مبنية على اللون الأساسي المختار.
class AppPalette {
  AppPalette(this.accent);

  final Color accent;

  /// اللون الثاني للتدرّج: إزاحة درجة اللون نحو السماوي مع تشبّع أعلى.
  Color get accentAlt {
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withHue((hsl.hue + 42) % 360)
        .withSaturation((hsl.saturation + 0.12).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 0.85))
        .toColor();
  }

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentAlt],
      );

  Color get soft => accent.withAlpha(36);
  Color get softer => accent.withAlpha(18);
}

/// الثيم الكامل.
ThemeData buildTheme(Brightness brightness, Color accent) {
  final palette = AppPalette(accent);
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: Colors.white,
    primaryContainer: palette.soft,
    onPrimaryContainer: isDark ? Colors.white : AppColors.lightText,
    secondary: palette.accentAlt,
    onSecondary: Colors.white,
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: isDark ? AppColors.darkText : AppColors.lightText,
    surfaceContainerHighest:
        isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
    onSurfaceVariant: isDark ? AppColors.darkMuted : AppColors.lightMuted,
    outline: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    error: AppColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Cairo',
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
  );

  TextStyle body(double size, FontWeight weight, Color color,
          {double? height, double? spacing}) =>
      TextStyle(
        fontFamily: 'Cairo',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  final text = isDark ? AppColors.darkText : AppColors.lightText;
  final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

  return base.copyWith(
    scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
    canvasColor: isDark ? AppColors.darkBg : AppColors.lightBg,
    dividerColor: scheme.outline,
    textTheme: TextTheme(
      displaySmall: body(34, FontWeight.w700, text, height: 1.35),
      headlineMedium: body(26, FontWeight.w700, text, height: 1.4),
      headlineSmall: body(21, FontWeight.w700, text, height: 1.4),
      titleLarge: body(18, FontWeight.w600, text, height: 1.45),
      titleMedium: body(15.5, FontWeight.w600, text, height: 1.5),
      bodyLarge: body(15, FontWeight.w500, text, height: 1.65),
      bodyMedium: body(13.5, FontWeight.w400, text, height: 1.7),
      bodySmall: body(12, FontWeight.w400, muted, height: 1.6),
      labelLarge: body(14, FontWeight.w600, text),
      labelMedium: body(12, FontWeight.w500, muted),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232A3B) : const Color(0xFF20243A),
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: body(12.5, FontWeight.w500, Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF1D2333) : const Color(0xFF1B2031),
      contentTextStyle: body(13.5, FontWeight.w500, Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 12,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: MaterialStatePropertyAll(
        (isDark ? Colors.white : Colors.black).withAlpha(31),
      ),
      radius: const Radius.circular(8),
      thickness: const MaterialStatePropertyAll(6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected) ? Colors.white : null,
      ),
      trackColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected) ? accent : null,
      ),
      trackOutlineColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected)
            ? accent
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: palette.soft,
      selectionHandleColor: accent,
    ),
  );
}

/// امتدادات مساعدة للقراءة من الثيم.
extension AppThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get textColor =>
      isDark ? AppColors.darkText : AppColors.lightText;
  Color get mutedColor =>
      isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get surfaceColor =>
      isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surfaceAlt =>
      isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
  Color get borderColor =>
      isDark ? AppColors.darkBorder : AppColors.lightBorder;
  AppPalette get palette => AppPalette(scheme.primary);
}
