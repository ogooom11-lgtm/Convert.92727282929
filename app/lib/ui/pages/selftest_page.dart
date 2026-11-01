import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/capabilities.dart';
import '../../core/self_test.dart';
import '../theme.dart';
import '../widgets.dart';

/// «الفحص الشامل»: يجرّب كل أداة تحويلًا حقيقيًا بدل قراءة رقم إصدارها.
///
/// وجود هذه الشاشة يعني أن المستخدم لا يحتاج أن يفتح طرفية أبدًا ليعرف
/// إن كانت الحزمة سليمة: زر واحد يعطيه الجواب.
class SelfTestPage extends StatelessWidget {
  const SelfTestPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final results = state.testResults;
    final passed = state.testsPassed;
    final total = ToolId.values.length;
    final running = state.isTestingAll;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('الفحص الشامل', style: context.theme.textTheme.headlineSmall),
              const SizedBox(width: 10),
              if (results.isNotEmpty)
                Pill(
                  '$passed / $total',
                  color: passed == total ? AppColors.success : AppColors.warning,
                  dense: true,
                ),
              const Spacer(),
              GradientButton(
                label: running
                    ? 'جارٍ الفحص…'
                    : (results.isEmpty ? 'ابدأ الفحص الشامل' : 'أعد الفحص'),
                icon: running ? Icons.hourglass_top_rounded : Icons.science_rounded,
                dense: true,
                onPressed: running ? null : state.runSelfTest,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'بدل قراءة «رقم الإصدار»، يأخذ كل أداة ويجعلها تنتج ملفًا حقيقيًا: '
            'صورة عربية الاسم، ملف PS، PDF، فيديو تجريبي، أرشيف مُستخرج، '
            'ومستند عربي إلى PDF. نجاح الفحص يعني أن العمليات ستنجح.',
            style: context.theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        results.isEmpty
                            ? 'لم يُجرَ فحص بعد'
                            : (passed == total
                                ? 'كل شيء جاهز — التطبيق كامل الوظائف'
                                : '$passed من $total أدوات تعمل'),
                        style: context.theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        results.isEmpty
                            ? 'اضغط «ابدأ الفحص الشامل» — يستغرق من ١٠ إلى ٦٠ ثانية.'
                            : (passed == total
                                ? 'الأدوات الثمانية أنتجت ملفات حقيقية بنجاح.'
                                : 'الأدوات غير الناجحة تُخفى عملياتها من شاشة العمل '
                                    'تلقائيًا؛ راجع الرسالة لمعرفة السبب.'),
                        style: context.theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      GradientProgress(
                        value: results.isEmpty ? 0 : passed / total,
                        height: 7,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                _ScoreRing(passed: passed, total: total),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final tool in ToolId.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ResultRow(
                tool: tool,
                result: results[tool],
                running: running && state.testingTool == tool,
                awaiting: running && results[tool] == null,
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
                  child: Icon(Icons.shield_outlined, size: 16, color: AppColors.info),
                ),
                Expanded(
                  child: Text(
                    'الفحص يعمل بالكامل على جهازك: ينشئ ملفات صغيرة في مجلد مؤقت، '
                    'يجرّب الأدوات عليها، ثم يحذفها. لا شيء يُرسل إلى الإنترنت.',
                    style: context.theme.textTheme.bodySmall,
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

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.passed, required this.total});

  final int passed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : passed / total;
    final palette = context.palette;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 7,
                backgroundColor: context.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio >= 1 ? AppColors.success : palette.accent,
                ),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$passed',
                style: context.theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  height: 1.1,
                ),
              ),
              Text(
                'من $total',
                style: context.theme.textTheme.labelMedium?.copyWith(
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.tool,
    required this.result,
    required this.running,
    required this.awaiting,
  });

  final ToolId tool;
  final SelfTestResult? result;
  final bool running;
  final bool awaiting;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final (Color tone, IconData icon, String label) = result == null
        ? (
            awaiting ? AppColors.info : context.mutedColor,
            awaiting ? Icons.more_horiz_rounded : Icons.circle_outlined,
            awaiting ? 'في الانتظار' : 'لم يُفحص',
          )
        : result.ok
            ? (AppColors.success, Icons.check_rounded, 'يعمل')
            : (AppColors.danger, Icons.close_rounded, 'لا يعمل');

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      radius: 16,
      borderColor: result != null && !result.ok
          ? AppColors.danger.withAlpha(64)
          : null,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withAlpha(34),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: tone.withAlpha(71)),
            ),
            child: running
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(tone),
                    ),
                  )
                : Icon(icon, size: 17, color: tone),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tool.label,
                        style: context.theme.textTheme.titleMedium),
                    if (result != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${result.duration.inMilliseconds} م.ث',
                        style: context.theme.textTheme.labelMedium
                            ?.copyWith(fontSize: 10),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  result?.message ?? 'لم يُجرَّب بعد',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: result == null || result.ok
                        ? context.mutedColor
                        : AppColors.danger,
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
}
