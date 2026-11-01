import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// بطاقة زجاجية: خلفية شبه شفافة + حدود رقيقة + ظل ناعم.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.borderColor,
    this.gradient,
    this.hover = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Gradient? gradient;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    final baseAlpha = context.isDark ? (hover ? 16 : 10) : (hover ? 250 : 219);

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? context.borderColor,
        width: 1,
      ),
      gradient: gradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withAlpha(baseAlpha),
              Colors.white.withAlpha((baseAlpha * 0.55).round()),
            ],
          ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(context.isDark ? 89 : 13),
          blurRadius: hover ? 26 : 18,
          offset: const Offset(0, 8),
        ),
      ],
    );

    final content = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

/// زر أساسي متدرّج مع تأثير ضغط وحركة لمعان.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final bool expand;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final palette = context.palette;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
      transformAlignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: widget.dense ? 16 : 22,
        vertical: widget.dense ? 11 : 14,
      ),
      decoration: BoxDecoration(
        gradient: enabled ? palette.gradient : null,
        color: enabled ? null : context.surfaceAlt,
        borderRadius: BorderRadius.circular(widget.dense ? 14 : 16),
        boxShadow: enabled && _hover
            ? [
                BoxShadow(
                  color: palette.accent.withAlpha(89),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ]
            : const [],
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: widget.dense ? 17 : 19,
              color: enabled ? Colors.white : context.mutedColor,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: widget.dense ? 13 : 14.5,
              fontWeight: FontWeight.w700,
              color: enabled ? Colors.white : context.mutedColor,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: content,
      ),
    );
  }
}

/// زر ثانوي شفاف.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final String? tooltip;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: widget.dense ? 12 : 16,
            vertical: widget.dense ? 8 : 11,
          ),
          decoration: BoxDecoration(
            color: _hover && enabled
                ? (context.isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(13))
                : (context.isDark
                    ? Colors.white.withAlpha(9)
                    : Colors.white.withAlpha(178)),
            borderRadius: BorderRadius.circular(widget.dense ? 12 : 14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.dense ? 15 : 17,
                  color: enabled ? context.textColor : context.mutedColor,
                ),
                if (widget.label.isNotEmpty) const SizedBox(width: 7),
              ],
              if (widget.label.isNotEmpty)
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: widget.dense ? 12.5 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: enabled ? context.textColor : context.mutedColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

/// زر أيقونة دائرية.
class IconBubble extends StatefulWidget {
  const IconBubble({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 36,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  State<IconBubble> createState() => _IconBubbleState();
}

class _IconBubbleState extends State<IconBubble> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final child = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hover
                ? (context.isDark
                    ? Colors.white.withAlpha(26)
                    : Colors.black.withAlpha(15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.size / 2.8),
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.5,
            color: widget.color ?? context.mutedColor,
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return child;
    return Tooltip(message: widget.tooltip!, child: child);
  }
}

/// شارة صغيرة ملوّنة.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.accent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 11,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.withAlpha(context.isDark ? 41 : 31),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withAlpha(71)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 12.5, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// أيقونة داخل مربع متدرّج — تُستخدم لبطاقات العمليات والملفات.
class GlyphBox extends StatelessWidget {
  const GlyphBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
    this.radius = 13,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(230),
            color.withAlpha(140),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(71),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }
}

/// شريط تقدم متدرّج مع حركة ناعمة.
class GradientProgress extends StatelessWidget {
  const GradientProgress({
    super.key,
    this.value,
    this.height = 6,
  });

  /// null = غير محدد (شريط متحرك).
  final double? value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: value == null
            ? const _IndeterminateBar()
            : Stack(
                children: [
                  Container(color: context.surfaceAlt),
                  FractionallySizedBox(
                    widthFactor: value!.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(gradient: palette.gradient),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar();

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          children: [
            Container(color: context.surfaceAlt),
            FractionallySizedBox(
              widthFactor: 0.42,
              alignment: Alignment(-2.4 + t * 3.2, 0),
              child: Container(
                decoration: BoxDecoration(gradient: palette.gradient),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// خلفية متدرّجة متحركة ببطء — تعطي إحساسًا حيًّا دون تشتيت.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDark;
    final strength = isDark ? 0.16 : 0.10;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? const [Color(0xFF0A0C13), Color(0xFF0B1020), Color(0xFF090A10)]
                  : const [Color(0xFFF7F8FC), Color(0xFFEFF2FA), Color(0xFFF9FAFD)],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * math.pi;
            return Stack(
              children: [
                Positioned(
                  top: -180 + math.sin(t) * 60,
                  right: -120 + math.cos(t) * 70,
                  child: _Blob(
                    color: palette.accent.withAlpha((strength * 255).round()),
                    size: 620,
                  ),
                ),
                Positioned(
                  bottom: -220 + math.cos(t) * 50,
                  left: -140 + math.sin(t * 0.8) * 80,
                  child: _Blob(
                    color: palette.accentAlt.withAlpha(((strength * 0.85) * 255).round()),
                    size: 560,
                  ),
                ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withAlpha(0)],
        ),
      ),
    );
  }
}

/// ظهور ناعم متتالٍ للعناصر عند أول عرض.
class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 55),
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final Duration step;
  final double offset;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.step * widget.index;
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// انتقال ناعم لتبديل المحتوى.
class SoftSwitcher extends StatelessWidget {
  const SoftSwitcher({super.key, required this.child, required this.keyValue});

  final Widget child;
  final Object keyValue;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(keyValue), child: child),
    );
  }
}

/// صندوق حالة فارغة.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.child,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? context.accent;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                tone.withAlpha(56),
                tone.withAlpha(10),
              ],
            ),
          ),
          child: Icon(icon, size: 32, color: tone),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: context.theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodySmall,
          ),
        ),
        if (child != null) ...[
          const SizedBox(height: 20),
          child!,
        ],
      ],
    );
  }
}
