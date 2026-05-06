import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/i18n/app_strings.dart';
import '../core/theme/html_design_tokens.dart';

/// Practice 页顶部大容器：新功能主推位（高于下方「听说读写」入口卡片）。
class HtmlPracticeFeaturedModule extends StatelessWidget {
  const HtmlPracticeFeaturedModule({super.key, this.onPrimaryPressed});

  final VoidCallback? onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusXl),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    HtmlDesignTokens.primary.withValues(alpha: 0.35),
                    HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusXl),
                border: Border.all(color: HtmlDesignTokens.glassBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: HtmlDesignTokens.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: HtmlDesignTokens.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            s.tr('NEW', 'NEW'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: HtmlDesignTokens.accent,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                        Text(
                          _todayLabel(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.tr('今日环球快讯模考', 'Global News Mock Test'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.tr('精选外刊头条，串联听力、阅读与写作任务，一站式完成当日演练。', 'Curated headlines connect listening, reading and writing in one daily drill.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: HtmlDesignTokens.primary,
                        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                        elevation: 0,
                        child: InkWell(
                          onTap: onPrimaryPressed,
                          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            child: Center(
                              child: Text(
                                s.tr('开启今日快讯模考', 'Start Today\'s News Mock'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _todayLabel() {
    final DateTime n = DateTime.now();
    return '${n.month.toString().padLeft(2, '0')}/${n.day.toString().padLeft(2, '0')}';
  }
}

/// 听说读写练习：单卡片入口，点击进入专项选择（如今日任务大厅）。
class HtmlPracticeListenReadWriteCard extends StatelessWidget {
  const HtmlPracticeListenReadWriteCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.glassCard,
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('📝', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      s.tr('听说读写练习', 'Listen-Speak-Read-Write'),
                      style: TextStyle(
                        color: HtmlDesignTokens.textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      s.tr('进入后选择听力、口语、阅读或写作专项', 'Choose listening, speaking, reading or writing'),
                      style: TextStyle(
                        color: HtmlDesignTokens.textSub,
                        fontSize: 12,
                        fontFamily: 'system-ui',
                      ),
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

/// `.list-item` row
class HtmlListRow extends StatelessWidget {
  const HtmlListRow({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.iconBackground,
    this.trailing,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color? iconBackground;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = iconBackground ?? HtmlDesignTokens.primary.withValues(alpha: 0.15);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: HtmlDesignTokens.textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          fontFamily: 'system-ui',
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: HtmlDesignTokens.textSub,
                            fontSize: 12,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Store module small tile (inline HTML `flex: 1` cards).
class HtmlStoreMiniTile extends StatelessWidget {
  const HtmlStoreMiniTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Column(
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HtmlDesignTokens.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    fontFamily: 'system-ui',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HtmlDesignTokens.textSub,
                    fontSize: 12,
                    fontFamily: 'system-ui',
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
