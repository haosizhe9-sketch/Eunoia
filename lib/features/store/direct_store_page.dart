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

String _formatShopPoints(int n) {
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

/// 与图鉴 [gachaCatalog] 对齐：直购上架全部头像框、卡面、昵称流彩。
class DirectStorePage extends ConsumerStatefulWidget {
  const DirectStorePage({super.key});

  @override
  ConsumerState<DirectStorePage> createState() => _DirectStorePageState();
}

enum _ShopFilter { all, frame, namefx, cardface }

class _ShopProduct {
  const _ShopProduct(this.entry);

  final GachaCatalogEntry entry;

  _ShopFilter get filter => switch (entry.kind) {
    GachaAssetKind.avatarFrame => _ShopFilter.frame,
    GachaAssetKind.nameFlow => _ShopFilter.namefx,
    GachaAssetKind.cardFace => _ShopFilter.cardface,
    _ => _ShopFilter.all,
  };

  String get id => entry.id;

  String get name => entry.name;

  int get price => directShopPriceEPoints(entry);

  String rarityLabel(AppStrings s) => switch (entry.quality) {
    GachaQuality.legendary => s.tr('传说', 'Legendary'),
    GachaQuality.epic => s.tr('史诗', 'Epic'),
    GachaQuality.rare => s.tr('稀有', 'Rare'),
  };

  String description(AppStrings s) {
    final String? sub = entry.subtitle;
    if (sub != null && sub.isNotEmpty) {
      return sub;
    }
    return '${s.tr(entry.kind.displayZh, entry.kind.displayEn)} · ${s.tr(entry.quality.displayZh, entry.quality.displayEn)}';
  }
}

int _kindOrder(GachaAssetKind k) => switch (k) {
  GachaAssetKind.avatarFrame => 0,
  GachaAssetKind.nameFlow => 1,
  GachaAssetKind.cardFace => 2,
  _ => 99,
};

int _qualityOrder(GachaQuality q) => switch (q) {
  GachaQuality.legendary => 0,
  GachaQuality.epic => 1,
  GachaQuality.rare => 2,
};

class _DirectStorePageState extends ConsumerState<DirectStorePage> {
  static final List<_ShopProduct> _products = () {
    final list = directShopCatalogEntries.map(_ShopProduct.new).toList();
    list.sort((a, b) {
      final ko = _kindOrder(a.entry.kind).compareTo(_kindOrder(b.entry.kind));
      if (ko != 0) return ko;
      final qo = _qualityOrder(
        a.entry.quality,
      ).compareTo(_qualityOrder(b.entry.quality));
      if (qo != 0) return qo;
      return a.id.compareTo(b.id);
    });
    return list;
  }();

  _ShopFilter _filter = _ShopFilter.all;
  bool _syncingEPoints = false;

  @override
  void initState() {
    super.initState();
    demoEPointsNotifier.addListener(_onPoints);
    demoOwnedAssetIdsNotifier.addListener(_onPoints);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncEPointsFromProfile(),
    );
  }

  void _onPoints() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    demoOwnedAssetIdsNotifier.removeListener(_onPoints);
    demoEPointsNotifier.removeListener(_onPoints);
    super.dispose();
  }

  List<_ShopProduct> get _visible {
    if (_filter == _ShopFilter.all) return _products;
    return _products.where((p) => p.filter == _filter).toList();
  }

  Future<void> _syncEPointsFromProfile() async {
    if (!isLoggedIn(ref) || _syncingEPoints) return;
    _syncingEPoints = true;
    try {
      final int? n = await ref.read(appDataServiceProvider).fetchEPoints();
      if (n != null) {
        demoEPointsNotifier.value = n;
      }
    } finally {
      _syncingEPoints = false;
    }
  }

  Future<void> _buy(_ShopProduct product) async {
    if (demoOwnedAssetIdsNotifier.value.contains(product.entry.id)) {
      return;
    }
    final pts = demoEPointsNotifier.value;
    final price = product.price;
    if (pts < price) return;
    try {
      final int next = await ref
          .read(appDataServiceProvider)
          .spendEPoints(price);
      demoEPointsNotifier.value = next;
    } catch (_) {
      return;
    }
    demoInventoryAddOwned(product.entry.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileRevisionProvider, (int? previous, int next) {
      _syncEPointsFromProfile();
    });
    ref.listen<AsyncValue<User?>>(authUserProvider, (
      AsyncValue<User?>? previous,
      AsyncValue<User?> next,
    ) {
      _syncEPointsFromProfile();
    });
    final AppStrings s = AppStrings.of(context);
    final pts = demoEPointsNotifier.value;

    return DecoratedBox(
      decoration: const BoxDecoration(color: HtmlDesignTokens.gachaSubBg),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.55),
                  radius: 1.05,
                  colors: <Color>[
                    const Color(0x387C3AED),
                    HtmlDesignTokens.gachaSubBg,
                  ],
                  stops: const <double>[0, 0.7],
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
                        child: Text(
                          s.tr('直购商城', 'Direct Store'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'system-ui',
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatShopPoints(pts),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: <Widget>[
                        _CategoryChip(
                          label: s.tr('全部', 'All'),
                          active: _filter == _ShopFilter.all,
                          onTap: () =>
                              setState(() => _filter = _ShopFilter.all),
                        ),
                        const SizedBox(width: 10),
                        _CategoryChip(
                          label: s.tr('头像框', 'Frames'),
                          active: _filter == _ShopFilter.frame,
                          onTap: () =>
                              setState(() => _filter = _ShopFilter.frame),
                        ),
                        const SizedBox(width: 10),
                        _CategoryChip(
                          label: s.tr('昵称流彩', 'Name Flows'),
                          active: _filter == _ShopFilter.namefx,
                          onTap: () =>
                              setState(() => _filter = _ShopFilter.namefx),
                        ),
                        const SizedBox(width: 10),
                        _CategoryChip(
                          label: s.tr('卡面', 'Card Faces'),
                          active: _filter == _ShopFilter.cardface,
                          onTap: () =>
                              setState(() => _filter = _ShopFilter.cardface),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.64,
                        ),
                    itemCount: _visible.length,
                    itemBuilder: (BuildContext context, int i) {
                      final p = _visible[i];
                      final owned = demoOwnedAssetIdsNotifier.value.contains(
                        p.entry.id,
                      );
                      return _ProductTile(
                        product: p,
                        strings: s,
                        owned: owned,
                        canAfford: pts >= p.price,
                        onBuy: () {
                          _buy(p);
                        },
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
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HtmlDesignTokens.glassCard,
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.1)
                : HtmlDesignTokens.glassCard,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.2)
                  : HtmlDesignTokens.glassBorder,
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active
                  ? HtmlDesignTokens.textMain
                  : HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.strings,
    required this.owned,
    required this.canAfford,
    required this.onBuy,
  });

  final _ShopProduct product;
  final AppStrings strings;
  final bool owned;
  final bool canAfford;
  final VoidCallback onBuy;

  static const Color _goldLegendary = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: owned ? 0.48 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                      _RarityTag(
                        quality: product.entry.quality,
                        label: product.rarityLabel(strings),
                      ),
                      Center(child: _CatalogPreview(entry: product.entry)),
                      if (owned)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                strings.tr('已拥有', 'Owned'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'system-ui',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.description(strings),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: HtmlDesignTokens.textSub,
                    fontFamily: 'system-ui',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(
                      HtmlDesignTokens.radiusMd,
                    ),
                    child: InkWell(
                      onTap: (!owned && canAfford) ? onBuy : null,
                      borderRadius: BorderRadius.circular(
                        HtmlDesignTokens.radiusMd,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            HtmlDesignTokens.radiusMd,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: owned
                            ? Text(
                                strings.tr('已拥有', 'Owned'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'system-ui',
                                  color: HtmlDesignTokens.textSub.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'system-ui',
                                      color:
                                          product.entry.quality ==
                                              GachaQuality.legendary
                                          ? _goldLegendary
                                          : HtmlDesignTokens.accent,
                                    ),
                                    children: <InlineSpan>[
                                      const TextSpan(text: '✦ '),
                                      TextSpan(
                                        text: strings.tr(
                                          '${_formatShopPoints(product.price)} E点',
                                          '${_formatShopPoints(product.price)} E-Points',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
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
    );
  }
}

class _RarityTag extends StatelessWidget {
  const _RarityTag({required this.quality, required this.label});

  final GachaQuality quality;
  final String label;

  @override
  Widget build(BuildContext context) {
    Color fg = HtmlDesignTokens.primaryLight;
    Color bg = const Color(0x337C3AED);
    Border border = Border(
      bottom: BorderSide(
        color: HtmlDesignTokens.primary.withValues(alpha: 0.4),
      ),
      right: BorderSide(color: HtmlDesignTokens.primary.withValues(alpha: 0.4)),
    );
    switch (quality) {
      case GachaQuality.legendary:
        fg = const Color(0xFFFBBF24);
        bg = const Color(0x26FBBF24);
        border = Border(
          bottom: BorderSide(color: const Color(0x4DFBBF24)),
          right: BorderSide(color: const Color(0x4DFBBF24)),
        );
      case GachaQuality.epic:
        fg = const Color(0xFFC4B5FD);
        bg = const Color(0x2E6D28D9);
        border = Border(
          bottom: BorderSide(color: const Color(0x59A78BFA)),
          right: BorderSide(color: const Color(0x59A78BFA)),
        );
      case GachaQuality.rare:
        fg = const Color(0xFF93C5FD);
        bg = const Color(0x2E3B82F6);
        border = Border(
          bottom: BorderSide(color: const Color(0x5960A5FA)),
          right: BorderSide(color: const Color(0x5960A5FA)),
        );
    }
    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(12),
          ),
          border: border,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ),
    );
  }
}

String _previewFallbackEmoji(GachaAssetKind k) => switch (k) {
  GachaAssetKind.avatarFrame => '🖼️',
  GachaAssetKind.nameFlow => '✨',
  GachaAssetKind.cardFace => '🎴',
  _ => '✦',
};

class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({required this.entry});

  final GachaCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => ColoredBox(
      color: Colors.white.withValues(alpha: 0.06),
      child: Center(
        child: Text(
          _previewFallbackEmoji(entry.kind),
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );

    if (entry.kind == GachaAssetKind.avatarFrame) {
      return SizedBox(
        height: 100,
        width: double.infinity,
        child: Center(child: AvatarFramePreview(frameId: entry.id, size: 78)),
      );
    }
    if (entry.kind == GachaAssetKind.nameFlow) {
      return SizedBox(
        height: 100,
        width: double.infinity,
        child: Center(
          child: NameFlowPreview(
            entry: entry,
            maxWidth: 130,
            fontSize: 15,
            animate: false,
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      width: double.infinity,
      child: Center(
        child: entry.kind == GachaAssetKind.cardFace
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 96,
                  child: Image.asset(
                    entry.previewAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => fallback(),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Image.asset(
                    entry.previewAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => fallback(),
                  ),
                ),
              ),
      ),
    );
  }
}
