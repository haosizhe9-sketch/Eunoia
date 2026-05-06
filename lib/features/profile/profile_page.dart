import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/demo_e_points.dart';
import '../../core/auth/display_name_utils.dart';
import '../../core/auth/test_credentials.dart';
import '../../core/gacha/cosmetic_preview_widgets.dart';
import '../../core/gacha/wealth_gacha.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/navigation/shell_branch_activation.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart'
    show DailyCheckInResult, ProfilePublicFields, AppDataService, User;
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/user_inventory_demo.dart';
import '../../widgets/html_match_blocks.dart';
import 'profile_edit_sheet.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final Locale locale = ref.watch(appLocaleProvider);
    ref.watch(devMockLoginProvider);
    ref.listen<Map<int, int>>(shellBranchActivationProvider, (
      Map<int, int>? previous,
      Map<int, int> next,
    ) {
      final int prevVal = previous?[3] ?? 0;
      final int nextVal = next[3] ?? 0;
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
    final int profileRev = ref.watch(profileRevisionProvider);
    final AsyncValue<User?> auth = ref.watch(authUserProvider);
    final User? user = ref.watch(appDataServiceProvider).currentUser ??
        auth.maybeWhen(data: (User? u) => u, orElse: () => null);
    final bool devMock = ref.watch(devMockLoginProvider);
    final bool isGuest = !isLoggedIn(ref);

    return ValueListenableBuilder<DemoProfileEquip>(
      valueListenable: demoProfileEquipNotifier,
      builder: (BuildContext context, DemoProfileEquip equip, _) {
        final GachaCatalogEntry? nameFlowEntry = equip.equippedNameFlowId != null
            ? catalogEntryById(equip.equippedNameFlowId!)
            : null;

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 10),
                  if (isGuest)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HtmlDesignTokens.glassCard,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: HtmlDesignTokens.glassBorder),
                        ),
                        child: Text(
                          s.profileGuestBanner,
                          style: TextStyle(
                            fontSize: 11,
                            color: HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    ),
                  if (equip.equippedFrameId != null)
                    AvatarFramePreview(
                      frameId: equip.equippedFrameId!,
                      size: 104,
                      avatarBuilder: (double d) => const Text('👾', style: TextStyle(fontSize: 28)),
                    )
                  else
                    const _PlainWhiteAvatarFrame(emoji: '👾'),
                  const SizedBox(height: 16),
                  if (isGuest)
                    SizedBox(
                      height: 30,
                      child: _ProfileDisplayName(
                        user: user,
                        devMockActive: devMock,
                        nameFlowEntry: nameFlowEntry,
                        profileRevision: profileRev,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Flexible(
                          child: SizedBox(
                            height: 30,
                            child: _ProfileDisplayName(
                              user: user,
                              devMockActive: devMock,
                              nameFlowEntry: nameFlowEntry,
                              profileRevision: profileRev,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: const EdgeInsets.only(left: 2, right: 4, bottom: 2),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          tooltip: s.tr('编辑资料', 'Edit Profile'),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: HtmlDesignTokens.textSub,
                            size: 22,
                          ),
                          onPressed: () => showProfileEditSheet(context, ref),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  _ProfileTagline(
                    user: user,
                    devMockActive: devMock,
                    isGuest: isGuest,
                    profileRevision: profileRev,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.glassCard,
                  borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
                  border: Border.all(color: HtmlDesignTokens.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _EPointsStatBlock(
                          isGuest: isGuest,
                          user: user,
                          devMock: devMock,
                        ),
                        _TowerFloorStatBlock(
                          isGuest: isGuest,
                          user: user,
                          devMock: devMock,
                          profileRevision: profileRev,
                        ),
                        _CheckInDaysStatBlock(
                          isGuest: isGuest,
                          user: user,
                          devMock: devMock,
                          profileRevision: profileRev,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DailyCheckInBanner(
                      isGuest: isGuest,
                      user: user,
                      devMock: devMock,
                      profileRevision: profileRev,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (!isGuest) const _ProMembershipCard(),
              const SizedBox(height: 10),
              HtmlListRow(
                emoji: '📝',
                title: s.myPostsTitle,
                subtitle: s.myPostsSubtitle,
                iconBackground: Colors.white.withValues(alpha: 0.1),
                trailing: const Icon(Icons.chevron_right, color: HtmlDesignTokens.textSub, size: 22),
                onTap: () => _openOrPromptLogin(
                  context,
                  isGuest: isGuest,
                  location: '/profile/my-posts',
                ),
              ),
              HtmlListRow(
                emoji: '🤝',
                title: s.contractRingTitle,
                subtitle: s.contractRingSubtitle,
                iconBackground: Colors.white.withValues(alpha: 0.1),
                trailing: const Icon(Icons.chevron_right, color: HtmlDesignTokens.textSub, size: 22),
                onTap: () => _openOrPromptLogin(
                  context,
                  isGuest: isGuest,
                  location: '/profile/contract-star-ring',
                ),
              ),
              HtmlListRow(
                emoji: '🏆',
                title: s.leaderboardTitle,
                subtitle: s.leaderboardSubtitle,
                iconBackground: Colors.white.withValues(alpha: 0.1),
                trailing: const Icon(Icons.chevron_right, color: HtmlDesignTokens.textSub, size: 22),
                onTap: () => context.push('/profile/leaderboard'),
              ),
              HtmlListRow(
                emoji: '📚',
                title: s.wrongNotesTitle,
                subtitle: isGuest
                    ? s.wrongNotesSubtitle
                    : (ref.read(appDataServiceProvider).canAccessWrongNotesArchive
                        ? s.wrongNotesSubtitle
                        : s.wrongNotesProOnlySubtitle),
                iconBackground: Colors.white.withValues(alpha: 0.1),
                trailing: const Icon(Icons.chevron_right, color: HtmlDesignTokens.textSub, size: 22),
                onTap: () {
                  if (isGuest) {
                    context.push('/profile/auth');
                    return;
                  }
                  if (!ref.read(appDataServiceProvider).canAccessWrongNotesArchive) {
                    showAppTopSnackBar(
                      context,
                      Text(s.wrongNotesProOnlySnack),
                    );
                    return;
                  }
                  context.push('/profile/wrong-notes');
                },
              ),
              HtmlListRow(
                emoji: '🌐',
                title: s.languageTitle,
                subtitle: s.languageSubtitle,
                iconBackground: Colors.white.withValues(alpha: 0.1),
                trailing: Icon(
                  Icons.swap_horiz_rounded,
                  color: HtmlDesignTokens.textSub,
                  size: locale.languageCode == 'zh' ? 22 : 24,
                ),
                onTap: () => ref.read(appLocaleProvider.notifier).toggleLocale(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                width: double.infinity,
                child: isGuest
                    ? _LoginRegisterButton(onPressed: () => context.push('/profile/auth'))
                    : _LogoutButton(
                        onLogout: () => _confirmLogoutProfile(context, ref),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 测试阶段一键订阅 Pro；权益说明见卡片文案。
class _ProMembershipCard extends ConsumerWidget {
  const _ProMembershipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLocaleProvider);
    ref.watch(profileRevisionProvider);
    final AppStrings s = AppStrings.of(context);
    final AppDataService svc = ref.watch(appDataServiceProvider);
    final bool pro = svc.currentUserIsPro;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFFFFD700).withValues(alpha: 0.22),
            HtmlDesignTokens.primary.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pro ? s.proCardTitlePro : s.proCardTitleUpgrade,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              if (!pro)
                TextButton(
                  onPressed: () async {
                    await ref.read(appDataServiceProvider).subscribeProTestPhase();
                    ref.read(profileRevisionProvider.notifier).state++;
                    if (context.mounted) {
                      showAppTopSnackBar(
                        context,
                        Text(s.proCardActivatedSnack),
                      );
                    }
                  },
                  child: Text(s.proCardButtonSubscribe),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pro ? s.proCardBodyPro : s.proCardBodyFree,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: HtmlDesignTokens.textSub.withValues(alpha: 0.96),
            ),
          ),
        ],
      ),
    );
  }
}

void _openOrPromptLogin(
  BuildContext context, {
  required bool isGuest,
  required String location,
}) {
  if (isGuest) {
    context.push('/profile/auth');
    return;
  }
  context.push(location);
}

class _LoginRegisterButton extends StatelessWidget {
  const _LoginRegisterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: HtmlDesignTokens.accent,
        side: const BorderSide(color: HtmlDesignTokens.accentDeep),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        ),
      ),
      child: Text(
        AppStrings.of(context).tr('登录/注册', 'Login/Register'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'system-ui',
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => onLogout(),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: const BorderSide(color: Color(0xFFEF4444)),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        ),
      ),
      child: Text(
        AppStrings.of(context).tr('退出登录', 'Log out'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'system-ui',
        ),
      ),
    );
  }
}

class _ProfileDisplayName extends ConsumerStatefulWidget {
  const _ProfileDisplayName({
    required this.user,
    required this.devMockActive,
    required this.nameFlowEntry,
    required this.profileRevision,
  });

  final User? user;
  final bool devMockActive;
  final GachaCatalogEntry? nameFlowEntry;
  final int profileRevision;

  @override
  ConsumerState<_ProfileDisplayName> createState() => _ProfileDisplayNameState();
}

class _ProfileDisplayNameState extends ConsumerState<_ProfileDisplayName> {
  Future<String>? _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = _load();
  }

  @override
  void didUpdateWidget(covariant _ProfileDisplayName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.devMockActive != widget.devMockActive ||
        oldWidget.profileRevision != widget.profileRevision) {
      _resolved = _load();
    }
  }

  Future<String> _load() async {
    if (widget.devMockActive) {
      final DevMockProfile? local = ref.read(devMockProfileProvider);
      if (local != null && local.displayName.trim().isNotEmpty) {
        return local.displayName.trim();
      }
      return TestCredentials.displayName;
    }
    final User? u = widget.user;
    if (u == null) {
      return AppStrings.of(context).tr('游客', 'Guest');
    }
    final String? fromDb = await ref.read(appDataServiceProvider).fetchProfileDisplayName(u.id);
    if (fromDb != null && fromDb.isNotEmpty) {
      return fromDb;
    }
    return syncDisplayNameOrRoastDuckUid(u);
  }

  @override
  Widget build(BuildContext context) {
    final GachaCatalogEntry? nameFlowEntry = widget.nameFlowEntry;

    return FutureBuilder<String>(
      future: _resolved,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String text = snapshot.data ??
            (widget.devMockActive
                ? TestCredentials.displayName
                : (widget.user == null ? AppStrings.of(context).tr('游客', 'Guest') : '…'));
        if (nameFlowEntry != null) {
          return NameFlowPreview(
            entry: nameFlowEntry,
            maxWidth: 260,
            fontSize: 24,
            animate: true,
            displayText: text,
            fixedHeight: 30,
          );
        }
        return Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'system-ui',
          ),
        );
      },
    );
  }
}

class _ProfileTagline extends ConsumerStatefulWidget {
  const _ProfileTagline({
    required this.user,
    required this.devMockActive,
    required this.isGuest,
    required this.profileRevision,
  });

  final User? user;
  final bool devMockActive;
  final bool isGuest;
  final int profileRevision;

  @override
  ConsumerState<_ProfileTagline> createState() => _ProfileTaglineState();
}

class _ProfileTaglineState extends ConsumerState<_ProfileTagline> {
  Future<String>? _resolved;

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) {
      _resolved = _load();
    }
  }

  @override
  void didUpdateWidget(covariant _ProfileTagline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGuest) {
      return;
    }
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.devMockActive != widget.devMockActive ||
        oldWidget.profileRevision != widget.profileRevision ||
        oldWidget.isGuest != widget.isGuest) {
      _resolved = _load();
    }
  }

  Future<String> _load() async {
    if (widget.devMockActive) {
      return ref.read(devMockProfileProvider)?.bio.trim() ?? '';
    }
    final User? u = widget.user;
    if (u == null) {
      return '';
    }
    final ProfilePublicFields? f = await ref.read(appDataServiceProvider).fetchProfilePublicFields(u.id);
    return f?.bio?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return Text(
        AppStrings.of(context).tr('登录后可同步学习进度与社区身份', 'Login to sync study progress and social profile'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: HtmlDesignTokens.textSub,
          fontFamily: 'system-ui',
        ),
      );
    }

    return FutureBuilder<String>(
      future: _resolved,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            '…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: HtmlDesignTokens.textSub.withValues(alpha: 0.7),
              fontFamily: 'system-ui',
            ),
          );
        }
        final String bio = snapshot.data ?? '';
        if (bio.isEmpty) {
          return Text(
            AppStrings.of(context).tr('写点什么介绍一下自己…', 'Write a short bio...'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: HtmlDesignTokens.textSub.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              fontFamily: 'system-ui',
            ),
          );
        }
        return Text(
          bio,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: HtmlDesignTokens.textSub,
            fontStyle: FontStyle.italic,
            fontFamily: 'system-ui',
          ),
        );
      },
    );
  }
}

Future<void> _confirmLogoutProfile(BuildContext context, WidgetRef ref) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: HtmlDesignTokens.gachaSubBg,
        title: Text(
          AppStrings.of(context).tr('退出登录', 'Log out'),
          style: TextStyle(color: HtmlDesignTokens.textMain, fontFamily: 'system-ui'),
        ),
        content: Text(
          AppStrings.of(context).tr('确定要退出当前账号吗？', 'Are you sure to log out of this account?'),
          style: TextStyle(color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.of(context).tr('取消', 'Cancel'), style: const TextStyle(fontFamily: 'system-ui')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.of(context).tr('退出', 'Log out'), style: const TextStyle(fontFamily: 'system-ui')),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) {
    return;
  }
  ref.read(devMockLoginProvider.notifier).state = false;
  try {
    await ref.read(appDataServiceProvider).signOut();
  } catch (_) {
    // 本地 JSON 会话退出失败时忽略。
  }
  if (!context.mounted) {
    return;
  }
  showAppTopSnackBar(context, Text(AppStrings.of(context).tr('已退出登录', 'Logged out')));
}

class _PlainWhiteAvatarFrame extends StatelessWidget {
  const _PlainWhiteAvatarFrame({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Center(
        child: Container(
          width: 66,
          height: 66,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: HtmlDesignTokens.bgDeep,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}

/// 第三列：仅展示累计签到天数（与 E点 / 词塔 对齐）。
class _CheckInDaysStatBlock extends ConsumerStatefulWidget {
  const _CheckInDaysStatBlock({
    required this.isGuest,
    required this.user,
    required this.devMock,
    required this.profileRevision,
  });

  final bool isGuest;
  final User? user;
  final bool devMock;
  final int profileRevision;

  @override
  ConsumerState<_CheckInDaysStatBlock> createState() => _CheckInDaysStatBlockState();
}

class _CheckInDaysStatBlockState extends ConsumerState<_CheckInDaysStatBlock> {
  Future<String>? _value;

  @override
  void initState() {
    super.initState();
    _value = _load();
  }

  @override
  void didUpdateWidget(covariant _CheckInDaysStatBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.devMock != widget.devMock ||
        oldWidget.isGuest != widget.isGuest ||
        oldWidget.profileRevision != widget.profileRevision) {
      _value = _load();
    }
  }

  Future<String> _load() async {
    if (widget.isGuest || widget.devMock) {
      return '—';
    }
    final User? u = widget.user;
    if (u == null) {
      return '0';
    }
    final ProfilePublicFields? f = await ref.read(appDataServiceProvider).fetchProfilePublicFields(u.id);
    return '${f?.checkInTotal ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return FutureBuilder<String>(
      future: _value,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String text = snapshot.data ?? (widget.isGuest ? '—' : '…');
        return _StatBlock(
          value: text,
          label: s.statLabelCheckInDays,
          valueColor: HtmlDesignTokens.accent,
        );
      },
    );
  }
}

/// 全宽每日签到入口：可签到时为高对比渐变按钮；已签为弱化状态条。
class _DailyCheckInBanner extends ConsumerStatefulWidget {
  const _DailyCheckInBanner({
    required this.isGuest,
    required this.user,
    required this.devMock,
    required this.profileRevision,
  });

  final bool isGuest;
  final User? user;
  final bool devMock;
  final int profileRevision;

  @override
  ConsumerState<_DailyCheckInBanner> createState() => _DailyCheckInBannerState();
}

class _DailyCheckInBannerState extends ConsumerState<_DailyCheckInBanner> {
  Future<_CheckInUiModel>? _model;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _model = _load();
  }

  @override
  void didUpdateWidget(covariant _DailyCheckInBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.devMock != widget.devMock ||
        oldWidget.isGuest != widget.isGuest ||
        oldWidget.profileRevision != widget.profileRevision) {
      _model = _load();
    }
  }

  Future<_CheckInUiModel> _load() async {
    if (widget.isGuest) {
      return const _CheckInUiModel(display: '—', canCheckInToday: false, checkedToday: false);
    }
    if (widget.devMock) {
      return const _CheckInUiModel(display: '—', canCheckInToday: false, checkedToday: false);
    }
    final User? u = widget.user;
    if (u == null) {
      return const _CheckInUiModel(display: '0', canCheckInToday: false, checkedToday: false);
    }
    final ProfilePublicFields? f = await ref.read(appDataServiceProvider).fetchProfilePublicFields(u.id);
    final String today = AppDataService.localCalendarDayIso(DateTime.now());
    final String? last = f?.lastCheckInDate;
    final bool checkedToday = last == today;
    final bool canCheck = !checkedToday;
    final int n = f?.checkInTotal ?? 0;
    return _CheckInUiModel(
      display: '$n',
      canCheckInToday: canCheck,
      checkedToday: checkedToday,
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final AppStrings s = AppStrings.of(context);
    if (widget.isGuest) {
      pushLoginPage(context);
      return;
    }
    if (widget.devMock) {
      showAppTopSnackBar(context, Text(s.checkInDevMockSnack));
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final DailyCheckInResult? r = await ref.read(appDataServiceProvider).performDailyCheckIn();
    if (!context.mounted) {
      return;
    }
    setState(() => _busy = false);
    if (r == null || !r.success) {
      showAppTopSnackBar(
        context,
        Text(s.checkInFailed),
      );
      return;
    }
    if (r.alreadyToday) {
      showAppTopSnackBar(
        context,
        Text(s.checkInAlreadyMessage(r.totalDays, r.ePointsBalance)),
      );
    } else {
      showAppTopSnackBar(
        context,
        Text(
          s.checkInSuccessMessage(
            r.ePointsGranted,
            r.checkInStreak,
            r.totalDays,
            r.ePointsBalance,
          ),
        ),
      );
    }
    ref.read(profileRevisionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    if (widget.isGuest) {
      return OutlinedButton.icon(
        onPressed: () => pushLoginPage(context),
        icon: const Icon(Icons.login_rounded, size: 20),
        label: Text(s.loginToCheckInDaily),
        style: OutlinedButton.styleFrom(
          foregroundColor: HtmlDesignTokens.accent,
          side: BorderSide(color: HtmlDesignTokens.accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    if (widget.devMock) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HtmlDesignTokens.glassBorder),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 20, color: HtmlDesignTokens.textSub),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.devModeCheckInNote,
                style: TextStyle(
                  fontSize: 13,
                  color: HtmlDesignTokens.textSub,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<_CheckInUiModel>(
      future: _model,
      builder: (BuildContext context, AsyncSnapshot<_CheckInUiModel> snap) {
        final _CheckInUiModel m = snap.data ??
            const _CheckInUiModel(display: '…', canCheckInToday: false, checkedToday: false);
        final bool canTap = !_busy;

        if (m.canCheckInToday) {
          return Material(
            color: Colors.transparent,
            elevation: 0,
            child: InkWell(
              onTap: canTap ? () => _onTap(context) : null,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Color(0xFF14B8A6),
                      HtmlDesignTokens.accent,
                      Color(0xFF5EEAD4),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: HtmlDesignTokens.accent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _busy
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              s.checkInBannerTitleActive,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                                fontFamily: 'system-ui',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.checkInBannerSubtitleActive,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xE6FFFFFF),
                                height: 1.25,
                                fontFamily: 'system-ui',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? () => _onTap(context) : null,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
                border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.35)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_rounded,
                      color: HtmlDesignTokens.accent,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.checkInBannerTitleDone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.checkInBannerSubtitleDone(m.display),
                            style: TextStyle(
                              fontSize: 12,
                              color: HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_busy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: HtmlDesignTokens.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckInUiModel {
  const _CheckInUiModel({
    required this.display,
    required this.canCheckInToday,
    required this.checkedToday,
  });

  final String display;
  final bool canCheckInToday;
  final bool checkedToday;
}

/// E 点余额：与商城同款 [demoEPointsNotifier]，由 [AppDataService] 在 JSON 余额变化时同步。
class _EPointsStatBlock extends ConsumerWidget {
  const _EPointsStatBlock({
    required this.isGuest,
    required this.user,
    required this.devMock,
  });

  final bool isGuest;
  final User? user;
  final bool devMock;

  static const Color _gold = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings s = AppStrings.of(context);
    if (isGuest || devMock) {
      return _StatBlock(
        value: '—',
        label: s.statLabelEPoints,
        valueColor: _gold,
      );
    }
    if (user == null) {
      return _StatBlock(
        value: '0',
        label: s.statLabelEPoints,
        valueColor: _gold,
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: demoEPointsNotifier,
      builder: (BuildContext context, int pts, _) {
        return _StatBlock(
          value: '$pts',
          label: s.statLabelEPoints,
          valueColor: _gold,
        );
      },
    );
  }
}

/// 词塔历史最高层（`profiles.word_tower_max_floor`）。
class _TowerFloorStatBlock extends ConsumerStatefulWidget {
  const _TowerFloorStatBlock({
    required this.isGuest,
    required this.user,
    required this.devMock,
    required this.profileRevision,
  });

  final bool isGuest;
  final User? user;
  final bool devMock;
  final int profileRevision;

  @override
  ConsumerState<_TowerFloorStatBlock> createState() => _TowerFloorStatBlockState();
}

class _TowerFloorStatBlockState extends ConsumerState<_TowerFloorStatBlock> {
  Future<String>? _value;

  @override
  void initState() {
    super.initState();
    _value = _load();
  }

  @override
  void didUpdateWidget(covariant _TowerFloorStatBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.id != widget.user?.id ||
        oldWidget.devMock != widget.devMock ||
        oldWidget.isGuest != widget.isGuest ||
        oldWidget.profileRevision != widget.profileRevision) {
      _value = _load();
    }
  }

  Future<String> _load() async {
    if (widget.isGuest) {
      return '—';
    }
    if (widget.devMock) {
      return '—';
    }
    final User? u = widget.user;
    if (u == null) {
      return '0';
    }
    final ProfilePublicFields? f = await ref.read(appDataServiceProvider).fetchProfilePublicFields(u.id);
    final int n = f?.wordTowerMaxFloor ?? 0;
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return FutureBuilder<String>(
      future: _value,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String text = snapshot.data ?? (widget.isGuest ? '—' : '…');
        return _StatBlock(
          value: text,
          label: s.statLabelWordTower,
          valueColor: HtmlDesignTokens.accent,
        );
      },
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor ?? HtmlDesignTokens.textMain,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}
