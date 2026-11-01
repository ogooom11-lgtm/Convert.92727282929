import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/capabilities.dart';
import '../../core/tool_registry.dart';
import '../theme.dart';
import '../widgets.dart';

/// شاشة الأدوات: حالة كل أداة، ومسار مجلد الأدوات، وإعادة الفحص.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final statuses = ToolId.values
        .map(state.registry.statusOf)
        .toList(growable: false);
    final ready = statuses.where((s) => s.isReady).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('الأدوات', style: context.theme.textTheme.headlineSmall),
              const SizedBox(width: 10),
              Pill('$ready من ${statuses.length}',
                  color: ready == statuses.length
                      ? AppColors.success
                      : AppColors.warning,
                  dense: true),
              const Spacer(),
              GhostButton(
                label: state.isScanning ? 'جارٍ الفحص…' : 'إعادة الفحص',
                icon: Icons.refresh_rounded,
                dense: true,
                onPressed: state.isScanning ? null : state.refreshTools,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'التطبيق لا يعالج الملفات بنفسه: ينسّق بين أدوات مجانية موجودة '
            'على جهازك. أي أداة غير موجودة تُخفى عملياتها من الواجهة.',
            style: context.theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_copy_rounded,
                        size: 16, color: context.accent),
                    const SizedBox(width: 8),
                    Text('مجلد الأدوات',
                        style: context.theme.textTheme.titleMedium),
                    const Spacer(),
                    GhostButton(
                      label: 'فتح المجلد',
                      icon: Icons.open_in_new_rounded,
                      dense: true,
                      onPressed: () => state.bridge.openPath(state.toolsDir),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  state.toolsDir,
                  textDirection: TextDirection.ltr,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ضع الأدوات في هذا المجلد (أو في مجلدات فرعية مثل bin). '
                  'يمكن استعمال نسخ محمولة: لا تُثبَّت أي أداة داخل النظام.',
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < statuses.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StaggeredFadeIn(
                index: i,
                child: _ToolRow(status: statuses[i]),
              ),
            ),
          const SizedBox(height: 6),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, left: 8),
                  child: Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.info),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إعداد إلزامي واحد',
                          style: context.theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'بناءات ويندوز من ImageMagick تحجب قراءة وكتابة PDF وPS '
                        'افتراضيًا. بدون تعديل policy.xml ستفشل عمليات PDF→صور '
                        'وEPS→PDF بلا رسالة واضحة. راجع ملف docs/الأدوات.md.',
                        style: context.theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.status});

  final ToolStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color tone, IconData icon, String label) = switch (status.state) {
      ToolState.checking => (context.mutedColor, Icons.more_horiz_rounded, 'فحص'),
      ToolState.ready => (AppColors.success, Icons.check_rounded, 'جاهزة'),
      ToolState.missing => (context.mutedColor, Icons.remove_rounded, 'غير موجودة'),
      ToolState.broken => (AppColors.danger, Icons.error_outline_rounded, 'لا تعمل'),
    };
    final operationsCount = kOperations
        .where((op) => op.tool == status.id || _sharesTool(op, status.id))
        .length;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withAlpha(33),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: tone.withAlpha(71)),
            ),
            child: Icon(icon, size: 17, color: tone),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(status.id.label,
                        style: context.theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Text(
                      '${operationsCount} عمليات',
                      style: context.theme.textTheme.labelMedium
                          ?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  status.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: status.isReady ? context.mutedColor : tone,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pill(label, color: tone, dense: true),
        ],
      ),
    );
  }

  /// بعض العمليات تخدمها أدوات مساندة (pdf-images تحتاج ImageMagick مثلًا).
  bool _sharesTool(ConvertOperation op, ToolId tool) {
    if (tool == ToolId.ffprobe) {
      return op.inputCategories.contains(FileCategory.video) ||
          op.inputCategories.contains(FileCategory.audio);
    }
    return false;
  }
}
