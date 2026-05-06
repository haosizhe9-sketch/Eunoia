import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/demo_e_points.dart';
import '../../core/gacha/cosmetic_preview_widgets.dart';
import '../../core/gacha/wealth_gacha.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart';
import '../../core/user_inventory_demo.dart';
import '../../core/theme/html_design_tokens.dart';

/// 与根目录 `index.html` 中「全息补给舱」同结构：手办池 / E宠池、单抽 / 十连（消耗抽卡盲盒券）、全屏动效与结果。
class GachaPage extends ConsumerStatefulWidget {
  const GachaPage({super.key});

  @override
  ConsumerState<GachaPage> createState() => _GachaPageState();
}

enum _OverlayPhase { idle, pulling, result }

class _GachaPageState extends ConsumerState<GachaPage>
    with TickerProviderStateMixin {
  final Random _random = Random();

  GachaSupplyPool _pool = GachaSupplyPool.figure;
  _OverlayPhase _phase = _OverlayPhase.idle;
  bool _tenPull = false;
  GachaRollOutcome? _singleOutcome;
  List<GachaRollOutcome>? _tenOutcomes;

  late AnimationController _floatCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _portalCtrl;
  late AnimationController _beamCtrl;
  late AnimationController _burstCtrl;
  late AnimationController _hintPulseCtrl;
  late AnimationController _flipCtrl;
  late AnimationController _tenStaggerCtrl;
  bool _syncingWallet = false;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _portalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _beamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _hintPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _tenStaggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    demoEPointsNotifier.addListener(_onPointsChanged);
    demoGachaTicketsNotifier.addListener(_onPointsChanged);
    demoOwnedAssetIdsNotifier.addListener(_onPointsChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncWalletFromProfile(),
    );
  }

  void _onPointsChanged() {
    if (mounted) setState(() {});
  }

  Set<String> get _ownedAssetIds => demoOwnedAssetIdsNotifier.value;

  @override
  void dispose() {
    demoOwnedAssetIdsNotifier.removeListener(_onPointsChanged);
    demoGachaTicketsNotifier.removeListener(_onPointsChanged);
    demoEPointsNotifier.removeListener(_onPointsChanged);
    _floatCtrl.dispose();
    _shakeCtrl.dispose();
    _portalCtrl.dispose();
    _beamCtrl.dispose();
    _burstCtrl.dispose();
    _hintPulseCtrl.dispose();
    _flipCtrl.dispose();
    _tenStaggerCtrl.dispose();
    super.dispose();
  }

  bool get _pet => _pool == GachaSupplyPool.pet;

  _PoolDef _poolDef(AppStrings s) {
    switch (_pool) {
      case GachaSupplyPool.figure:
        return _PoolDef(
          boxEmoji: '🎁',
          boxLabel: s.tr('限定手办序列', 'Limited Figure Series'),
          vol: 'FIGURE MATRIX · VOL.1',
        );
      case GachaSupplyPool.pet:
        return _PoolDef(
          boxEmoji: '🐾',
          boxLabel: s.tr('E宠共鸣序列', 'E-Pet Resonance Series'),
          vol: 'E-PET SYNC · VOL.1',
        );
    }
  }

  int get _pts => demoEPointsNotifier.value;

  int get _tickets => demoGachaTicketsNotifier.value;

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

  List<GachaRollOutcome> _rollTenOutcomes() {
    final batchOwned = Set<String>.from(_ownedAssetIds);
    final list = <GachaRollOutcome>[];
    for (var i = 0; i < 10; i++) {
      final o = GachaEngine.roll(
        random: _random,
        pool: _pool,
        ownedIds: batchOwned,
      );
      list.add(o);
      if (o is GachaAssetOutcome && !o.alreadyOwned) {
        batchOwned.add(o.entry.id);
      }
    }
    return list;
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

  Future<void> _pull(int count) async {
    final cost = count == 1
        ? GachaEngine.pullTicketsSingle
        : GachaEngine.pullTicketsTen;
    if (_tickets < cost || _phase != _OverlayPhase.idle) return;

    try {
      final int nextTickets = await ref
          .read(appDataServiceProvider)
          .spendBlindBoxTickets(cost);
      demoGachaTicketsNotifier.value = nextTickets;
    } catch (_) {
      return;
    }

    setState(() {
      _phase = _OverlayPhase.pulling;
      _tenPull = count == 10;
      _singleOutcome = null;
      _tenOutcomes = null;
    });

    _shakeCtrl.duration = Duration(milliseconds: count == 1 ? 850 : 1100);
    _shakeCtrl.forward(from: 0);

    _portalCtrl.duration = Duration(milliseconds: _pet ? 1200 : 3000);
    _portalCtrl.repeat();
    _beamCtrl.forward(from: 0);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _phase == _OverlayPhase.pulling) {
        _burstCtrl.forward(from: 0);
      }
    });

    final delay = count == 1
        ? const Duration(milliseconds: 1100)
        : const Duration(milliseconds: 1900);
    await Future<void>.delayed(delay);
    if (!mounted || _phase != _OverlayPhase.pulling) return;

    _portalCtrl.stop();
    _portalCtrl.reset();

    if (count == 10) {
      setState(() {
        _tenOutcomes = _rollTenOutcomes();
        _phase = _OverlayPhase.result;
      });
      _tenStaggerCtrl.forward(from: 0);
    } else {
      setState(() {
        _singleOutcome = GachaEngine.roll(
          random: _random,
          pool: _pool,
          ownedIds: _ownedAssetIds,
        );
        _phase = _OverlayPhase.result;
      });
      _flipCtrl.forward(from: 0);
    }
  }

  Future<void> _applyOutcomesAndClose() async {
    var pts = demoEPointsNotifier.value;
    final newIds = <String>{};
    var ePointGain = 0;
    void consume(GachaRollOutcome o) {
      switch (o) {
        case GachaAssetOutcome(:final entry, :final alreadyOwned):
          if (!alreadyOwned) {
            newIds.add(entry.id);
          }
        case GachaEPointsOutcome(:final amount):
          pts += amount;
          ePointGain += amount;
        case GachaNullOutcome():
          break;
      }
    }

    if (_singleOutcome != null) {
      consume(_singleOutcome!);
    }
    if (_tenOutcomes != null) {
      for (final o in _tenOutcomes!) {
        consume(o);
      }
    }
    if (newIds.isNotEmpty) {
      demoInventoryAddAllOwned(newIds);
    }
    if (ePointGain > 0 && isLoggedIn(ref)) {
      try {
        final int synced = await ref
            .read(appDataServiceProvider)
            .addEPoints(ePointGain);
        pts = synced;
      } catch (_) {
        // 回退为当前本地值，避免 UI 卡死。
      }
    }
    demoEPointsNotifier.value = pts;
    if (!mounted) return;

    setState(() {
      _phase = _OverlayPhase.idle;
      _tenPull = false;
      _singleOutcome = null;
      _tenOutcomes = null;
    });
    _portalCtrl.stop();
    _portalCtrl.reset();
    _beamCtrl.reset();
    _burstCtrl.reset();
    _flipCtrl.reset();
    _tenStaggerCtrl.reset();
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
    final AppStrings s = AppStrings.of(context);
    final _PoolDef def = _poolDef(s);
    final String dropHint =
        s.isZh ? _pool.dropTableHintZh : _pool.dropTableHintEn;
    final pts = _pts;
    final tickets = _tickets;
    final canSingle = tickets >= GachaEngine.pullTicketsSingle;
    final canTen = tickets >= GachaEngine.pullTicketsTen;

    return DecoratedBox(
      decoration: BoxDecoration(color: HtmlDesignTokens.gachaSubBg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 0.85,
                  colors: _pet
                      ? <Color>[
                          const Color(0x472DD4BF),
                          HtmlDesignTokens.gachaSubBg,
                        ]
                      : <Color>[
                          const Color(0x597C3AED),
                          HtmlDesignTokens.gachaSubBg,
                        ],
                  stops: const <double>[0, 0.72],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: HtmlDesignTokens.stackedPageAppBarPadding,
                  child: Row(
                    children: <Widget>[
                      _CircleIconButton(
                        onTap: () => context.pop(),
                        child: const Text(
                          '‹',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            s.tr('全息补给舱', 'Supply Bay'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'system-ui',
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: HtmlDesignTokens.glassBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Text(
                                      '🎟️',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$tickets',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                        fontFamily: 'system-ui',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: HtmlDesignTokens.glassBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Text(
                                      '✦',
                                      style: TextStyle(
                                        color: HtmlDesignTokens.primaryLight,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatPoints(pts),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
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
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _PoolTab(
                                label: s.tr('手办池', 'Figure Pool'),
                                active: !_pet,
                                figureStyle: true,
                                onTap: () => setState(
                                  () => _pool = GachaSupplyPool.figure,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PoolTab(
                                label: s.tr('E宠池', 'E-Pet Pool'),
                                active: _pet,
                                figureStyle: false,
                                onTap: () =>
                                    setState(() => _pool = GachaSupplyPool.pet),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          def.vol,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: HtmlDesignTokens.textSub,
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontFamily: 'system-ui',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dropHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: HtmlDesignTokens.textSub.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 10,
                            height: 1.35,
                            fontFamily: 'system-ui',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: Listenable.merge(<Listenable>[
                                _floatCtrl,
                                _shakeCtrl,
                              ]),
                              builder: (BuildContext context, _) {
                                final t = _floatCtrl.value;
                                final w = sin(pi * t);
                                final w2 = w * w;
                                final ty = -18.0 * w2;
                                final rx = (10 + 4 * w2) * pi / 180;
                                final ry = (-12 + 24 * w2) * pi / 180;

                                Matrix4 shake = Matrix4.identity();
                                if (_shakeCtrl.isAnimating) {
                                  final s = _shakeCtrl.value;
                                  if (_tenPull) {
                                    final rot = sin(s * pi * 4) * 0.2 * (1 - s);
                                    final sc = 1 + 0.12 * sin(s * pi * 3);
                                    shake = Matrix4.rotationZ(rot)
                                      ..scale(sc, sc, 1);
                                  } else {
                                    shake = Matrix4.translationValues(
                                      0,
                                      -6 * sin(s * pi * 2),
                                      0,
                                    );
                                    var sc =
                                        1 +
                                        0.08 *
                                            (1 - (s - 0.45).abs().clamp(0, 1));
                                    if (s > 0.4 && s < 0.55) {
                                      sc *= 1.03;
                                    }
                                    shake = shake..scale(sc, sc, 1);
                                  }
                                }

                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.translationValues(0, ty, 0)
                                    ..rotateX(rx)
                                    ..rotateY(ry)
                                    ..multiply(shake),
                                  child: Container(
                                    width: 200,
                                    height: 260,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      gradient: LinearGradient(
                                        begin: const Alignment(-1, -1),
                                        end: const Alignment(1, 1),
                                        colors: _pet
                                            ? <Color>[
                                                Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                                const Color(0x142DD4BF),
                                              ]
                                            : <Color>[
                                                Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                                const Color(0x0D7C3AED),
                                              ],
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.75,
                                          ),
                                          blurRadius: 30,
                                          offset: const Offset(0, 30),
                                        ),
                                        BoxShadow(
                                          color:
                                              (_pet
                                                      ? HtmlDesignTokens.accent
                                                      : HtmlDesignTokens
                                                            .primary)
                                                  .withValues(alpha: 0.35),
                                          blurRadius: 40,
                                          spreadRadius: -10,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 12,
                                          sigmaY: 12,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              def.boxEmoji,
                                              style: TextStyle(
                                                fontSize: 56,
                                                shadows: <Shadow>[
                                                  Shadow(
                                                    color:
                                                        (_pet
                                                                ? HtmlDesignTokens
                                                                      .accent
                                                                : HtmlDesignTokens
                                                                      .primary)
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              def.boxLabel,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: HtmlDesignTokens.textSub,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 2,
                                                fontFamily: 'system-ui',
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            Expanded(
                              flex: 1,
                              child: _GachaCostButton(
                                filled: false,
                                enabled:
                                    canSingle && _phase == _OverlayPhase.idle,
                                onTap: () => _pull(1),
                                title: s.tr('单次解密', 'Single Draw'),
                                subtitle: s.tr(
                                  '消耗 1 张盲盒券',
                                  'Costs 1 blind-box ticket',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _GachaCostButton(
                                filled: true,
                                petAccent: _pet,
                                enabled: canTen && _phase == _OverlayPhase.idle,
                                onTap: () => _pull(10),
                                title: s.tr('十阶跃迁', 'Ten-draw'),
                                subtitle: s.tr(
                                  '消耗 10 张盲盒券',
                                  'Costs 10 blind-box tickets',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_phase != _OverlayPhase.idle)
            Positioned.fill(
              child: _GachaOverlayLayer(
                s: s,
                pet: _pet,
                ten: _tenPull,
                phase: _phase,
                portalCtrl: _portalCtrl,
                beamCtrl: _beamCtrl,
                burstCtrl: _burstCtrl,
                hintPulse: _hintPulseCtrl,
                flipCtrl: _flipCtrl,
                pullHint: _tenPull
                    ? s.tr('十阶跃迁 · 矩阵展开…', 'Ten-draw · unfolding…')
                    : s.tr('单次解密 · 信道校准…', 'Single draw · syncing…'),
                single: _singleOutcome,
                tenList: _tenOutcomes,
                tenStagger: _tenStaggerCtrl,
                onClose: () {
                  _applyOutcomesAndClose();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PoolDef {
  const _PoolDef({
    required this.boxEmoji,
    required this.boxLabel,
    required this.vol,
  });

  final String boxEmoji;
  final String boxLabel;
  final String vol;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HtmlDesignTokens.glassCard,
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PoolTab extends StatelessWidget {
  const _PoolTab({
    required this.label,
    required this.active,
    required this.figureStyle,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool figureStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
            color: HtmlDesignTokens.glassCard,
            border: Border.all(
              color: active
                  ? (figureStyle
                        ? const Color(0x80A78BFA)
                        : const Color(0x732DD4BF))
                  : HtmlDesignTokens.glassBorder,
            ),
            gradient: active
                ? LinearGradient(
                    begin: const Alignment(-1, -1),
                    end: const Alignment(1, 1),
                    colors: figureStyle
                        ? <Color>[
                            const Color(0x597C3AED),
                            const Color(0x269333EA),
                          ]
                        : <Color>[
                            const Color(0x402DD4BF),
                            const Color(0x1F14B8A6),
                          ],
                  )
                : null,
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color:
                          (figureStyle
                                  ? HtmlDesignTokens.primary
                                  : HtmlDesignTokens.accent)
                              .withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : HtmlDesignTokens.textSub,
                fontFamily: 'system-ui',
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GachaCostButton extends StatelessWidget {
  const _GachaCostButton({
    required this.filled,
    required this.enabled,
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.petAccent = false,
  });

  final bool filled;
  final bool petAccent;
  final bool enabled;
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final gradient = filled
        ? LinearGradient(
            colors: petAccent
                ? <Color>[HtmlDesignTokens.accentDeep, HtmlDesignTokens.accent]
                : <Color>[HtmlDesignTokens.primary, const Color(0xFF9333EA)],
          )
        : null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
              gradient: gradient,
              color: filled ? null : HtmlDesignTokens.glassCard,
              border: Border.all(
                color: filled
                    ? Colors.transparent
                    : HtmlDesignTokens.glassBorder,
              ),
              boxShadow: filled
                  ? <BoxShadow>[
                      BoxShadow(
                        color:
                            (petAccent
                                    ? HtmlDesignTokens.accent
                                    : HtmlDesignTokens.primary)
                                .withValues(alpha: 0.45),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _qualityBorderColor(GachaQuality q) => switch (q) {
  GachaQuality.legendary => const Color(0xB3FACC15),
  GachaQuality.epic => const Color(0xB3A78BFA),
  GachaQuality.rare => const Color(0x9960A5FA),
};

Color? _qualityGlowColor(GachaQuality q) => switch (q) {
  GachaQuality.legendary => const Color(0x59FACC15),
  GachaQuality.epic => HtmlDesignTokens.primary.withValues(alpha: 0.4),
  GachaQuality.rare => null,
};

Color _qualityBorderColorMini(GachaQuality q) => switch (q) {
  GachaQuality.legendary => const Color(0x8CFACC15),
  GachaQuality.epic => const Color(0x80A78BFA),
  GachaQuality.rare => Colors.white.withValues(alpha: 0.15),
};

String _kindEmoji(GachaAssetKind k) => switch (k) {
  GachaAssetKind.figure => '🧸',
  GachaAssetKind.ePet => '🐾',
  GachaAssetKind.avatarFrame => '🖼️',
  GachaAssetKind.cardFace => '🎴',
  GachaAssetKind.nameFlow => '✨',
};

class _GachaOverlayLayer extends StatelessWidget {
  const _GachaOverlayLayer({
    required this.s,
    required this.pet,
    required this.ten,
    required this.phase,
    required this.portalCtrl,
    required this.beamCtrl,
    required this.burstCtrl,
    required this.hintPulse,
    required this.flipCtrl,
    required this.pullHint,
    required this.single,
    required this.tenList,
    required this.tenStagger,
    required this.onClose,
  });

  final AppStrings s;
  final bool pet;
  final bool ten;
  final _OverlayPhase phase;
  final AnimationController portalCtrl;
  final AnimationController beamCtrl;
  final AnimationController burstCtrl;
  final AnimationController hintPulse;
  final AnimationController flipCtrl;
  final String pullHint;
  final GachaRollOutcome? single;
  final List<GachaRollOutcome>? tenList;
  final Animation<double> tenStagger;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pulling = phase == _OverlayPhase.pulling;
    final result = phase == _OverlayPhase.result;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: const Color(0xEB05030F),
          child: pulling
              ? _buildPulling(context)
              : result
              ? _buildResult(context)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildPulling(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        RotationTransition(
          turns: portalCtrl,
          child: Transform.scale(
            scale: 1.05,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: pet
                      ? const Color(0x802DD4BF)
                      : const Color(0x66A78BFA),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color:
                        (pet
                                ? HtmlDesignTokens.accent
                                : HtmlDesignTokens.primary)
                            .withValues(alpha: 0.35),
                    blurRadius: 60,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: beamCtrl,
          builder: (BuildContext context, _) {
            final h = 420 * Curves.easeOut.transform(beamCtrl.value);
            return Align(
              alignment: Alignment.center,
              child: Container(
                width: 6,
                height: h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: pet
                        ? <Color>[
                            Colors.transparent,
                            const Color(0xFF5EEAD4),
                            Colors.transparent,
                          ]
                        : <Color>[
                            Colors.transparent,
                            HtmlDesignTokens.primaryLight,
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: burstCtrl,
          builder: (BuildContext context, _) {
            final t = Curves.easeOut.transform(burstCtrl.value);
            final scale = ten
                ? lerpDouble(0.2, 1.6, t)!
                : lerpDouble(0.3, 1.4, t)!;
            final rot = ten ? t * 3 * pi : 0.0;
            final op = ten
                ? (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0)
                : (t < 0.4 ? t / 0.4 : (1 - t) / 0.6).clamp(0.0, 1.0);
            return Opacity(
              opacity: op * 0.9,
              child: Transform.rotate(
                angle: rot,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                        stops: const <double>[0, 0.45],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 120,
          left: 16,
          right: 16,
          child: AnimatedBuilder(
            animation: hintPulse,
            builder: (BuildContext context, _) {
              final o = lerpDouble(0.5, 1, sin(pi * hintPulse.value).abs())!;
              return Opacity(
                opacity: o,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      pullHint,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        color: HtmlDesignTokens.textSub,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    if (ten && tenList != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
        child: Column(
          children: <Widget>[
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (BuildContext context, double scale, Widget? child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    const gap = 8.0;
                    final w = c.maxWidth;
                    final cellW = (w - 4 * gap) / 5;
                    final cellH = cellW * 7 / 5;

                    Widget row(int start) {
                      return SizedBox(
                        height: cellH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (var j = 0; j < 5; j++) ...<Widget>[
                              if (j > 0) const SizedBox(width: gap),
                              Expanded(
                                child: _StaggerMiniCard(
                                  index: start + j,
                                  outcome: tenList![start + j],
                                  stagger: tenStagger,
                                  s: s,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        row(0),
                        const SizedBox(height: gap),
                        row(5),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            _OverlayPillButton(
              label: s.tr('全部收下', 'Claim all'),
              onTap: onClose,
            ),
          ],
        ),
      );
    }

    if (single != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedBuilder(
              animation: flipCtrl,
              builder: (BuildContext context, _) {
                final t = Curves.easeOutCubic.transform(flipCtrl.value);
                final angle = (1 - t) * pi / 2;
                final m = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle);
                return Opacity(
                  opacity: t,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: m,
                    child: Transform.scale(
                      scale: lerpDouble(0.4, 1, Curves.easeOut.transform(t))!,
                      child: _OutcomeBigCard(outcome: single!, s: s),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _OverlayPillButton(
              label: s.tr('收下', 'Claim'),
              onTap: onClose,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _OutcomeBigCard extends StatelessWidget {
  const _OutcomeBigCard({required this.outcome, required this.s});

  final GachaRollOutcome outcome;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return switch (outcome) {
      GachaAssetOutcome(:final entry, :final alreadyOwned) => _AssetBigBody(
        entry: entry,
        alreadyOwned: alreadyOwned,
        s: s,
      ),
      GachaEPointsOutcome(:final amount) => _GenericBigBody(
        border: const Color(0xB338BDF8),
        glow: const Color(0x4038BDF8),
        topChild: const Text(
          '✦',
          style: TextStyle(fontSize: 64, color: HtmlDesignTokens.primaryLight),
        ),
        title: s.tr('E点补给箱', 'E-Point Crate'),
        subtitle: s.tr('+$amount E点', '+$amount E-Points'),
      ),
      GachaNullOutcome() => _GenericBigBody(
        border: Colors.white.withValues(alpha: 0.2),
        glow: null,
        topChild: const Text(
          '◇',
          style: TextStyle(fontSize: 64, color: HtmlDesignTokens.textSub),
        ),
        title: s.tr('虚无一掷', 'Empty Pull'),
        subtitle: s.tr('本次无掉落', 'No drop this time'),
      ),
    };
  }
}

class _AssetBigBody extends StatelessWidget {
  const _AssetBigBody({
    required this.entry,
    required this.alreadyOwned,
    required this.s,
  });

  final GachaCatalogEntry entry;
  final bool alreadyOwned;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final border = _qualityBorderColor(entry.quality);
    final glow = _qualityGlowColor(entry.quality);

    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 2),
        boxShadow: <BoxShadow>[
          if (glow != null)
            BoxShadow(color: glow, blurRadius: 40, spreadRadius: 0),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 50,
            offset: const Offset(0, 25),
          ),
        ],
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: Center(
                        child:
                            entry.kind == GachaAssetKind.avatarFrame ||
                                entry.kind == GachaAssetKind.nameFlow
                            ? buildCosmeticOrAssetPreview(
                                entry,
                                maxSide: 88,
                                flowFontSize: 18,
                                animateFlow: true,
                              )
                            : Image.asset(
                                entry.previewAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) => Text(
                                      _kindEmoji(entry.kind),
                                      style: const TextStyle(fontSize: 72),
                                    ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.tr(entry.kind.displayZh, entry.kind.displayEn),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HtmlDesignTokens.textSub,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    if (entry.subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        entry.subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HtmlDesignTokens.textSub.withValues(
                            alpha: 0.9,
                          ),
                          fontSize: 10,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${s.tr(entry.quality.displayZh, entry.quality.displayEn)} · ${s.tr(entry.quality.colorLabel, entry.quality.colorLabelEn)}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HtmlDesignTokens.textSub,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (alreadyOwned)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  s.tr('已拥有', 'Owned'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GenericBigBody extends StatelessWidget {
  const _GenericBigBody({
    required this.border,
    required this.glow,
    required this.topChild,
    required this.title,
    required this.subtitle,
  });

  final Color border;
  final Color? glow;
  final Widget topChild;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 2),
        boxShadow: <BoxShadow>[
          if (glow != null)
            BoxShadow(color: glow!, blurRadius: 40, spreadRadius: 0),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 50,
            offset: const Offset(0, 25),
          ),
        ],
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          topChild,
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HtmlDesignTokens.textSub,
              fontSize: 12,
              letterSpacing: 1,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggerMiniCard extends StatelessWidget {
  const _StaggerMiniCard({
    required this.index,
    required this.outcome,
    required this.stagger,
    required this.s,
  });

  final int index;
  final GachaRollOutcome outcome;
  final Animation<double> stagger;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stagger,
      builder: (BuildContext context, _) {
        final v = stagger.value;
        final start = index * 0.05;
        const window = 0.45;
        final end = start + window;
        double t;
        if (v <= start) {
          t = 0;
        } else if (v >= end) {
          t = 1;
        } else {
          t = (v - start) / window;
        }
        t = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: _OutcomeMiniCard(outcome: outcome, s: s),
          ),
        );
      },
    );
  }
}

class _OutcomeMiniCard extends StatelessWidget {
  const _OutcomeMiniCard({required this.outcome, required this.s});

  final GachaRollOutcome outcome;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return switch (outcome) {
      GachaAssetOutcome(:final entry, :final alreadyOwned) => _AssetMiniBody(
        entry: entry,
        alreadyOwned: alreadyOwned,
        s: s,
      ),
      GachaEPointsOutcome(:final amount) => _PlainMiniBody(
        border: const Color(0x8038BDF8),
        icon: const Text(
          '✦',
          style: TextStyle(fontSize: 22, color: HtmlDesignTokens.primaryLight),
        ),
        label: '+$amount',
        legendaryGlow: false,
      ),
      GachaNullOutcome() => _PlainMiniBody(
        border: Colors.white.withValues(alpha: 0.12),
        icon: const Text(
          '◇',
          style: TextStyle(fontSize: 20, color: HtmlDesignTokens.textSub),
        ),
        label: s.tr('无', 'None'),
        legendaryGlow: false,
      ),
    };
  }
}

class _AssetMiniBody extends StatelessWidget {
  const _AssetMiniBody({
    required this.entry,
    required this.alreadyOwned,
    required this.s,
  });

  final GachaCatalogEntry entry;
  final bool alreadyOwned;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final border = _qualityBorderColorMini(entry.quality);
    final leg = entry.quality == GachaQuality.legendary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        gradient: LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: <Color>[
            Colors.white.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.2),
          ],
        ),
        boxShadow: leg
            ? <BoxShadow>[
                const BoxShadow(color: Color(0x40FACC15), blurRadius: 16),
              ]
            : null,
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 38,
                      width: double.infinity,
                      child: Center(
                        child:
                            entry.kind == GachaAssetKind.avatarFrame ||
                                entry.kind == GachaAssetKind.nameFlow
                            ? buildCosmeticOrAssetPreview(
                                entry,
                                maxSide: 34,
                                flowFontSize: 9,
                                animateFlow: false,
                              )
                            : Image.asset(
                                entry.previewAsset,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                errorBuilder:
                                    (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) => Text(
                                      _kindEmoji(entry.kind),
                                      style: const TextStyle(fontSize: 26),
                                    ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HtmlDesignTokens.textSub,
                        fontSize: 8,
                        height: 1.15,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (alreadyOwned)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.tr('已有', 'Owned'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 7,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlainMiniBody extends StatelessWidget {
  const _PlainMiniBody({
    required this.border,
    required this.icon,
    required this.label,
    required this.legendaryGlow,
  });

  final Color border;
  final Widget icon;
  final String label;
  final bool legendaryGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        gradient: LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: <Color>[
            Colors.white.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.2),
          ],
        ),
        boxShadow: legendaryGlow
            ? <BoxShadow>[
                const BoxShadow(color: Color(0x40FACC15), blurRadius: 16),
              ]
            : null,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              icon,
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HtmlDesignTokens.textSub,
                  fontSize: 9,
                  height: 1.1,
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

class _OverlayPillButton extends StatelessWidget {
  const _OverlayPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ),
    );
  }
}
