import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/gacha/cosmetic_preview_widgets.dart';
import '../../core/gacha/wealth_gacha.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/user_inventory_demo.dart';

/// 从底部滑出：仅展示已拥有藏品，带 √ 的为当前主页展示；点选可切换。
void openSelfShowcaseEditSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => const SelfShowcaseEditSheet(),
  );
}

class SelfShowcaseEditSheet extends StatefulWidget {
  const SelfShowcaseEditSheet({super.key});

  @override
  State<SelfShowcaseEditSheet> createState() => _SelfShowcaseEditSheetState();
}

class _SelfShowcaseEditSheetState extends State<SelfShowcaseEditSheet> {
  @override
  void initState() {
    super.initState();
    demoOwnedAssetIdsNotifier.addListener(_onInv);
    demoProfileEquipNotifier.addListener(_onInv);
  }

  void _onInv() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    demoOwnedAssetIdsNotifier.removeListener(_onInv);
    demoProfileEquipNotifier.removeListener(_onInv);
    super.dispose();
  }

  List<GachaCatalogEntry> _ownedOfKind(GachaAssetKind kind) {
    final owned = demoOwnedAssetIdsNotifier.value;
    return gachaCatalog.where((GachaCatalogEntry e) => e.kind == kind && owned.contains(e.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
    final equip = demoProfileEquipNotifier.value;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(HtmlDesignTokens.radiusXl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.97),
            border: Border(top: BorderSide(color: HtmlDesignTokens.accent.withValues(alpha: 0.55))),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HtmlDesignTokens.accent.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        '📦 编辑主页展柜',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HtmlDesignTokens.textMain,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                    Material(
                      color: HtmlDesignTokens.glassCard,
                      shape: CircleBorder(side: BorderSide(color: HtmlDesignTokens.glassBorder)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: HtmlDesignTokens.glassBorder),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: <Widget>[
                    _section(
                      title: '手办',
                      equippedId: equip.equippedFigureId,
                      kind: GachaAssetKind.figure,
                      onSelect: demoEquipSetFigure,
                    ),
                    _section(
                      title: 'E 宠',
                      equippedId: equip.equippedEpetId,
                      kind: GachaAssetKind.ePet,
                      onSelect: demoEquipSetEpet,
                    ),
                    _section(
                      title: '头像框',
                      equippedId: equip.equippedFrameId,
                      kind: GachaAssetKind.avatarFrame,
                      onSelect: demoEquipSetFrame,
                    ),
                    _section(
                      title: '卡面',
                      equippedId: equip.equippedCardFaceId,
                      kind: GachaAssetKind.cardFace,
                      onSelect: demoEquipSetCardFace,
                    ),
                    _section(
                      title: '昵称流彩',
                      equippedId: equip.equippedNameFlowId,
                      kind: GachaAssetKind.nameFlow,
                      onSelect: demoEquipSetNameFlow,
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

  Widget _section({
    required String title,
    required String? equippedId,
    required GachaAssetKind kind,
    required void Function(String id) onSelect,
  }) {
    final items = _ownedOfKind(kind);
    final total = gachaCatalog.where((e) => e.kind == kind).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HtmlDesignTokens.accent,
                  fontFamily: 'system-ui',
                ),
              ),
              Text(
                '${items.length}/$total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HtmlDesignTokens.textSub,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              '暂无藏品，可在补给舱或直购商城获取',
              style: TextStyle(
                fontSize: 12,
                color: HtmlDesignTokens.textSub.withValues(alpha: 0.9),
                fontFamily: 'system-ui',
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int i) {
                final e = items[i];
                final isEquipped = equippedId == e.id;
                return _EquipTile(
                  entry: e,
                  equipped: isEquipped,
                  onTap: () => onSelect(e.id),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EquipTile extends StatelessWidget {
  const _EquipTile({
    required this.entry,
    required this.equipped,
    required this.onTap,
  });

  final GachaCatalogEntry entry;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: equipped ? 0.12 : 0.06),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(
              color: equipped ? HtmlDesignTokens.accent.withValues(alpha: 0.65) : HtmlDesignTokens.glassBorder,
              width: equipped ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 52,
                      child: Center(
                        child: buildCosmeticOrAssetPreview(
                          entry,
                          maxSide: 48,
                          flowFontSize: 11,
                          animateFlow: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: HtmlDesignTokens.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.quality.displayZh,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: HtmlDesignTokens.primaryLight,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (equipped)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.8)),
                    ),
                    child: const Icon(Icons.check, color: HtmlDesignTokens.accent, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
