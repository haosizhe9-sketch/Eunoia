import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_locale.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/html_design_tokens.dart';

/// 进入听力 / 阅读 / 写作真题页面前的套题选择。
class DailyTaskSetPickPage extends ConsumerWidget {
  const DailyTaskSetPickPage({super.key, required this.skill});

  /// `listening` | `reading` | `writing`
  final String skill;

  static const Color _cyanGlow = HtmlDesignTokens.accent;
  static const Color _goldGlow = Color(0xFFFBBF24);

  String _normSkill() {
    switch (skill.trim().toLowerCase()) {
      case 'reading':
        return 'reading';
      case 'writing':
        return 'writing';
      case 'listening':
      default:
        return 'listening';
    }
  }

  ({String title, String emoji, Color accent, List<_SetPickOption> sets}) _config(
    AppStrings s,
  ) {
    final String sk = _normSkill();
    switch (sk) {
      case 'reading':
        return (
          title: s.setPickReadingTitle,
          emoji: '📖',
          accent: HtmlDesignTokens.primaryLight,
          sets: List<_SetPickOption>.generate(
            4,
            (int i) => _SetPickOption(
              setNumber: i + 1,
              label: 'Test ${i + 1}',
              subtitle: s.setPickReadingPassages,
            ),
          ),
        );
      case 'writing':
        return (
          title: s.setPickWritingTitle,
          emoji: '✍️',
          accent: _goldGlow,
          sets: List<_SetPickOption>.generate(
            4,
            (int i) => _SetPickOption(
              setNumber: i + 1,
              label: s.setPickSetLabel(i + 1),
              subtitle: s.setPickWritingSubtitle(i + 1),
            ),
          ),
        );
      case 'listening':
      default:
        return (
          title: s.setPickListeningTitle,
          emoji: '🎧',
          accent: _cyanGlow,
          sets: List<_SetPickOption>.generate(
            5,
            (int i) => _SetPickOption(
              setNumber: i + 1,
              label: s.setPickSetLabel(i + 1),
              subtitle: s.setPickListeningSubtitle(i + 1),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLocaleProvider);
    final AppStrings s = AppStrings.of(context);
    final ({String title, String emoji, Color accent, List<_SetPickOption> sets}) cfg = _config(s);
    final String routeSkill = _normSkill();

    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -40,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      cfg.accent.withValues(alpha: 0.18),
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
                          cfg.title,
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
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: cfg.sets.length,
                    itemBuilder: (BuildContext context, int index) {
                      final _SetPickOption opt = cfg.sets[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push(
                              '/practice/daily-tasks/$routeSkill?set=${opt.setNumber}',
                            ),
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
                                        color: cfg.accent.withValues(alpha: 0.15),
                                        border: Border.all(color: cfg.accent.withValues(alpha: 0.35)),
                                      ),
                                      child: Text(cfg.emoji, style: const TextStyle(fontSize: 28)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            opt.label,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: HtmlDesignTokens.textMain,
                                              fontFamily: 'system-ui',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            opt.subtitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: HtmlDesignTokens.textSub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: HtmlDesignTokens.textSub.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

class _SetPickOption {
  const _SetPickOption({
    required this.setNumber,
    required this.label,
    required this.subtitle,
  });

  final int setNumber;
  final String label;
  final String subtitle;
}
