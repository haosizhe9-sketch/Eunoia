import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session.dart';
import '../../core/auth/display_name_utils.dart';
import '../../core/auth/test_credentials.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/theme/html_design_tokens.dart';
import 'leaderboard_entry.dart';
import 'rank_player_profile_page.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  bool _tower = true;

  static const List<LeaderboardEntry> _towerEntries = <LeaderboardEntry>[
    LeaderboardEntry(
      rank: 1,
      name: '烤鸭_8921',
      uid: '100456',
      emoji: '🦊',
      score: 128,
      isTowerBoard: true,
      avatarGradient: <Color>[Color(0xFFF43F5E), Color(0xFFE11D48)],
    ),
    LeaderboardEntry(
      rank: 2,
      name: 'Simon Fan',
      uid: '201001',
      emoji: '🐼',
      score: 105,
      isTowerBoard: true,
      avatarGradient: <Color>[Color(0xFF10B981), Color(0xFF059669)],
    ),
    LeaderboardEntry(
      rank: 3,
      name: 'IELTS Master',
      uid: '330221',
      emoji: '🐳',
      score: 92,
      isTowerBoard: true,
      avatarGradient: <Color>[Color(0xFF3B82F6), Color(0xFF2563EB)],
    ),
    LeaderboardEntry(rank: 4, name: '雅思冲刺者', uid: '902183', emoji: '🐱', score: 88, isTowerBoard: true),
    LeaderboardEntry(rank: 5, name: 'Tiger_W', uid: '812903', emoji: '🐯', score: 85, isTowerBoard: true),
    LeaderboardEntry(rank: 6, name: 'Bunny Learns', uid: '712034', emoji: '🐰', score: 76, isTowerBoard: true),
    LeaderboardEntry(rank: 7, name: 'Doggo', uid: '692812', emoji: '🐶', score: 70, isTowerBoard: true),
    LeaderboardEntry(
      rank: 8,
      name: 'WolfStudy',
      uid: '581234',
      emoji: '🐺',
      score: 65,
      isTowerBoard: true,
      avatarGradient: <Color>[Color(0xFF64748B), Color(0xFF475569)],
    ),
    LeaderboardEntry(
      rank: 9,
      name: 'SkyReader',
      uid: '571100',
      emoji: '🦅',
      score: 62,
      isTowerBoard: true,
      avatarGradient: <Color>[Color(0xFF0EA5E9), Color(0xFF0369A1)],
    ),
    LeaderboardEntry(
      rank: 10,
      name: 'LeapFrog',
      uid: '560009',
      emoji: '🐸',
      score: 58,
      isTowerBoard: true,
      avatarGradient: <Color>[Color(0xFF22C55E), Color(0xFF15803D)],
    ),
  ];

  static const List<LeaderboardEntry> _wealthEntries = <LeaderboardEntry>[
    LeaderboardEntry(
      rank: 1,
      name: 'Rich_Leo',
      uid: '880001',
      emoji: '🦁',
      score: 28000,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    LeaderboardEntry(
      rank: 2,
      name: '氪金大佬',
      uid: '770002',
      emoji: '🦄',
      score: 12500,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    ),
    LeaderboardEntry(
      rank: 3,
      name: 'Slow_Win',
      uid: '660003',
      emoji: '🐢',
      score: 9800,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFF14B8A6), Color(0xFF0D9488)],
    ),
    LeaderboardEntry(rank: 4, name: '烤鸭_8921', uid: '100456', emoji: '🦊', score: 8200, isTowerBoard: false),
    LeaderboardEntry(rank: 5, name: 'Hamster_Coin', uid: '201934', emoji: '🐹', score: 7500, isTowerBoard: false),
    LeaderboardEntry(
      rank: 6,
      name: 'DiamondHand',
      uid: '501111',
      emoji: '💎',
      score: 6980,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFF38BDF8), Color(0xFF0284C7)],
    ),
    LeaderboardEntry(
      rank: 7,
      name: 'CryptoBear',
      uid: '501222',
      emoji: '🐻',
      score: 6550,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFFA16207), Color(0xFF713F12)],
    ),
    LeaderboardEntry(
      rank: 8,
      name: 'SilverFox',
      uid: '501333',
      emoji: '🦊',
      score: 6200,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFF94A3B8), Color(0xFF64748B)],
    ),
    LeaderboardEntry(
      rank: 9,
      name: 'MiniWhale',
      uid: '501444',
      emoji: '🐋',
      score: 5900,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFF6366F1), Color(0xFF4338CA)],
    ),
    LeaderboardEntry(
      rank: 10,
      name: 'StackSaver',
      uid: '501555',
      emoji: '📚',
      score: 5400,
      isTowerBoard: false,
      avatarGradient: <Color>[Color(0xFFEC4899), Color(0xFFBE185D)],
    ),
  ];

  static const LeaderboardEntry _guestTowerSelf = LeaderboardEntry(
    rank: 0,
    name: '游客',
    uid: LeaderboardEntry.kGuestLeaderboardUid,
    emoji: '👤',
    score: 0,
    isTowerBoard: true,
  );

  static const LeaderboardEntry _guestWealthSelf = LeaderboardEntry(
    rank: 0,
    name: '游客',
    uid: LeaderboardEntry.kGuestLeaderboardUid,
    emoji: '👤',
    score: 0,
    isTowerBoard: false,
  );

  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Color get _glowColor =>
      _tower ? HtmlDesignTokens.accent.withValues(alpha: 0.15) : LeaderboardTokens.goldGlow.withValues(alpha: 0.15);

  Color get _scoreColor => _tower ? HtmlDesignTokens.accent : LeaderboardTokens.goldGlow;

  List<LeaderboardEntry> get _entries => _tower ? _towerEntries : _wealthEntries;

  LeaderboardEntry get _self {
    if (!isLoggedIn(ref)) {
      return _tower ? _guestTowerSelf : _guestWealthSelf;
    }
    if (ref.watch(devMockLoginProvider)) {
      return LeaderboardEntry(
        rank: 0,
        name: TestCredentials.displayName,
        uid: TestCredentials.account,
        emoji: '👾',
        score: 0,
        isTowerBoard: _tower,
        avatarGradient: const <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent],
      );
    }
    final User? u = readAuthUser(ref);
    if (u == null) {
      return _tower ? _guestTowerSelf : _guestWealthSelf;
    }
    return LeaderboardEntry(
      rank: 0,
      name: syncDisplayNameOrRoastDuckUid(u),
      uid: shortUidForDisplay(u.id),
      emoji: '👾',
      score: 0,
      isTowerBoard: _tower,
      avatarGradient: const <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent],
    );
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _entries.take(3).toList();
    final podium = top3.length >= 3 ? <LeaderboardEntry>[top3[1], top3[0], top3[2]] : top3;
    final rest = _entries.skip(3).toList();

    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[_glowColor, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient),
            child: Column(
              children: <Widget>[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: HtmlDesignTokens.subpageAppBarPadding,
                    child: Row(
                      children: <Widget>[
                        _CircleIconButton(
                          icon: Icons.chevron_left,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Text(
                            AppStrings.of(context).tr('全球排行榜', 'Global Leaderboard'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _TabSwitch(
                    towerSelected: _tower,
                    onTower: () => setState(() => _tower = true),
                    onWealth: () => setState(() => _tower = false),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey<bool>(_tower),
                      child: Column(
                        children: <Widget>[
                          _PodiumSection(
                            podium: podium,
                            scoreColor: _scoreColor,
                            floatAnimation: _floatController,
                            onEntryTap: _onEntryTap,
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                              physics: const BouncingScrollPhysics(),
                              itemCount: rest.length,
                              separatorBuilder: (BuildContext context, int index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (BuildContext context, int i) {
                                final e = rest[i];
                                return _ListRow(
                                  entry: e,
                                  scoreColor: _scoreColor,
                                  onTap: () => _onEntryTap(e),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Material(
                  color: HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.92),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        child: _ListRow(
                          entry: _self,
                          scoreColor: _scoreColor,
                          emphasizeScore: true,
                          highlightAvatar: true,
                          onTap: () => _onSelfTap(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onEntryTap(LeaderboardEntry e) {
    _pushEpicProfile(e, isSelf: false);
  }

  void _onSelfTap() {
    if (!isLoggedIn(ref)) {
      pushLoginPage(context);
      return;
    }
    _pushEpicProfile(_self, isSelf: true);
  }

  void _pushEpicProfile(LeaderboardEntry e, {required bool isSelf}) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) {
          return RankPlayerProfilePage(
            entry: e,
            isSelf: isSelf,
            boardIsTower: _tower,
          );
        },
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.92, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _TabSwitch extends StatelessWidget {
  const _TabSwitch({
    required this.towerSelected,
    required this.onTower,
    required this.onWealth,
  });

  final bool towerSelected;
  final VoidCallback onTower;
  final VoidCallback onWealth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final w = (c.maxWidth - 8) / 2;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: towerSelected ? 0 : w,
                top: 0,
                width: w,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.glassCard,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: HtmlDesignTokens.glassBorder),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TabLabel(
                      text: AppStrings.of(context).tr('无尽词塔', 'Endless Tower'),
                      selected: towerSelected,
                      onTap: onTower,
                    ),
                  ),
                  Expanded(
                    child: _TabLabel(
                      text: AppStrings.of(context).tr('财富榜', 'Wealth'),
                      selected: !towerSelected,
                      onTap: onWealth,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub,
                fontFamily: 'system-ui',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HtmlDesignTokens.glassCard,
      shape: CircleBorder(side: BorderSide(color: HtmlDesignTokens.glassBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: HtmlDesignTokens.textMain, size: 22),
        ),
      ),
    );
  }
}

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({
    required this.podium,
    required this.scoreColor,
    required this.floatAnimation,
    required this.onEntryTap,
  });

  final List<LeaderboardEntry> podium;
  final Color scoreColor;
  final Animation<double> floatAnimation;
  final ValueChanged<LeaderboardEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    if (podium.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (podium.isNotEmpty)
            Expanded(
              child: _PodiumSlot(
                entry: podium[0],
                place: 2,
                scoreColor: scoreColor,
                floatAnimation: floatAnimation,
                delay: 0.15,
                marginBottom: 20,
                onTap: () => onEntryTap(podium[0]),
              ),
            ),
          if (podium.length > 1)
            Expanded(
              child: _PodiumSlot(
                entry: podium[1],
                place: 1,
                scoreColor: scoreColor,
                floatAnimation: floatAnimation,
                delay: 0,
                marginBottom: 45,
                onTap: () => onEntryTap(podium[1]),
              ),
            ),
          if (podium.length > 2)
            Expanded(
              child: _PodiumSlot(
                entry: podium[2],
                place: 3,
                scoreColor: scoreColor,
                floatAnimation: floatAnimation,
                delay: 0.3,
                marginBottom: 10,
                onTap: () => onEntryTap(podium[2]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.place,
    required this.scoreColor,
    required this.floatAnimation,
    required this.delay,
    required this.marginBottom,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final int place;
  final Color scoreColor;
  final Animation<double> floatAnimation;
  final double delay;
  final double marginBottom;
  final VoidCallback onTap;

  double get _size {
    switch (place) {
      case 1:
        return 76;
      case 2:
        return 60;
      default:
        return 54;
    }
  }

  BorderSide get _border {
    switch (place) {
      case 1:
        return const BorderSide(color: LeaderboardTokens.goldGlow, width: 3);
      case 2:
        return const BorderSide(color: LeaderboardTokens.silver, width: 2);
      default:
        return const BorderSide(color: LeaderboardTokens.bronze, width: 2);
    }
  }

  List<Color> get _shadow {
    switch (place) {
      case 1:
        return <Color>[LeaderboardTokens.goldGlow.withValues(alpha: 0.45), Colors.transparent];
      case 2:
        return <Color>[LeaderboardTokens.silver.withValues(alpha: 0.35), Colors.transparent];
      default:
        return <Color>[LeaderboardTokens.bronze.withValues(alpha: 0.35), Colors.transparent];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatAnimation,
      builder: (BuildContext context, Widget? child) {
        final t = (floatAnimation.value + delay) % 1.0;
        final dy = -4 * (0.5 - (t - 0.5).abs()) * 2;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: marginBottom),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: place == 1 ? 38 : 8,
                  child: place == 1
                      ? const Text('👑', style: TextStyle(fontSize: 28))
                      : null,
                ),
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    Container(
                      width: _size,
                      height: _size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: entry.avatarGradient != null
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: entry.avatarGradient!,
                              )
                            : null,
                        color: entry.avatarGradient == null ? Colors.white.withValues(alpha: 0.06) : null,
                        border: Border.fromBorderSide(_border),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _shadow[0],
                            blurRadius: place == 1 ? 20 : 14,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(entry.emoji, style: TextStyle(fontSize: place == 1 ? 34 : 26)),
                    ),
                    Positioned(
                      bottom: place == 1 ? -10 : -8,
                      child: Container(
                        width: place == 1 ? 28 : 24,
                        height: place == 1 ? 28 : 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: place == 1 ? LeaderboardTokens.goldGlow : HtmlDesignTokens.glassCard,
                          border: place == 1 ? null : Border.all(color: HtmlDesignTokens.glassBorder),
                        ),
                        child: Text(
                          '$place',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: place == 1 ? Colors.black : HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 88,
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HtmlDesignTokens.textMain,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(entry.isTowerBoard ? '🧗 ' : '💎 ', style: const TextStyle(fontSize: 13)),
                    Text(
                      entry.isTowerBoard
                          ? AppStrings.of(context).tr('${entry.score} 层', 'Lv ${entry.score}')
                          : formatLeaderboardWealth(entry.score),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.entry,
    required this.scoreColor,
    this.emphasizeScore = false,
    this.highlightAvatar = false,
    this.onTap,
  });

  final LeaderboardEntry entry;
  final Color scoreColor;
  final bool emphasizeScore;
  final bool highlightAvatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.glassCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(
                  entry.isGuestSelfRow ? '—' : (entry.rank == 0 ? '—' : '${entry.rank}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: highlightAvatar ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: entry.avatarGradient != null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: entry.avatarGradient!,
                        )
                      : null,
                  color: entry.avatarGradient == null ? Colors.white.withValues(alpha: 0.05) : null,
                  border: highlightAvatar
                      ? Border.all(color: HtmlDesignTokens.primary, width: 2)
                      : null,
                  boxShadow: highlightAvatar
                      ? <BoxShadow>[
                          BoxShadow(
                            color: HtmlDesignTokens.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Text(entry.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isGuestSelfRow
                          ? AppStrings.of(context).tr('登录后参与全球排名', 'Login to join global ranking')
                          : 'UID: ${entry.uid}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                entry.isGuestSelfRow
                    ? '—'
                    : (entry.isTowerBoard
                        ? AppStrings.of(context).tr('${entry.score} 层', 'Lv ${entry.score}')
                        : formatLeaderboardWealth(entry.score)),
                style: TextStyle(
                  fontSize: emphasizeScore ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
