import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/capabilities.dart';
import '../../core/file_entry.dart';
import '../theme.dart';
import '../widgets.dart';
import 'file_dialog.dart';

/// شاشة العمل: الملفات، العمليات، خيارات العملية، وزر البدء.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key, required this.state});

  final AppState state;

  Future<void> _pickFiles(BuildContext context) async {
    final paths = await pickFilesWithSystemDialog();
    if (paths == null || paths.isEmpty) return;
    final result = state.addPaths(paths);
    if (!context.mounted) return;
    _showAddFeedback(context, result.added, result.rejected, result.duplicates);
  }

  void _showAddFeedback(
    BuildContext context,
    int added,
    int rejected,
    int duplicates,
  ) {
    if (added == 0 && rejected == 0 && duplicates == 0) return;
    final parts = <String>[];
    if (added > 0) parts.add('أُضيف $added ملف');
    if (duplicates > 0) parts.add('$duplicates مكرر');
    if (rejected > 0) parts.add('$rejected غير مدعوم');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(parts.join(' · ')),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _FilesPane(state: state, onPick: () => _pickFiles(context)),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: _OperationsPane(state: state),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// عمود الملفات
// ─────────────────────────────────────────────────────────────
class _FilesPane extends StatelessWidget {
  const _FilesPane({required this.state, required this.onPick});

  final AppState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final files = state.files;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('الملفات', style: context.theme.textTheme.headlineSmall),
            const SizedBox(width: 10),
            if (files.isNotEmpty)
              Pill('${files.length}', color: context.accent, dense: true),
            const Spacer(),
            if (files.isNotEmpty) ...[
              GhostButton(
                label: 'إضافة',
                icon: Icons.add_rounded,
                dense: true,
                onPressed: onPick,
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: 'تفريغ',
                icon: Icons.delete_sweep_rounded,
                dense: true,
                onPressed: () => state.clearFiles(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: files.isEmpty
              ? _DropZone(state: state, onPick: onPick)
              : _FileList(state: state, onPick: onPick),
        ),
      ],
    );
  }
}

class _DropZone extends StatefulWidget {
  const _DropZone({required this.state, required this.onPick});

  final AppState state;
  final VoidCallback onPick;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _hover
                  ? palette.accent.withAlpha(153)
                  : context.borderColor,
              width: _hover ? 1.6 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.accent.withAlpha(_hover ? 26 : 10),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedDropIcon(active: _hover),
                const SizedBox(height: 22),
                Text(
                  'اسحب ملفاتك هنا',
                  style: context.theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أو اضغط لاختيار ملفات من الجهاز',
                  style: context.theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    Pill('مستندات', dense: true),
                    Pill('صور', dense: true),
                    Pill('PDF', dense: true),
                    Pill('فيديو', dense: true),
                    Pill('صوت', dense: true),
                    Pill('أرشيف', dense: true),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '٩٥ صيغة · كل شيء يعمل على جهازك بلا إنترنت',
                  style: context.theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDropIcon extends StatefulWidget {
  const _AnimatedDropIcon({required this.active});
  final bool active;

  @override
  State<_AnimatedDropIcon> createState() => _AnimatedDropIconState();
}

class _AnimatedDropIconState extends State<_AnimatedDropIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
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
        final lift = (t < 0.5 ? t : 1 - t) * 10 - 5;
        return SizedBox(
          width: 150,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.accent.withAlpha(56),
                      palette.accent.withAlpha(0),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, lift),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: palette.gradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withAlpha(89),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.state, required this.onPick});

  final AppState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final files = state.files;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: files.length,
              onReorder: state.reorder,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.02).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              itemBuilder: (context, index) {
                final file = files[index];
                return _FileTile(
                  key: ValueKey(file.path),
                  index: index,
                  file: file,
                  onRemove: () => state.removeFile(file),
                  onOpen: () => state.bridge.revealPath(file.path),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
            child: Row(
              children: [
                Icon(Icons.drag_indicator_rounded,
                    size: 15, color: context.mutedColor),
                const SizedBox(width: 4),
                Text(
                  'اسحب لإعادة الترتيب',
                  style: context.theme.textTheme.labelMedium,
                ),
                const Spacer(),
                Text(
                  'الإجمالي ${_totalSize(files)}',
                  style: context.theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _totalSize(List<FileEntry> files) {
    final total = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    return FileEntry(
      path: 'x',
      category: FileCategory.document,
      sizeBytes: total,
    ).readableSize;
  }
}

class _FileTile extends StatefulWidget {
  const _FileTile({
    super.key,
    required this.index,
    required this.file,
    required this.onRemove,
    required this.onOpen,
  });

  final int index;
  final FileEntry file;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      index: widget.index > 8 ? 8 : widget.index,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
                ? (context.isDark
                    ? Colors.white.withAlpha(13)
                    : Colors.black.withAlpha(8))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 17,
                      color: context.mutedColor.withAlpha(178),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlyphBox(
                icon: widget.file.icon,
                color: widget.file.color,
                size: 40,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.file.extension.toUpperCase()} · ${widget.file.readableSize}',
                      style: context.theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _hover ? 1 : 0.35,
                child: Row(
                  children: [
                    IconBubble(
                      icon: Icons.folder_open_rounded,
                      tooltip: 'إظهار في المستكشف',
                      size: 32,
                      onPressed: widget.onOpen,
                    ),
                    IconBubble(
                      icon: Icons.close_rounded,
                      tooltip: 'إزالة',
                      size: 32,
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// عمود العمليات
// ─────────────────────────────────────────────────────────────
class _OperationsPane extends StatelessWidget {
  const _OperationsPane({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.isScanning) {
      return const Center(child: _ScanningTools());
    }
    if (!state.hasFiles) {
      return const Center(
        child: EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'العمليات تظهر هنا',
          message: 'أضف ملفًا واحدًا أو أكثر، وسيعرض التطبيق العمليات '
              'المتاحة لصيغته فقط — بلا قوائم طويلة ولا خيارات مربكة.',
        ),
      );
    }

    final operations = state.availableOperations;
    final category = state.activeCategory!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('العمليات', style: context.theme.textTheme.headlineSmall),
            const SizedBox(width: 10),
            Pill(category.label, color: context.accent, dense: true),
            const Spacer(),
            Text(
              '${operations.length} متاحة',
              style: context.theme.textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: operations.isEmpty
              ? EmptyState(
                  icon: Icons.extension_off_rounded,
                  title: 'لا توجد أداة جاهزة لهذه الصيغة',
                  message: 'كل الأدوات التي تخدم «${category.label}» غير موجودة '
                      'أو لا تعمل. أضفها إلى مجلد tools ثم أعد الفحص من الإعدادات.',
                  child: GhostButton(
                    label: 'فتح مجلد الأدوات',
                    icon: Icons.folder_rounded,
                    onPressed: () => state.bridge.openPath(state.toolsDir),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < operations.length; i++)
                        SizedBox(
                          width: 200,
                          child: StaggeredFadeIn(
                            index: i,
                            child: _OperationCard(
                              operation: operations[i],
                              selected:
                                  state.operation?.id == operations[i].id,
                              onTap: () => state.selectOperation(operations[i]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _OptionAndSubmit(state: state),
      ],
    );
  }
}

class _ScanningTools extends StatefulWidget {
  const _ScanningTools();

  @override
  State<_ScanningTools> createState() => _ScanningToolsState();
}

class _ScanningToolsState extends State<_ScanningTools>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _controller,
          child: Icon(Icons.autorenew_rounded,
              size: 30, color: context.accent),
        ),
        const SizedBox(height: 14),
        Text('جارٍ فحص الأدوات على الجهاز…',
            style: context.theme.textTheme.bodySmall),
      ],
    );
  }
}

class _OperationCard extends StatefulWidget {
  const _OperationCard({
    required this.operation,
    required this.selected,
    required this.onTap,
  });

  final ConvertOperation operation;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_OperationCard> createState() => _OperationCardState();
}

class _OperationCardState extends State<_OperationCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = widget.selected;
    return Tooltip(
      message: widget.operation.description,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.accent.withAlpha(56),
                        palette.accentAlt.withAlpha(26),
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : (context.isDark
                      ? Colors.white.withAlpha(_hover ? 15 : 9)
                      : Colors.white.withAlpha(_hover ? 242 : 191)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? palette.accent.withAlpha(166)
                    : context.borderColor,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.accent.withAlpha(56),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : const [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: selected ? 1.06 : 1,
                      child: GlyphBox(
                        icon: _iconFor(widget.operation.id),
                        color: selected ? palette.accent : context.mutedColor,
                        size: 34,
                        radius: 11,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          size: 17, color: palette.accent),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.operation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.titleMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.operation.outputLabel,
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String id) => switch (id) {
        'doc-pdf' || 'sheet-pdf' || 'slides-pdf' => Icons.picture_as_pdf_rounded,
        'doc-docx' => Icons.article_rounded,
        'doc-txt' => Icons.notes_rounded,
        'sheet-csv' => Icons.grid_on_rounded,
        'image-jpg' => Icons.photo_rounded,
        'image-webp' => Icons.bolt_rounded,
        'image-png' => Icons.image_rounded,
        'images-pdf' => Icons.collections_bookmark_rounded,
        'svg-png' => Icons.brush_rounded,
        'eps-pdf' => Icons.polyline_rounded,
        'pdf-merge' => Icons.merge_rounded,
        'pdf-extract' => Icons.call_split_rounded,
        'pdf-compress' => Icons.compress_rounded,
        'pdf-images' => Icons.burst_mode_rounded,
        'pdf-text' => Icons.text_snippet_rounded,
        'pdf-encrypt' => Icons.lock_rounded,
        'pdf-decrypt' => Icons.lock_open_rounded,
        'video-mp4' => Icons.movie_rounded,
        'video-gif' => Icons.gif_box_rounded,
        'video-thumb' => Icons.hide_image_rounded,
        'media-trim' => Icons.content_cut_rounded,
        'video-audio' => Icons.audiotrack_rounded,
        'video-merge' => Icons.playlist_add_rounded,
        'audio-mp3' => Icons.graphic_eq_rounded,
        'audio-wav' => Icons.waves_rounded,
        'archive-zip' => Icons.folder_zip_rounded,
        'archive-7z' => Icons.inventory_2_rounded,
        'archive-extract' => Icons.unarchive_rounded,
        _ => Icons.auto_fix_high_rounded,
      };
}

class _OptionAndSubmit extends StatefulWidget {
  const _OptionAndSubmit({required this.state});

  final AppState state;

  @override
  State<_OptionAndSubmit> createState() => _OptionAndSubmitState();
}

class _OptionAndSubmitState extends State<_OptionAndSubmit> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final op = state.operation;
    final option = op?.option;
    final palette = context.palette;
    final fileCount = state.files.length;
    final batch = op != null && op.supportsBatch && fileCount > 1;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (option != null) ...[
            Text(
              option.label,
              style: context.theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey('${op?.id}-${option.field.name}'),
              initialValue: state.options[option.field] ?? '',
              obscureText: option.kind == OptionKind.password,
              style: context.theme.textTheme.bodyMedium,
              onChanged: (value) => state.setOption(option.field, value),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                isDense: true,
                hintText: option.hint,
                hintStyle: context.theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                ),
                filled: true,
                fillColor: context.isDark
                    ? Colors.white.withAlpha(10)
                    : Colors.black.withAlpha(8),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: palette.accent, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مجلد النتائج',
                      style: context.theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.outputFolderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconBubble(
                icon: Icons.folder_open_rounded,
                tooltip: 'تغيير مجلد النتائج',
                onPressed: state.chooseOutputFolder,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (batch)
                Expanded(
                  child: Text(
                    'ستُضاف $fileCount مهام إلى الطابور',
                    style: context.theme.textTheme.labelMedium,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    op == null
                        ? 'اختر عملية للبدء'
                        : op.outputFolder
                            ? 'الناتج: مجلد'
                            : 'الناتج: ${op.outputLabel}',
                    style: context.theme.textTheme.labelMedium,
                  ),
                ),
              const SizedBox(width: 10),
              GradientButton(
                label: batch ? 'أضف $fileCount مهام' : 'ابدأ التحويل',
                icon: Icons.play_arrow_rounded,
                onPressed: op == null ? null : () => _submit(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    final result = widget.state.submit();
    if (result.error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(result.error!),
          backgroundColor: AppColors.danger,
        ));
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(result.count == 1
            ? 'أُضيفت المهمة إلى الطابور'
            : 'أُضيفت ${result.count} مهام إلى الطابور'),
        duration: const Duration(seconds: 2),
      ));
  }
}
