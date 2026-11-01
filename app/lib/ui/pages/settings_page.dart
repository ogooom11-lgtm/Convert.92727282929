import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// الإعدادات: المظهر، اللون، مجلد النتائج، التنبيهات، ومعلومات التطبيق.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الإعدادات', style: context.theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'كل شيء محفوظ على جهازك فقط. لا حساب، لا مزامنة، لا إحصاءات.',
            style: context.theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'المظهر',
            icon: Icons.palette_outlined,
            children: [
              SettingRow(
                title: 'وضع الواجهة',
                subtitle: 'حسب النظام يعني أن التطبيق يتبع إعداد ويندوز تلقائيًا.',
                trailing: _ThemeModeSelector(state: state),
              ),
              const SizedBox(height: 14),
              SettingRow(
                title: 'اللون الأساسي',
                subtitle: 'يغيّر أزرار التطبيق والتدرّجات فورًا.',
                trailing: _AccentPicker(state: state),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'النتائج',
            icon: Icons.folder_outlined,
            children: [
              SettingRow(
                title: 'حفظ النتائج بجوار الملف الأصلي',
                subtitle: 'داخل مجلد فرعي اسمه Convert-out. '
                    'أوقفه لاستخدام مجلد ثابت تختاره.',
                trailing: Switch(
                  value: settings.saveBesideSource,
                  onChanged: (value) => state.setSaveBesideSource(value),
                ),
              ),
              const SizedBox(height: 14),
              SettingRow(
                title: 'مجلد النتائج الثابت',
                subtitle: settings.outputFolder.isEmpty
                    ? 'لم تحدد مجلدًا — تستطيع اختياره الآن.'
                    : settings.outputFolder,
                trailing: GhostButton(
                  label: state.settings.outputFolder.isEmpty
                      ? 'اختيار مجلد'
                      : 'تغيير',
                  icon: Icons.folder_open_rounded,
                  dense: true,
                  onPressed: state.chooseOutputFolder,
                ),
              ),
              const SizedBox(height: 14),
              SettingRow(
                title: 'تنبيه عند انتهاء مهمة',
                subtitle: 'رسالة قصيرة أسفل النافذة عند نجاح التحويل أو فشله.',
                trailing: Switch(
                  value: settings.notifications,
                  onChanged: (value) => state.setNotifications(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'حول التطبيق',
            icon: Icons.info_outline_rounded,
            children: [
              _InfoLine(label: 'الاسم', value: 'تحويل — Convert'),
              _InfoLine(label: 'الإصدار', value: '1.0.0'),
              _InfoLine(label: 'المنصة', value: 'ويندوز · فلاتر'),
              _InfoLine(label: 'مجلد البيانات', value: state.dataDir, mono: true),
              const SizedBox(height: 10),
              Text(
                'التطبيق لا يتصل بالإنترنت ولا يرفع أي ملف. كل ما يحدث '
                'يحدث على جهازك.',
                style: context.theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: context.accent),
              const SizedBox(width: 8),
              Text(title, style: context.theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// صفّ إعداد: عنوان + وصف + عنصر تحكّم.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.theme.textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        trailing,
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: context.theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: mono ? TextDirection.ltr : TextDirection.rtl,
              style: context.theme.textTheme.bodySmall?.copyWith(
                fontSize: mono ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ثلاثة أزرار لاختيار وضع الواجهة (حسب النظام / داكن / فاتح).
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    const options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, 'النظام', Icons.brightness_auto_rounded),
      (ThemeMode.dark, 'داكن', Icons.dark_mode_rounded),
      (ThemeMode.light, 'فاتح', Icons.light_mode_rounded),
    ];
    final current = state.settings.themeMode;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withAlpha(10)
            : Colors.black.withAlpha(9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            _ModeChip(
              label: option.$2,
              icon: option.$3,
              selected: current == option.$1,
              onTap: () => state.setThemeMode(option.$1),
            ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatefulWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: widget.selected ? palette.gradient : null,
            color: widget.selected
                ? null
                : (_hover
                    ? (context.isDark
                        ? Colors.white.withAlpha(15)
                        : Colors.black.withAlpha(10))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(11),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: palette.accent.withAlpha(76),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: widget.selected ? Colors.white : context.mutedColor,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.selected ? Colors.white : context.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ثمانية ألوان أساسية، كل واحد يغيّر هوية التطبيق بالكامل.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final current = state.settings.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in AppSettings.accents)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Swatch(
              color: Color(color),
              selected: current == color,
              onTap: () => state.setAccent(color),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: _hover ? 1.12 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.selected ? 30 : 26,
            height: widget.selected ? 30 : 26,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.selected
                    ? Colors.white.withAlpha(230)
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(115),
                  blurRadius: widget.selected ? 14 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: widget.selected
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
