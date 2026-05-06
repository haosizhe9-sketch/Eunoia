import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/navigation/shell_branch_activation.dart';
import '../../core/auth/display_name_utils.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/services/app_data_service.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../widgets/html_match_blocks.dart';
import 'practice_daily_tasks_panel.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _needLogin(
    BuildContext context,
    WidgetRef ref,
    VoidCallback whenAuthed,
  ) {
    if (isLoggedIn(ref)) {
      whenAuthed();
    } else {
      pushLoginPage(context);
    }
  }

  /// 未登录时提示登录以同步 E 点；已登录展示每日任务面板。
  Widget _dailyTasksSection(BuildContext context, WidgetRef ref) {
    final AppStrings s = AppStrings.of(context);
    if (isLoggedIn(ref)) {
      return const PracticeDailyTasksPanel();
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => pushLoginPage(context),
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.glassCard,
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.practiceDailyTaskBadge,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HtmlDesignTokens.accent,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.practiceDailyTaskLoginHint,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: HtmlDesignTokens.textSub.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLocaleProvider);
    ref.listen<Map<int, int>>(shellBranchActivationProvider, (
      Map<int, int>? previous,
      Map<int, int> next,
    ) {
      final int prevVal = previous?[0] ?? 0;
      final int nextVal = next[0] ?? 0;
      if (nextVal > prevVal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    });
    final AppStrings s = AppStrings.of(context);
    final User? user = readAuthUser(ref);
    final String welcomeName = user == null
        ? s.practiceGuestName
        : syncDisplayNameOrRoastDuckUid(user);
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hi! $welcomeName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.tr('准备开练，', 'Ready to learn,'),
                    style: TextStyle(
                      fontSize: 14,
                      color: HtmlDesignTokens.textSub,
                      fontFamily: 'system-ui',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.tr('预备烤鸭', 'Future IELTS Topper'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: HtmlDesignTokens.textMain,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'E',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          HtmlPracticeFeaturedModule(
            onPrimaryPressed: () => _needLogin(
              context,
              ref,
              () => context.push('/practice/news-brief-mock'),
            ),
          ),
          const SizedBox(height: 16),
          _dailyTasksSection(context, ref),
          const SizedBox(height: 24),
          Text(
            s.tr('基础训练', 'Core Training'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.tr(
              '按听说读写自选题库，AI 自动批改',
              'Choose skills by module, AI grades automatically',
            ),
            style: TextStyle(
              fontSize: 12,
              color: HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 12),
          HtmlPracticeListenReadWriteCard(
            onTap: () => _needLogin(
              context,
              ref,
              () => context.push('/practice/daily-tasks'),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            s.tr('互动玩法', 'Interactive Modes'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 12),
          HtmlListRow(
            emoji: '🧗',
            title: s.tr('无尽爬词塔', 'Endless Word Tower'),
            subtitle: s.tr('限时翻译，挑战极限', 'Timed translation challenge'),
            onTap: () => _needLogin(
              context,
              ref,
              () => context.push('/practice/word-tower'),
            ),
          ),
          HtmlListRow(
            emoji: '💬',
            title: s.tr('匿名语聊匹配', 'Anonymous Voice Match'),
            subtitle: s.tr('1分钟英文破冰交流', '1-minute English icebreaker'),
            iconBackground: const Color(0x262DD4BF),
            onTap: () => _needLogin(
              context,
              ref,
              () => context.push('/practice/anonymous-voice-match'),
            ),
          ),
        ],
      ),
    );
  }
}
