import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/navigation/shell_branch_activation.dart';
import '../../core/demo_e_points.dart';
import '../../core/gacha/wealth_gacha.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import '../../widgets/html_match_blocks.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  bool _syncingWallet = false;
  late final ScrollController _scrollController;

  static String _formatPoints(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncWalletFromProfile(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _syncWalletFromProfile() async {
    if (!isLoggedIn(ref) || _syncingWallet) return;
    _syncingWallet = true;
    try {
      final service = ref.read(appDataServiceProvider);
      final int? ePoints = await service.fetchEPoints();
      final int? tickets = await service.fetchBlindBoxTickets();
      if (ePoints != null) demoEPointsNotifier.value = ePoints;
      if (tickets != null) demoGachaTicketsNotifier.value = tickets;
    } finally {
      _syncingWallet = false;
    }
  }

  void _showExchangeBlindBoxTicketDialog(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final int pts = demoEPointsNotifier.value;
    final int rate = GachaEngine.ePointsPerBlindBoxTicket;
    final int maxTickets = pts ~/ rate;
    if (maxTickets < 1) {
      showAppTopSnackBar(
        context,
        Text(
          s.tr(
            'E点不足，兑换 1 张需 $rate E点',
            'Not enough E-Points. 1 ticket needs $rate E-Points',
          ),
        ),
      );
      return;
    }
    int qty = 1;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setModalState) {
          final int cost = qty * rate;
          return AlertDialog(
            backgroundColor: const Color(0xFF1A162B),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
              side: BorderSide(color: HtmlDesignTokens.glassBorder),
            ),
            title: Text(
              s.tr('兑换抽卡盲盒券', 'Exchange Blind-Box Tickets'),
              style: TextStyle(
                color: HtmlDesignTokens.textMain,
                fontFamily: 'system-ui',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  s.tr(
                    '手办池 / E宠池单抽消耗 1 张，十连消耗 10 张。可调数量批量兑换。',
                    'Figure/E-Pet pools: 1 ticket per draw, 10 for a ten-draw. Adjust quantity to exchange in batch.',
                  ),
                  style: TextStyle(
                    color: HtmlDesignTokens.textSub,
                    height: 1.45,
                    fontFamily: 'system-ui',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    Text(
                      s.tr('快捷批量：', 'Quick batch:'),
                      style: TextStyle(
                        fontSize: 12,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    for (final int preset in <int>[1, 5, 10])
                      if (preset <= maxTickets)
                        ActionChip(
                          label: Text('×$preset'),
                          onPressed: () => setModalState(() => qty = preset),
                        ),
                    ActionChip(
                      label: Text(s.tr('全部', 'All')),
                      onPressed: () => setModalState(() => qty = maxTickets),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      onPressed: qty > 1
                          ? () => setModalState(() {
                                qty -= 1;
                              })
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, color: HtmlDesignTokens.textMain),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: HtmlDesignTokens.textMain,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: qty < maxTickets
                          ? () => setModalState(() {
                                qty += 1;
                              })
                          : null,
                      icon: const Icon(Icons.add_circle_outline, color: HtmlDesignTokens.textMain),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => setModalState(() {
                      qty = maxTickets;
                    }),
                    child: Text(
                      s.tr('一次兑满（$maxTickets 张）', 'Max ($maxTickets)'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    '共消耗 ${_formatPoints(cost)} E点（$rate E点/张，当前余额 ${_formatPoints(pts)} E点）',
                    'Total ${_formatPoints(cost)} E-Points ($rate each, balance ${_formatPoints(pts)})',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: HtmlDesignTokens.accent,
                    fontFamily: 'system-ui',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.tr('取消', 'Cancel')),
              ),
              TextButton(
                onPressed: () async {
                  final int p = demoEPointsNotifier.value;
                  final int need = qty * rate;
                  if (qty < 1 || p < need) {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    return;
                  }
                  try {
                    final AppDataService service = ref.read(appDataServiceProvider);
                    final int next = await service.spendEPoints(need);
                    final int ticketNext = await service.addBlindBoxTickets(qty);
                    demoEPointsNotifier.value = next;
                    demoGachaTicketsNotifier.value = ticketNext;
                  } catch (_) {
                    if (ctx.mounted) {
                      showAppTopSnackBar(
                        ctx,
                        Text(
                          s.tr('E点不足，兑换失败', 'Not enough E-Points, exchange failed'),
                        ),
                      );
                    }
                    return;
                  }
                  if (!ctx.mounted) {
                    return;
                  }
                  Navigator.pop(ctx);
                  if (!mounted) {
                    return;
                  }
                  ref.read(profileRevisionProvider.notifier).state++;
                  showAppTopSnackBar(
                    context,
                    Text(
                      s.tr('已兑换 $qty 张抽卡盲盒券', 'Exchanged $qty blind-box tickets'),
                    ),
                  );
                },
                child: Text(s.tr('确认', 'Confirm')),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileRevisionProvider, (int? previous, int next) {
      _syncWalletFromProfile();
    });
    ref.listen<AsyncValue<User?>>(authUserProvider, (
      AsyncValue<User?>? previous,
      AsyncValue<User?> next,
    ) {
      _syncWalletFromProfile();
    });
    ref.listen<Map<int, int>>(shellBranchActivationProvider, (
      Map<int, int>? previous,
      Map<int, int> next,
    ) {
      final int prevVal = previous?[2] ?? 0;
      final int nextVal = next[2] ?? 0;
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
    final bool guest = !isLoggedIn(ref);

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.navStore,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: HtmlDesignTokens.textMain,
                letterSpacing: 0.5,
                fontFamily: 'system-ui',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      HtmlDesignTokens.radiusXl,
                    ),
                    border: Border.all(color: HtmlDesignTokens.glassBorder),
                    gradient: RadialGradient(
                      center: const Alignment(1, -1),
                      radius: 1.2,
                      colors: <Color>[
                        const Color(0x332DD4BF),
                        HtmlDesignTokens.glassCard,
                      ],
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        s.tr('当前 E 点', 'Current E-Points'),
                        style: TextStyle(
                          fontSize: 14,
                          color: HtmlDesignTokens.textSub,
                          letterSpacing: 2,
                          fontFamily: 'system-ui',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (guest)
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: '— ',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: HtmlDesignTokens.textSub,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                              TextSpan(
                                text: s.tr('E点', 'E-Points'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: HtmlDesignTokens.textMain,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ValueListenableBuilder<int>(
                          valueListenable: demoEPointsNotifier,
                          builder: (BuildContext context, int pts, _) {
                            return Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: '${_formatPoints(pts)} ',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w700,
                                      color: HtmlDesignTokens.accent,
                                      fontFamily: 'system-ui',
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: HtmlDesignTokens.accent
                                              .withValues(alpha: 0.4),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextSpan(
                                    text: s.tr('E点', 'E-Points'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: HtmlDesignTokens.textMain,
                                      fontFamily: 'system-ui',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),
                      Container(height: 1, color: HtmlDesignTokens.glassBorder),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[
                          demoEPointsNotifier,
                          demoGachaTicketsNotifier,
                        ]),
                        builder: (BuildContext context, _) {
                          if (guest) {
                            return Row(
                              children: <Widget>[
                                const Text(
                                  '🎟️',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.tr('抽卡盲盒券: —', 'Blind-box Tickets: —'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: HtmlDesignTokens.textSub,
                                      fontFamily: 'system-ui',
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => pushLoginPage(context),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.03,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: HtmlDesignTokens.glassBorder
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        s.tr('兑换', 'Exchange'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: HtmlDesignTokens.textSub,
                                          fontFamily: 'system-ui',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          final pts = demoEPointsNotifier.value;
                          final tickets = demoGachaTicketsNotifier.value;
                          final canExchange =
                              pts >= GachaEngine.ePointsPerBlindBoxTicket;
                          return Row(
                            children: <Widget>[
                              const Text('🎟️', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.tr(
                                    '抽卡盲盒券: $tickets',
                                    'Blind-box Tickets: $tickets',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: HtmlDesignTokens.textMain,
                                    fontFamily: 'system-ui',
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: canExchange
                                      ? () => _showExchangeBlindBoxTicketDialog(
                                          context,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: canExchange ? 0.06 : 0.03,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: HtmlDesignTokens.glassBorder
                                            .withValues(
                                              alpha: canExchange ? 1 : 0.5,
                                            ),
                                      ),
                                    ),
                                    child: Text(
                                      s.tr('兑换', 'Exchange'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: canExchange
                                            ? HtmlDesignTokens.textMain
                                            : HtmlDesignTokens.textSub,
                                        fontFamily: 'system-ui',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.tr(
                      '盲盒抽卡消耗抽卡盲盒券（上方可批量兑换，${GachaEngine.ePointsPerBlindBoxTicket} E点/张）；直购商城仍使用 E点。',
                      'Blind-box draws use tickets (batch exchange above, ${GachaEngine.ePointsPerBlindBoxTicket} E-Points each); direct store still uses E-Points.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: HtmlDesignTokens.textSub,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.tr('商城入口', 'Store Entrances'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              HtmlStoreMiniTile(
                emoji: '📦',
                title: s.tr('盲盒抽卡', 'Blind-box Draw'),
                subtitle: s.tr('手办池 & E宠池', 'Figure Pool & E-Pet Pool'),
                onTap: () {
                  if (guest) {
                    pushLoginPage(context);
                  } else {
                    context.push('/store/gacha');
                  }
                },
              ),
              const SizedBox(width: 12),
              HtmlStoreMiniTile(
                emoji: '🛍️',
                title: s.tr('直购商城', 'Direct Store'),
                subtitle: s.tr(
                  '头像框 · 流彩 · 卡面',
                  'Avatar Frame · Name Flow · Card',
                ),
                onTap: () {
                  if (guest) {
                    pushLoginPage(context);
                  } else {
                    context.push('/store/shop');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
