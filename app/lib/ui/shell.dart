import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/capabilities.dart';
import '../core/task_queue.dart';
import 'pages/file_dialog.dart';
import 'pages/queue_page.dart';
import 'pages/selftest_page.dart';
import 'pages/settings_page.dart';
import 'pages/task_queue_scope.dart';
import 'pages/tools_page.dart';
import 'pages/workspace_page.dart';
import 'theme.dart';
import 'widgets.dart';

enum AppSection { workspace, queue, tools, selftest, settings }

/// الهيكل: شريط جانبي ثابت + رأس + محتوى متحرك.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state, this.initialSection});

  final AppState state;

  /// شاشة البداية (من وسيط سطر الأوامر --section=queue مثلًا).
  final AppSection? initialSection;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppSection _section = widget.initialSection ?? AppSection.workspace;
  bool _sidebarExpanded = true;
  bool _autoCollapsed = false;
  bool? _lastDark;

  late final AppState _state = widget.state;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onQueueChanged);
    _state.queue.addListener(_onQueueChanged);
    _state.queue.onTaskFinished = _onTaskFinished;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncCaption();
      // نبدأ بشريط مصغّر على النوافذ الضيقة بلا انتظار تفاعل.
      if (MediaQuery.sizeOf(context).width < 1120) {
        setState(() {
          _sidebarExpanded = false;
          _autoCollapsed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onQueueChanged);
    _state.queue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) setState(() {});
  }

  /// تنبيه قصير عند انتهاء كل مهمة (إن كان مفعّلًا).
  void _onTaskFinished(ConvertTask task) {
    if (!mounted || !_state.settings.notifications) return;
    if (!task.isOk && task.state != TaskState.failed) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(
              task.isOk ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 18,
              color: task.isOk ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.isOk
                    ? 'انتهى: ${task.title}'
                    : 'فشل: ${task.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                setState(() => _section = AppSection.queue);
              },
              child: const Text(
                'عرض',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ));
  }

  Future<void> _syncCaption() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      await _state.bridge.setCaptionColor(0x0A, 0x0C, 0x13);
    } else {
      await _state.bridge.setCaptionColor(0xF5, 0xF6, 0xFA);
    }
  }

  void _go(AppSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  /// رسالة قصيرة بعد الإضافة (مكرر / غير مدعوم / تم).
  void _announceAdd(({int added, int rejected, int duplicates}) result) {
    if (result.added == 0 && result.rejected == 0 && result.duplicates == 0) {
      return;
    }
    final parts = <String>[];
    if (result.added > 0) parts.add('أُضيف ${result.added} ملف');
    if (result.duplicates > 0) parts.add('${result.duplicates} مكرر');
    if (result.rejected > 0) parts.add('${result.rejected} غير مدعوم');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(parts.join(' · ')),
        duration: const Duration(seconds: 3),
      ));
  }

  /// «ضغط الكل»: ZIP بضغطة واحدة من أي شاشة.
  Future<void> _archiveAll() async {
    final op = operationById('archive-zip');
    if (op == null) return;
    if (!_state.registry.isOperationReady(op)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('7-Zip غير متاحة — أضفها إلى مجلد الأدوات أولًا.'),
          backgroundColor: AppColors.danger,
        ));
      return;
    }
    _state.queue.enqueue(
      op,
      _state.files.map((file) => file.path).toList(growable: false),
      options: const {},
      outputFolder: _state.effectiveOutputDir(),
    );
    _go(AppSection.queue);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('أُضيفت مهمة ضغط كل الملفات إلى الطابور'),
        duration: Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final width = MediaQuery.sizeOf(context).width;
    // الشريط الجانبي يتقلّص تلقائيًا عند ضيق النافذة، ويبقى قابلًا للتوسيع.
    final narrow = width < 1120;
    if (narrow && !_autoCollapsed) {
      _autoCollapsed = true;
      if (_sidebarExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _sidebarExpanded = false);
        });
      }
    } else if (!narrow && _autoCollapsed) {
      _autoCollapsed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _sidebarExpanded = true);
      });
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark != _lastDark) {
      _lastDark = isDark;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCaption();
      });
    }
    return AppStateScope(
      state: state,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AuroraBackground(
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                () async {
              final paths = await pickFilesShortcut();
              if (paths.isEmpty) return;
              _announceAdd(state.addPaths(paths));
            },
            const SingleActivator(LogicalKeyboardKey.digit1, control: true):
                () => _go(AppSection.workspace),
            const SingleActivator(LogicalKeyboardKey.digit2, control: true):
                () => _go(AppSection.queue),
            const SingleActivator(LogicalKeyboardKey.digit3, control: true):
                () => _go(AppSection.tools),
            const SingleActivator(LogicalKeyboardKey.digit4, control: true):
                () => _go(AppSection.selftest),
            const SingleActivator(LogicalKeyboardKey.digit5, control: true):
                () => _go(AppSection.settings),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Row(
                  children: [
                    _Sidebar(
                      section: _section,
                      expanded: _sidebarExpanded,
                      state: state,
                      onSelect: _go,
                      onToggle: () => setState(
                        () => _sidebarExpanded = !_sidebarExpanded,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _Header(
                            section: _section,
                            state: state,
                            onGoWorkspace: () => _go(AppSection.workspace),
                            onPickFiles: () async {
                              final paths = await pickFilesShortcut();
                              if (paths.isEmpty) return;
                              _announceAdd(state.addPaths(paths));
                            },
                            onArchive: _archiveAll,
                            onQueueTap: () => _go(AppSection.queue),
                          ),
                          Expanded(
                            child: SoftSwitcher(
                              keyValue: _section,
                              child: _pageFor(_section),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _pageFor(AppSection section) => switch (section) {
        AppSection.workspace => WorkspacePage(state: _state),
        AppSection.queue => QueuePage(state: _state),
        AppSection.tools => ToolsPage(state: _state),
        AppSection.selftest => SelfTestPage(state: _state),
        AppSection.settings => SettingsPage(state: _state),
      };
}

/// اختصار Ctrl+O — فتح نافذة اختيار الملفات.
Future<List<String>> pickFilesShortcut() async {
  final paths = await pickFilesWithSystemDialog();
  return paths ?? const [];
}

// ─────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.expanded,
    required this.state,
    required this.onSelect,
    required this.onToggle,
  });

  final AppSection section;
  final bool expanded;
  final AppState state;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: expanded ? 224 : 82,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withAlpha(9)
            : Colors.white.withAlpha(242),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 71 : 13),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _Brand(expanded: expanded),
          const SizedBox(height: 22),
          _NavItem(
            icon: Icons.dashboard_customize_rounded,
            label: 'العمل',
            shortcut: 'Ctrl+1',
            selected: section == AppSection.workspace,
            expanded: expanded,
            onTap: () => onSelect(AppSection.workspace),
          ),
          _NavItem(
            icon: Icons.layers_rounded,
            label: 'الطابور',
            shortcut: 'Ctrl+2',
            selected: section == AppSection.queue,
            expanded: expanded,
            badge: state.queue.queuedCount + (state.queue.isRunning ? 1 : 0),
            onTap: () => onSelect(AppSection.queue),
          ),
          _NavItem(
            icon: Icons.extension_rounded,
            label: 'الأدوات',
            shortcut: 'Ctrl+3',
            selected: section == AppSection.tools,
            expanded: expanded,
            warning: state.registry.missingTools.isNotEmpty,
            onTap: () => onSelect(AppSection.tools),
          ),
          _NavItem(
            icon: Icons.science_rounded,
            label: 'الفحص الشامل',
            shortcut: 'Ctrl+4',
            selected: section == AppSection.selftest,
            expanded: expanded,
            warning: state.testResults.values.any((r) => !r.ok),
            onTap: () => onSelect(AppSection.selftest),
          ),
          _NavItem(
            icon: Icons.tune_rounded,
            label: 'الإعدادات',
            shortcut: 'Ctrl+5',
            selected: section == AppSection.settings,
            expanded: expanded,
            onTap: () => onSelect(AppSection.settings),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _ToolsHealth(expanded: expanded, state: state),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: IconBubble(
              icon: expanded
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
              tooltip: expanded ? 'تصغير الشريط' : 'توسيع الشريط',
              size: 36,
              onPressed: onToggle,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).withAccentGlow(palette);
  }
}

extension on Widget {
  Widget withAccentGlow(AppPalette palette) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.accent.withAlpha(13),
              Colors.transparent,
            ],
          ),
        ),
        child: this,
      );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: palette.gradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withAlpha(102),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                color: Colors.white, size: 21),
          ),
          if (expanded) ...[
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تحويل',
                  style: context.theme.textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Convert',
                  textDirection: TextDirection.ltr,
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
    this.shortcut,
    this.badge = 0,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final String? shortcut;
  final int badge;
  final bool warning;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = widget.selected;
    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 14,
            vertical: 3,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 0,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            gradient: selected ? palette.gradient : null,
            color: selected
                ? null
                : (_hover
                    ? (context.isDark
                        ? Colors.white.withAlpha(15)
                        : Colors.black.withAlpha(9))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.accent.withAlpha(76),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: widget.expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    widget.icon,
                    size: 19,
                    color: selected ? Colors.white : context.mutedColor,
                  ),
                  if (widget.badge > 0 && !widget.expanded)
                    Positioned(
                      top: -4,
                      left: -5,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (widget.warning && !widget.expanded)
                    Positioned(
                      top: -3,
                      left: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Colors.white : context.textColor,
                    ),
                  ),
                ),
                if (widget.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withAlpha(64)
                          : AppColors.info.withAlpha(46),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${widget.badge}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.info,
                      ),
                    ),
                  ),
                if (widget.warning)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppColors.warning),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!widget.expanded && widget.shortcut != null) {
      return Tooltip(
        message: '${widget.label} · ${widget.shortcut}',
        child: content,
      );
    }
    return content;
  }
}

class _ToolsHealth extends StatelessWidget {
  const _ToolsHealth({required this.expanded, required this.state});

  final bool expanded;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ready = state.registry.readyCount;
    final total = state.registry.totalCount;
    final ratio = total == 0 ? 0.0 : ready / total;
    final tone = ratio == 1
        ? AppColors.success
        : ratio > 0.5
            ? AppColors.warning
            : AppColors.danger;

    return Tooltip(
      message: 'الأدوات الجاهزة: $ready من $total',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 12 : 8,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: context.isDark
              ? Colors.white.withAlpha(8)
              : Colors.black.withAlpha(6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                ),
                if (expanded) ...[
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'أدوات جاهزة $ready/$total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.labelMedium?.copyWith(
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    Container(color: context.surfaceAlt),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(color: tone),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.state,
    required this.onPickFiles,
    required this.onQueueTap,
    required this.onGoWorkspace,
    required this.onArchive,
  });

  final AppSection section;
  final AppState state;
  final VoidCallback onPickFiles;
  final VoidCallback onQueueTap;
  final VoidCallback onGoWorkspace;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final titles = {
      AppSection.workspace: ('مرحبًا بك', 'أضف ملفاتك واختر ما تريد فعله بها — كله على جهازك.'),
      AppSection.queue: ('الطابور', 'متابعة المهام: الحالة، الوقت، ورسائل الخطأ الحقيقية.'),
      AppSection.tools: ('الأدوات', 'حالة الأدوات المحلية ومسار مجلدها.'),
      AppSection.selftest: (
        'الفحص الشامل',
        'زر واحد يجرّب كل أداة على ملف حقيقي — بلا طرفية ولا أوامر.'
      ),
      AppSection.settings: ('الإعدادات', 'تخصيص المظهر ومكان النتائج.'),
    };
    final (title, subtitle) = titles[section]!;
    final queue = state.queue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.theme.textTheme.headlineMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: context.theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (section != AppSection.workspace)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GhostButton(
                label: 'العمل',
                icon: Icons.dashboard_customize_rounded,
                dense: true,
                onPressed: onGoWorkspace,
              ),
            ),
          if (section == AppSection.workspace) ...[
            if (state.hasFiles)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: GhostButton(
                  label: 'ضغط الكل',
                  icon: Icons.folder_zip_rounded,
                  dense: true,
                  onPressed: onArchive,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: GhostButton(
                label: 'اختيار ملفات',
                icon: Icons.add_rounded,
                dense: true,
                onPressed: onPickFiles,
              ),
            ),
          ],
          _QueueChip(
            queue: queue,
            onTap: onQueueTap,
          ),
        ],
      ),
    );
  }
}

class _QueueChip extends StatefulWidget {
  const _QueueChip({required this.queue, required this.onTap});

  final TaskQueue queue;
  final VoidCallback onTap;

  @override
  State<_QueueChip> createState() => _QueueChipState();
}

class _QueueChipState extends State<_QueueChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    final running = queue.isRunning;
    final pending = queue.queuedCount;
    if (!running && pending == 0) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: context.accent.withAlpha(_hover ? 46 : 26),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: context.accent.withAlpha(89),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (running)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(context.accent),
                  ),
                )
              else
                Icon(Icons.schedule_rounded, size: 14, color: context.accent),
              const SizedBox(width: 8),
              Text(
                running
                    ? 'يعمل الآن${pending > 0 ? ' · $pending منتظرة' : ''}'
                    : '$pending في الانتظار',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
