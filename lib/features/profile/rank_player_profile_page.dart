import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gacha/cosmetic_preview_widgets.dart';
import '../../core/gacha/wealth_gacha.dart';
import '../../core/providers/community_social_providers.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/user_inventory_demo.dart';
import '../community/community_social_repository.dart';
import 'epet_model_viewer.dart';
import 'handoff_model_viewer.dart';
import 'leaderboard_entry.dart';
import 'self_showcase_edit_sheet.dart';

const Color _kEpicBg = Color(0xFF05020A);
const Color _kPinkGlow = Color(0xFFFF61D2);

/// 档案页头像占位：与 [AvatarFramePreview] 的 [size] 一致，避免「未装备 / 装备头像框」切换时布局跳动。
/// 取约 60 ≈ 104×0.58，与原先无框时 ~60px 内圈接近。
const double _kProfileAvatarSlot = 104;

/// 无头像框时内圈直径（白边内深色底 + emoji），与槽位比例协调。
const double _kPlainAvatarInnerD = 66;

/// 词塔榜用户的「词塔层数」即 score；财富榜用户用手动映射演示档案里的层数。
int profileTowerLayersForEntry(LeaderboardEntry e) {
  if (e.isTowerBoard) return e.score;
  return _wealthUidToTowerLayers[e.uid] ?? 0;
}

const Map<String, int> _wealthUidToTowerLayers = <String, int>{
  '100001': 42,
  '880001': 108,
  '770002': 96,
  '660003': 72,
  '100456': 128,
  '201934': 55,
  '501111': 88,
  '501222': 76,
  '501333': 64,
  '501444': 52,
  '501555': 40,
};

String figureEmojiForAvatar(String avatarEmoji) {
  const Map<String, String> m = <String, String>{
    '🐼': '🧙‍♂️',
    '🦊': '🧝‍♀️',
    '🐳': '🧜‍♀️',
    '🐱': '🦸‍♀️',
    '🐯': '🦹‍♂️',
    '🐰': '🧚‍♀️',
    '🐶': '🕵️‍♂️',
    '🦄': '🧝‍♂️',
    '🦁': '🤴',
    '🐢': '🥷',
    '👾': '🧑‍🚀',
    '🦉': '🧛‍♂️',
    '🐦': '🧞‍♂️',
    '🐻': '🧟‍♂️',
    '⭐': '👼',
    '💎': '🥷',
    '🐋': '🧜‍♂️',
    '🐺': '🧌',
    '🦅': '🦅',
    '🐸': '🧙',
    '📚': '🧑‍🏫',
    '🐹': '🧝',
  };
  return m[avatarEmoji] ?? '🧝‍♀️';
}

/// 对应 `rank.html` 中 `.epic-profile-page` + `.showcase-backdrop` 演示。
class RankPlayerProfilePage extends ConsumerStatefulWidget {
  const RankPlayerProfilePage({
    super.key,
    required this.entry,
    required this.isSelf,
    required this.boardIsTower,
  });

  final LeaderboardEntry entry;
  final bool isSelf;
  final bool boardIsTower;

  @override
  ConsumerState<RankPlayerProfilePage> createState() => _RankPlayerProfilePageState();
}

class _RankPlayerProfilePageState extends ConsumerState<RankPlayerProfilePage>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    if (widget.isSelf) {
      demoProfileEquipNotifier.addListener(_onSelfEquipChanged);
      demoOwnedAssetIdsNotifier.addListener(_onSelfEquipChanged);
    }
  }

  void _onSelfEquipChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.isSelf) {
      demoProfileEquipNotifier.removeListener(_onSelfEquipChanged);
      demoOwnedAssetIdsNotifier.removeListener(_onSelfEquipChanged);
    }
    _floatController.dispose();
    super.dispose();
  }

  int get _towerLayers => profileTowerLayersForEntry(widget.entry);

  String get _figureEmoji => figureEmojiForAvatar(widget.entry.emoji);

  DemoProfileEquip? get _selfEquip => widget.isSelf ? demoProfileEquipNotifier.value : null;

  String get _selfFigureGlb =>
      widget.isSelf ? demoFigureGlbPath(_selfEquip?.equippedFigureId) : widget.entry.showcaseGlbAssetPath;

  String? get _selfEpetGlb =>
      widget.isSelf ? demoEpetGlbPath(_selfEquip?.equippedEpetId) : widget.entry.epetGlbAssetPath;

  @override
  Widget build(BuildContext context) {
    final GachaCatalogEntry? nameFlowEntry = widget.isSelf && _selfEquip?.equippedNameFlowId != null
        ? catalogEntryById(_selfEquip!.equippedNameFlowId!)
        : null;

    return Scaffold(
      backgroundColor: _kEpicBg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _EpicBackground(),
          SafeArea(
            minimum: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (widget.isSelf && _selfEquip?.equippedFrameId != null)
                              AvatarFramePreview(
                                frameId: _selfEquip!.equippedFrameId!,
                                size: _kProfileAvatarSlot,
                                avatarBuilder: (double d) => Text(
                                  widget.entry.emoji,
                                  style: TextStyle(fontSize: d * 0.45),
                                ),
                              )
                            else
                              _PlainWhiteAvatarFrame(emoji: widget.entry.emoji),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                  // 固定行高 + 左对齐：切换昵称流彩时与默认白字昵称同位置，不跳动
                                  SizedBox(
                                    height: 30,
                                    width: double.infinity,
                                    child: nameFlowEntry != null
                                        ? NameFlowPreview(
                                            entry: nameFlowEntry,
                                            maxWidth: double.infinity,
                                            fontSize: 20,
                                            animate: true,
                                            displayText: widget.entry.name,
                                            leftAlign: true,
                                            fixedHeight: 30,
                                          )
                                        : Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              widget.entry.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                fontFamily: 'system-ui',
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'UID: ${widget.entry.uid}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: HtmlDesignTokens.textMain,
                                        letterSpacing: 0.5,
                                        fontFamily: 'system-ui',
                                      ),
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.close, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isSelf) ...<Widget>[
                  Builder(
                    builder: (BuildContext context) {
                      final ce = catalogEntryById(_selfEquip?.equippedCardFaceId ?? '');
                      if (ce == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text(
                                '展示卡面',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: HtmlDesignTokens.textSub,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                              const SizedBox(width: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 52,
                                  height: 74,
                                  child: Image.asset(
                                    ce.previewAsset,
                                    fit: BoxFit.cover,
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const ColoredBox(
                                      color: Color(0x22FFFFFF),
                                      child: Center(child: Text('🎴', style: TextStyle(fontSize: 22))),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                Expanded(
                  child: _ShowcaseStage(
                    floatController: _floatController,
                    glbAssetPath: _selfFigureGlb,
                    epetGlbAssetPath: _selfEpetGlb,
                    figureEmoji: _figureEmoji,
                  ),
                ),
                _ProfileBottomPanel(
                  towerLayers: _towerLayers,
                  isSelf: widget.isSelf,
                  onViewShowcase: widget.isSelf
                      ? () => openSelfShowcaseEditSheet(context)
                      : () => _openShowcaseSheet(context, widget.entry.name),
                  onFriend: () async {
                    final String uid = widget.entry.uid.trim();
                    if (!CommunitySocialRepository.isAuthUserUuid(uid)) {
                      showAppTopSnackBar(
                        context,
                        const Text('该榜条目为演示数据，无真实账号，无法发起好友请求'),
                      );
                      return;
                    }
                    final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
                    final String? err = await repo.sendFriendRequest(uid);
                    if (!context.mounted) {
                      return;
                    }
                    if (err == null) {
                      showAppTopSnackBar(context, const Text('好友请求已发送'));
                    } else {
                      showAppTopSnackBar(context, Text(err));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openShowcaseSheet(BuildContext context, String ownerName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return _ShowcaseSheet(ownerName: ownerName);
      },
    );
  }
}

class _EpicBackground extends StatelessWidget {
  const _EpicBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.85),
              radius: 1.2,
              colors: <Color>[
                HtmlDesignTokens.primary.withValues(alpha: 0.28),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.9, 0.9),
              radius: 0.85,
              colors: <Color>[
                HtmlDesignTokens.accent.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 未装备头像框：纯白细环 + 圆形内槽（与抽卡/展柜编辑中「基础」观感一致，区别于炫彩框）。
class _PlainWhiteAvatarFrame extends StatelessWidget {
  const _PlainWhiteAvatarFrame({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kProfileAvatarSlot,
      height: _kProfileAvatarSlot,
      child: Center(
        child: Container(
          width: _kPlainAvatarInnerD,
          height: _kPlainAvatarInnerD,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _kEpicBg,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}

class _ShowcaseStage extends StatelessWidget {
  const _ShowcaseStage({
    required this.floatController,
    required this.glbAssetPath,
    required this.epetGlbAssetPath,
    required this.figureEmoji,
  });

  final AnimationController floatController;
  final String glbAssetPath;
  final String? epetGlbAssetPath;
  final String figureEmoji;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double stageH = math.min(720, c.maxHeight * 0.86);
        final bool hasEpet = epetGlbAssetPath != null;
        // 手办相对「整块展区」几何居中；E 宠叠在右下，IgnorePointer 避免挡住手办 WebView 手势。
        final double handoffW = math.min(440, c.maxWidth * 0.92);
        final double emojiSize = math.min(140, c.maxWidth * 0.38);
        final Size epetSize = epetShowcaseViewportSize(c);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            Center(
              child: AnimatedBuilder(
                animation: floatController,
                builder: (BuildContext context, Widget? child) {
                  final double t = floatController.value;
                  final double dy = -10 * math.sin(t * math.pi);
                  return Transform.translate(offset: Offset(0, dy), child: child);
                },
                child: HandoffFigureViewer(
                  width: handoffW,
                  height: stageH,
                  glbAssetPath: glbAssetPath,
                  fallbackEmoji: figureEmoji,
                  fallbackEmojiStyle: TextStyle(
                    fontSize: emojiSize,
                    shadows: <Shadow>[
                      Shadow(
                        color: HtmlDesignTokens.primary.withValues(alpha: 0.55),
                        blurRadius: 28,
                      ),
                      const Shadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 14)),
                    ],
                  ),
                ),
              ),
            ),
            if (hasEpet)
              Positioned(
                right: 10,
                bottom: 10,
                child: AnimatedBuilder(
                  animation: floatController,
                  builder: (BuildContext context, Widget? child) {
                    final double t = floatController.value;
                    final double dy = -8 * math.sin(t * math.pi);
                    return Transform.translate(offset: Offset(0, dy), child: child);
                  },
                  child: EpetFigureViewer(
                    glbAssetPath: epetGlbAssetPath!,
                    width: epetSize.width,
                    height: epetSize.height,
                    fallbackEmoji: '🐾',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileBottomPanel extends StatelessWidget {
  const _ProfileBottomPanel({
    required this.towerLayers,
    required this.isSelf,
    required this.onViewShowcase,
    required this.onFriend,
  });

  final int towerLayers;
  final bool isSelf;
  final VoidCallback onViewShowcase;
  final VoidCallback onFriend;

  @override
  Widget build(BuildContext context) {
    const int figCur = 45;
    const int figMax = 50;
    const int petCur = 12;
    const int petMax = 20;
    final double towerRatio = (towerLayers / 150).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            _kEpicBg.withValues(alpha: 0.92),
            _kEpicBg,
          ],
          stops: const <double>[0, 0.15, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.accent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.45), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Progress & Archives (数据档案)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: HtmlDesignTokens.textMain,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: HtmlDesignTokens.textSub, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _CollectCard(
                  title: '手办图鉴',
                  valueText: '$figCur/$figMax',
                  barFraction: figCur / figMax,
                  barGradient: const LinearGradient(
                    colors: <Color>[HtmlDesignTokens.accent, Color(0xFF3B82F6)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CollectCard(
                  title: 'E宠收集进度',
                  valueText: '$petCur/$petMax',
                  barFraction: petCur / petMax,
                  barGradient: LinearGradient(
                    colors: <Color>[HtmlDesignTokens.primary, _kPinkGlow],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CollectCard(
                  title: '词塔层数',
                  valueText: '$towerLayers 层',
                  barFraction: towerRatio,
                  barGradient: const LinearGradient(
                    colors: <Color>[LeaderboardTokens.goldGlow, LeaderboardTokens.bronze],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _PanelActionButton(
                  label: isSelf ? '编辑主页展柜' : '查看展柜',
                  highlight: false,
                  onPressed: onViewShowcase,
                ),
              ),
              if (!isSelf) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: _PanelActionButton(
                    label: '加为好友',
                    highlight: true,
                    onPressed: onFriend,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectCard extends StatelessWidget {
  const _CollectCard({
    required this.title,
    required this.valueText,
    required this.barFraction,
    required this.barGradient,
  });

  final String title;
  final String valueText;
  final double barFraction;
  final Gradient barGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            valueText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: Colors.white.withValues(alpha: 0.1)),
                  FractionallySizedBox(
                    widthFactor: barFraction.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(decoration: BoxDecoration(gradient: barGradient)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelActionButton extends StatelessWidget {
  const _PanelActionButton({
    required this.label,
    required this.highlight,
    required this.onPressed,
  });

  final String label;
  final bool highlight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(100),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: highlight
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[HtmlDesignTokens.primary, Color(0xFF9333EA)],
                  )
                : null,
            color: highlight ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: highlight ? Colors.transparent : Colors.white.withValues(alpha: 0.15),
            ),
            boxShadow: highlight
                ? <BoxShadow>[
                    BoxShadow(
                      color: HtmlDesignTokens.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: highlight ? Colors.white : HtmlDesignTokens.textMain,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowcaseSheet extends StatelessWidget {
  const _ShowcaseSheet({required this.ownerName});

  final String ownerName;

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.sizeOf(context).height * 0.75;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(HtmlDesignTokens.radiusXl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.96),
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
                    Expanded(
                      child: Text(
                        '📦 $ownerName 的藏品展柜',
                        style: const TextStyle(
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  physics: const BouncingScrollPhysics(),
                  children: <Widget>[
                    _SheetSectionTitle(left: 'Figures Collection (手办收集)', right: '45/50'),
                    const SizedBox(height: 12),
                    _CollectionGrid(
                      items: const <_CollectionItemData>[
                        _CollectionItemData('🧝‍♀️', 'Aether Wings', 'Legendary', false),
                        _CollectionItemData('🧜‍♀️', 'Ocean Song', 'Epic', false),
                        _CollectionItemData('🦸‍♀️', 'Neon Hero', 'Rare', true),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SheetSectionTitle(left: 'E-Pets Collection (E宠收集)', right: '12/20'),
                    const SizedBox(height: 12),
                    _CollectionGrid(
                      items: const <_CollectionItemData>[
                        _CollectionItemData('🐉', 'Nebula Drake', 'Epic', false),
                        _CollectionItemData('🦉', 'Night Watcher', 'Rare', true),
                      ],
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

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.accent,
              letterSpacing: 0.5,
              fontFamily: 'system-ui',
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}

class _CollectionItemData {
  const _CollectionItemData(this.emoji, this.name, this.rarity, this.rareStyle);

  final String emoji;
  final String name;
  final String rarity;
  final bool rareStyle;
}

class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({required this.items});

  final List<_CollectionItemData> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // 略增高单元格，避免 emoji + 双行名 + 稀有度标签在部分机型上亚像素溢出
      childAspectRatio: 0.72,
      children: items
          .map(
            (_CollectionItemData d) => _CollectionTile(data: d),
          )
          .toList(),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.data});

  final _CollectionItemData data;

  @override
  Widget build(BuildContext context) {
    final Color rarityBg = data.rareStyle
        ? HtmlDesignTokens.accent.withValues(alpha: 0.2)
        : HtmlDesignTokens.primary.withValues(alpha: 0.2);
    final Color rarityFg = data.rareStyle ? HtmlDesignTokens.accent : HtmlDesignTokens.primaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(data.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            data.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rarityBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.rarity,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: rarityFg,
                fontFamily: 'system-ui',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
