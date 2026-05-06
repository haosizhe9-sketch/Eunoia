import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/html_design_tokens.dart';

/// 今日任务大厅（对齐参考稿中的 Today's Tasks 仪表盘）。
class DailyTasksHubPage extends ConsumerWidget {
  const DailyTasksHubPage({super.key});

  static const Color _cyanGlow = HtmlDesignTokens.accent;
  static const Color _pinkGlow = Color(0xFFFF61D2);
  static const Color _goldGlow = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLocaleProvider);
    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -40,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      HtmlDesignTokens.primary.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: HtmlDesignTokens.compactSubpageAppBarPadding,
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.chevron_left, color: HtmlDesignTokens.textMain, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: HtmlDesignTokens.glassCard,
                          side: BorderSide(color: HtmlDesignTokens.glassBorder),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          s.dailyTasksHubAppBar,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            s.dailyTasksHubTitle,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                          ),
                          Text(
                            s.dailyTasksHubStreak,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _cyanGlow,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ModuleCard(
                        emoji: '🎧',
                        title: s.moduleListeningTitle,
                        subtitle: s.moduleListeningSubtitle,
                        accent: _cyanGlow,
                        onTap: () =>
                            context.push('/practice/daily-tasks/pick?skill=listening'),
                      ),
                      _ModuleCard(
                        emoji: '📖',
                        title: s.moduleReadingTitle,
                        subtitle: s.moduleReadingSubtitle,
                        accent: HtmlDesignTokens.primaryLight,
                        onTap: () =>
                            context.push('/practice/daily-tasks/pick?skill=reading'),
                      ),
                      _ModuleCard(
                        emoji: '✍️',
                        title: s.moduleWritingTitle,
                        subtitle: s.moduleWritingSubtitle,
                        accent: _goldGlow,
                        onTap: () =>
                            context.push('/practice/daily-tasks/pick?skill=writing'),
                      ),
                      _ModuleCard(
                        emoji: '🗣️',
                        title: s.moduleSpeakingTitle,
                        subtitle: s.moduleSpeakingSubtitle,
                        accent: _pinkGlow,
                        onTap: () => context.push('/practice/daily-tasks/speaking'),
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

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: accent.withValues(alpha: 0.15),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: HtmlDesignTokens.textSub.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
