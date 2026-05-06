import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/providers/daily_practice_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/theme/html_design_tokens.dart';

/// 练习页「每日任务」：听力 / 阅读 / 写作首次批改 + 每日一局爬词塔可获得 E 点并记录当日雅思估分。
class PracticeDailyTasksPanel extends ConsumerWidget {
  const PracticeDailyTasksPanel({super.key});

  static String _fmtBand(double? v) {
    if (v == null || v <= 0) {
      return '—';
    }
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLocaleProvider);
    final AppStrings s = AppStrings.of(context);
    final AsyncValue<DailyPracticeTodayView?> snap = ref.watch(dailyPracticeTodayProvider);

    return snap.when(
      loading: () => _shell(
        context,
        child: const Center(
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2, color: HtmlDesignTokens.accent),
          ),
        ),
      ),
      error: (Object e, StackTrace st) => _shell(
        context,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            s.practiceDailyTaskLoadError,
            style: const TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub),
          ),
        ),
      ),
      data: (DailyPracticeTodayView? d) {
        if (d == null) {
          return const SizedBox.shrink();
        }
        late final String wordTowerSubLine;
        if (!d.wordTowerRewarded) {
          wordTowerSubLine = s.dailyTaskWordTowerSubtitlePending;
        } else {
          final int f = d.wordTowerBestFloor ?? 0;
          wordTowerSubLine =
              f > 0 ? s.dailyTaskWordTowerBestToday(f) : s.dailyTaskWordTowerRewardDoneShort;
        }
        final int pot = d.potentialPointsPerDay();
        final int got = d.pointsEarnedToday();
        return _shell(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    s.practiceDailyTaskTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HtmlDesignTokens.textMain,
                      fontFamily: 'system-ui',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      s.practiceDailyTaskPoints(got, pot),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: HtmlDesignTokens.accent,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.practiceDailyTaskRewardLine(
                  AppDataService.dailyRewardListening,
                  AppDataService.dailyRewardReading,
                  AppDataService.dailyRewardWriting,
                  AppDataService.dailyRewardWordTower,
                ),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 14),
              _TaskRow(
                emoji: '🎧',
                title: s.skillListening,
                estimateLine: '${s.practiceTodayBand} ${_fmtBand(d.listeningBand)}',
                rewarded: d.listeningRewarded,
                rewardPts: AppDataService.dailyRewardListening,
                onTap: () => context.push('/practice/daily-tasks/pick?skill=listening'),
              ),
              const SizedBox(height: 10),
              _TaskRow(
                emoji: '📖',
                title: s.skillReading,
                estimateLine: '${s.practiceTodayBand} ${_fmtBand(d.readingBand)}',
                rewarded: d.readingRewarded,
                rewardPts: AppDataService.dailyRewardReading,
                onTap: () => context.push('/practice/daily-tasks/pick?skill=reading'),
              ),
              const SizedBox(height: 10),
              _TaskRow(
                emoji: '✍️',
                title: s.skillWriting,
                estimateLine: '${s.practiceTodayBand} ${_fmtBand(d.writingBand)}',
                rewarded: d.writingRewarded,
                rewardPts: AppDataService.dailyRewardWriting,
                onTap: () => context.push('/practice/daily-tasks/pick?skill=writing'),
              ),
              const SizedBox(height: 10),
              _TaskRow(
                emoji: '🧗',
                title: s.dailyTaskWordTowerTitle,
                estimateLine: wordTowerSubLine,
                rewarded: d.wordTowerRewarded,
                rewardPts: AppDataService.dailyRewardWordTower,
                onTap: () => context.push('/practice/word-tower'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HtmlDesignTokens.glassCard,
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
          border: Border.all(color: HtmlDesignTokens.glassBorder),
        ),
        child: child,
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.emoji,
    required this.title,
    required this.estimateLine,
    required this.rewarded,
    required this.rewardPts,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String estimateLine;
  final bool rewarded;
  final int rewardPts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: HtmlDesignTokens.glassBorder.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      estimateLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: HtmlDesignTokens.textSub.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              if (rewarded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$rewardPts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: HtmlDesignTokens.primaryLight,
                    ),
                  ),
                )
              else
                Text(
                  '+$rewardPts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HtmlDesignTokens.textSub.withValues(alpha: 0.75),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: HtmlDesignTokens.textSub.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}
