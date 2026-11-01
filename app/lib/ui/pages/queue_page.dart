import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/task_queue.dart';
import '../theme.dart';
import '../widgets.dart';
import 'task_queue_scope.dart';

/// الطابور: مهمة واحدة في كل مرة، مع حالات واضحة وأزرار تحكّم.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final queue = state.queue;
    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final tasks = queue.tasks;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('الطابور', style: context.theme.textTheme.headlineSmall),
                  const SizedBox(width: 10),
                  if (queue.queuedCount > 0)
                    Pill('${queue.queuedCount} في الانتظار',
                        color: AppColors.warning, dense: true),
                  if (queue.isRunning)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Pill('قيد التنفيذ',
                          color: AppColors.info, dense: true),
                    ),
                  const Spacer(),
                  if (queue.isRunning)
                    GhostButton(
                      label: 'إلغاء الجارية',
                      icon: Icons.stop_circle_outlined,
                      dense: true,
                      onPressed: queue.cancelActive,
                    ),
                  if (queue.queuedCount > 0) ...[
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'إلغاء المنتظرة',
                      icon: Icons.clear_all_rounded,
                      dense: true,
                      onPressed: queue.cancelQueued,
                    ),
                  ],
                  if (queue.tasks.any((t) => t.isFinished)) ...[
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'إفراغ المنتهية',
                      icon: Icons.cleaning_services_rounded,
                      dense: true,
                      onPressed: queue.clearFinished,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _Summary(queue: queue),
              const SizedBox(height: 14),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.inbox_rounded,
                          title: 'الطابور فارغ',
                          message: 'أضف ملفات من شاشة العمل، اختر عملية، '
                              'واضغط «ابدأ التحويل». ستظهر هنا حالة كل مهمة '
                              'مع إمكانية الإلغاء وإعادة المحاولة.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return StaggeredFadeIn(
                            index: index > 8 ? 8 : index,
                            child: _TaskCard(
                              task: tasks[index],
                              queue: queue,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.queue});

  final TaskQueue queue;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('في الانتظار', queue.queuedCount, AppColors.warning),
      ('تم', queue.doneCount, AppColors.success),
      ('فشل', queue.failedCount, AppColors.danger),
    ];
    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              radius: 16,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(item.$1, style: context.theme.textTheme.labelMedium),
                  const Spacer(),
                  Text(
                    '${item.$2}',
                    style: context.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item != items.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({required this.task, required this.queue});

  final ConvertTask task;
  final TaskQueue queue;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final (Color tone, IconData icon, String label) = switch (task.state) {
      TaskState.queued => (AppColors.warning, Icons.schedule_rounded, 'في الانتظار'),
      TaskState.running => (AppColors.info, Icons.sync_rounded, 'قيد التنفيذ'),
      TaskState.done => (AppColors.success, Icons.check_circle_rounded, 'تم'),
      TaskState.failed => (AppColors.danger, Icons.error_rounded, 'فشل'),
      TaskState.cancelled => (context.mutedColor, Icons.block_rounded, 'أُلغي'),
    };

    final running = task.state == TaskState.running;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      borderColor: running
          ? context.accent.withAlpha(115)
          : task.state == TaskState.failed
              ? AppColors.danger.withAlpha(76)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GlyphBox(
                icon: icon,
                color: tone,
                size: 38,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.operation.title} · ${task.inputs.length} ملف',
                      style: context.theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Pill(label, color: tone, dense: true),
              const SizedBox(width: 10),
              if (task.state == TaskState.done)
                const SizedBox(width: 4),
              if (task.state == TaskState.done)
                _OpenButtons(path: task.outputPath, isFolder: task.outputIsFolder),
              if (task.state == TaskState.failed ||
                  task.state == TaskState.cancelled) ...[
                IconBubble(
                  icon: Icons.refresh_rounded,
                  tooltip: 'إعادة المحاولة',
                  onPressed: () => widget.queue.retry(task),
                ),
              ],
              if (running)
                IconBubble(
                  icon: Icons.stop_rounded,
                  tooltip: 'إلغاء',
                  color: AppColors.danger,
                  onPressed: widget.queue.cancelActive,
                )
              else if (task.state == TaskState.queued)
                IconBubble(
                  icon: Icons.close_rounded,
                  tooltip: 'إزالة من الطابور',
                  onPressed: () => widget.queue.cancelTask(task),
                ),
              if (task.isFinished)
                IconBubble(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'حذف من القائمة',
                  onPressed: () => widget.queue.removeTask(task),
                ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 12),
            const GradientProgress(value: null, height: 4),
            if (task.lastLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.lastLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ],
          if (task.state == TaskState.failed && task.error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(23),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.danger.withAlpha(56),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, left: 6),
                    child: Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.danger),
                  ),
                  Expanded(
                    child: Text(
                      task.error,
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (task.state == TaskState.done && task.elapsed.inMilliseconds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'انتهت في ${_formatDuration(task.elapsed)}',
                style: context.theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} ثانية';
    }
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes د $seconds ث';
  }
}

/// زرّا «فتح الناتج» و«إظهار في المجلد».
class _OpenButtons extends StatelessWidget {
  const _OpenButtons({required this.path, required this.isFolder});

  final String path;
  final bool isFolder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GhostButton(
          label: isFolder ? 'المجلد' : 'فتح',
          icon: Icons.play_circle_outline_rounded,
          dense: true,
          onPressed: path.isEmpty
              ? null
              : () => _open(context, reveal: false),
        ),
        const SizedBox(width: 6),
        IconBubble(
          icon: Icons.folder_open_rounded,
          tooltip: 'إظهار في المستكشف',
          onPressed: path.isEmpty ? null : () => _open(context, reveal: true),
        ),
      ],
    );
  }

  void _open(BuildContext context, {required bool reveal}) {
    final state = AppStateScope.read(context);
    if (reveal) {
      state.bridge.revealPath(path);
    } else {
      state.bridge.openPath(path);
    }
  }
}

extension TaskOutputX on ConvertTask {
  bool get outputIsFolder =>
      operation.outputFolder || operation.id == 'pdf-images';
}
