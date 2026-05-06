import 'dart:math';

/// 可计入财富值的资产类型（与产品文档对齐）。
enum GachaAssetKind {
  figure,
  ePet,
  avatarFrame,
  cardFace,
  nameFlow,
}

/// 品质：金 Legendary / 紫 Epic / 蓝 Rare。
enum GachaQuality {
  legendary,
  epic,
  rare,
}

/// 补给舱卡池。
///
/// - **手办池**：可掉落 **手办**、**头像框**、**卡面**、**昵称流彩**、**E 点**、**无**（不会出现 E 宠）。
/// - **E 宠池**：可掉落 **E 宠**、**头像框**、**卡面**、**昵称流彩**、**E 点**、**无**（不会出现手办）。
///
/// 概率上：核心资产分支（5%）只出当前池对应核心类型；外观资产分支（25%）只在三种外观间均分。
enum GachaSupplyPool {
  figure,
  pet,
}

extension GachaSupplyPoolX on GachaSupplyPool {
  /// 界面说明用短句。
  String get dropTableHintZh => switch (this) {
        GachaSupplyPool.figure => '掉落：手办、头像框、卡面、昵称流彩、E点、无',
        GachaSupplyPool.pet => '掉落：E宠、头像框、卡面、昵称流彩、E点、无',
      };

  String get dropTableHintEn => switch (this) {
        GachaSupplyPool.figure =>
          'Drops: figure, avatar frame, card face, name flow, E-Points, none',
        GachaSupplyPool.pet =>
          'Drops: E-Pet, avatar frame, card face, name flow, E-Points, none',
      };
}

extension GachaQualityX on GachaQuality {
  String get displayZh => switch (this) {
        GachaQuality.legendary => '传说',
        GachaQuality.epic => '史诗',
        GachaQuality.rare => '稀有',
      };

  String get displayEn => switch (this) {
        GachaQuality.legendary => 'Legendary',
        GachaQuality.epic => 'Epic',
        GachaQuality.rare => 'Rare',
      };

  /// UI 与文档中的品质色标签。
  String get colorLabel => switch (this) {
        GachaQuality.legendary => '金色',
        GachaQuality.epic => '紫色',
        GachaQuality.rare => '蓝色',
      };

  String get colorLabelEn => switch (this) {
        GachaQuality.legendary => 'Gold',
        GachaQuality.epic => 'Purple',
        GachaQuality.rare => 'Blue',
      };
}

extension GachaAssetKindX on GachaAssetKind {
  String get displayZh => switch (this) {
        GachaAssetKind.figure => '手办',
        GachaAssetKind.ePet => 'E宠',
        GachaAssetKind.avatarFrame => '头像框',
        GachaAssetKind.cardFace => '卡面',
        GachaAssetKind.nameFlow => '昵称流彩',
      };

  String get displayEn => switch (this) {
        GachaAssetKind.figure => 'Figure',
        GachaAssetKind.ePet => 'E-Pet',
        GachaAssetKind.avatarFrame => 'Avatar frame',
        GachaAssetKind.cardFace => 'Card face',
        GachaAssetKind.nameFlow => 'Name flow',
      };

  /// 服务端写入 `user_assets.asset_type` 时建议使用的大写枚举名。
  String get wireType => switch (this) {
        GachaAssetKind.figure => 'FIGURE',
        GachaAssetKind.ePet => 'E_PET',
        GachaAssetKind.avatarFrame => 'AVATAR_FRAME',
        GachaAssetKind.cardFace => 'CARD_FACE',
        GachaAssetKind.nameFlow => 'NAME_FLOW',
      };
}

/// 图鉴条目：预览图约定在 `assets/pictures/`（手办/E宠/框/流彩按前缀，卡面前缀 `card`）。
class GachaCatalogEntry {
  const GachaCatalogEntry({
    required this.id,
    required this.kind,
    required this.quality,
    required this.name,
    required this.previewAsset,
    this.subtitle,
  });

  final String id;
  final GachaAssetKind kind;
  final GachaQuality quality;
  final String name;
  final String previewAsset;
  final String? subtitle;
}

/// 单次抽取的解析结果（写入 `user_assets` 或仅展示）。
sealed class GachaRollOutcome {}

class GachaAssetOutcome extends GachaRollOutcome {
  GachaAssetOutcome({required this.entry, required this.alreadyOwned});

  final GachaCatalogEntry entry;
  final bool alreadyOwned;
}

class GachaEPointsOutcome extends GachaRollOutcome {
  GachaEPointsOutcome(this.amount);
  final int amount;
}

class GachaNullOutcome extends GachaRollOutcome {
  GachaNullOutcome();
}

/// 财富值：背包内已拥有资产的 `wealthContribution` 之和。
int wealthContribution(GachaCatalogEntry e) {
  final core = e.kind == GachaAssetKind.figure || e.kind == GachaAssetKind.ePet;
  switch (e.quality) {
    case GachaQuality.legendary:
      return core ? 10000 : 5000;
    case GachaQuality.epic:
      return core ? 2500 : 1200;
    case GachaQuality.rare:
      return core ? 600 : 300;
  }
}

int totalWealthForOwned(Iterable<GachaCatalogEntry> owned) {
  var sum = 0;
  for (final e in owned) {
    sum += wealthContribution(e);
  }
  return sum;
}

/// 双层概率抽卡（与产品文档一致）。十连 = 独立调用 10 次。
///
/// [GachaSupplyPool.figure] 与 [GachaSupplyPool.pet] 仅区分 **5% 核心资产** 是手办还是 E 宠；
/// **25% 外观**、**60% E 点**、**10% 无** 两池相同，且外观只在头像框 / 卡面 / 昵称流彩中抽取。
abstract final class GachaEngine {
  static const double pCore = 0.05;
  static const double pAppearance = 0.25;
  static const double pEPoints = 0.60;
  static const double pNull = 0.10;

  static const double pGold = 0.02;
  static const double pPurple = 0.18;

  /// 商城兑换：100 E点 = 1 张抽卡盲盒券。
  static const int ePointsPerBlindBoxTicket = 100;

  /// 补给舱单抽 / 十连消耗的盲盒券张数（手办池与 E 宠池相同）。
  static const int pullTicketsSingle = 1;
  static const int pullTicketsTen = 10;

  static GachaQuality rollQuality(Random random) {
    final t = random.nextDouble();
    if (t < pGold) return GachaQuality.legendary;
    if (t < pGold + pPurple) return GachaQuality.epic;
    return GachaQuality.rare;
  }

  /// E 点奖励箱： [20–50: 70%], [80–120: 25%], [200–500: 5%]
  static int rollEPointsPack(Random random) {
    final t = random.nextDouble();
    if (t < 0.70) {
      return 20 + random.nextInt(31);
    }
    if (t < 0.95) {
      return 80 + random.nextInt(41);
    }
    return 200 + random.nextInt(301);
  }

  static GachaCatalogEntry? _pick(
    Random random,
    GachaAssetKind kind,
    GachaQuality quality,
  ) {
    final pool = gachaCatalog.where((e) => e.kind == kind && e.quality == quality).toList();
    if (pool.isEmpty) return null;
    return pool[random.nextInt(pool.length)];
  }

  static GachaCatalogEntry? _pickAppearance(Random random, GachaQuality quality) {
    final sub = random.nextInt(3);
    final kind = switch (sub) {
      0 => GachaAssetKind.avatarFrame,
      1 => GachaAssetKind.cardFace,
      _ => GachaAssetKind.nameFlow,
    };
    return _pick(random, kind, quality);
  }

  /// [ownedIds]：用户已拥有的资产 `id`；用于展示「已拥有」（服务端应基于 `user_assets` 判定）。
  static GachaRollOutcome roll({
    required Random random,
    required GachaSupplyPool pool,
    required Set<String> ownedIds,
  }) {
    final c = random.nextDouble();
    if (c < pCore) {
      final q = rollQuality(random);
      final kind = pool == GachaSupplyPool.figure ? GachaAssetKind.figure : GachaAssetKind.ePet;
      final entry = _pick(random, kind, q);
      if (entry == null) {
        return GachaNullOutcome();
      }
      return GachaAssetOutcome(entry: entry, alreadyOwned: ownedIds.contains(entry.id));
    }
    if (c < pCore + pAppearance) {
      final q = rollQuality(random);
      final entry = _pickAppearance(random, q);
      if (entry == null) {
        return GachaNullOutcome();
      }
      return GachaAssetOutcome(entry: entry, alreadyOwned: ownedIds.contains(entry.id));
    }
    if (c < pCore + pAppearance + pEPoints) {
      return GachaEPointsOutcome(rollEPointsPack(random));
    }
    return GachaNullOutcome();
  }
}

/// 全量图鉴：手办10、E宠10、头像框10、卡面15、昵称流彩10；品质分布见产品表。
///
/// 预览图在 `assets/pictures/`：手办前缀 **model**，E 宠前缀 **Epet**，卡面前缀 **card**。
/// **头像框 / 昵称流彩** 在客户端用程序绘制预览（示例头像+框、示例昵称+流彩渐变），`frame_*.png` / `flow_*.png` 可仅作运营导出或留空。
final List<GachaCatalogEntry> gachaCatalog = <GachaCatalogEntry>[
  // —— 手办 10：金2 紫3 蓝5 ——
  const GachaCatalogEntry(
    id: 'figure_01',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.legendary,
    name: '星穹歌姬 Eunoa',
    previewAsset: 'assets/pictures/model_01.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_02',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.legendary,
    name: '缄墨藏书使',
    previewAsset: 'assets/pictures/model_02.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_03',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.epic,
    name: '量子写手办',
    previewAsset: 'assets/pictures/model_03.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_04',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.epic,
    name: '霓虹词姬',
    previewAsset: 'assets/pictures/model_04.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_05',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.epic,
    name: '像素谬斯',
    previewAsset: 'assets/pictures/model_05.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_06',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.rare,
    name: '玻璃展台·初版',
    previewAsset: 'assets/pictures/model_06.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_07',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.rare,
    name: '迷你书签精',
    previewAsset: 'assets/pictures/model_07.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_08',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.rare,
    name: '咖啡杯学者',
    previewAsset: 'assets/pictures/model_08.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_09',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.rare,
    name: '便签小妖',
    previewAsset: 'assets/pictures/model_09.png',
  ),
  const GachaCatalogEntry(
    id: 'figure_10',
    kind: GachaAssetKind.figure,
    quality: GachaQuality.rare,
    name: '迟到闹钟君',
    previewAsset: 'assets/pictures/model_10.png',
  ),

  // —— E宠 10：金2 紫3 蓝5 ——
  const GachaCatalogEntry(
    id: 'epet_01',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.legendary,
    name: '辉羽星狐',
    previewAsset: 'assets/pictures/Epet_01.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_02',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.legendary,
    name: '溯光龙猫',
    previewAsset: 'assets/pictures/Epet_02.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_03',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.epic,
    name: '霓虹兔',
    previewAsset: 'assets/pictures/Epet_03.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_04',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.epic,
    name: '流雾水母',
    previewAsset: 'assets/pictures/Epet_04.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_05',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.epic,
    name: '数据啄木鸟',
    previewAsset: 'assets/pictures/Epet_05.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_06',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.rare,
    name: '瞌睡仓鼠',
    previewAsset: 'assets/pictures/Epet_06.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_07',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.rare,
    name: '蹦迪企鹅',
    previewAsset: 'assets/pictures/Epet_07.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_08',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.rare,
    name: '白板喵',
    previewAsset: 'assets/pictures/Epet_08.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_09',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.rare,
    name: '快门柴',
    previewAsset: 'assets/pictures/Epet_09.png',
  ),
  const GachaCatalogEntry(
    id: 'epet_10',
    kind: GachaAssetKind.ePet,
    quality: GachaQuality.rare,
    name: '回声鹦',
    previewAsset: 'assets/pictures/Epet_10.png',
  ),

  // —— 头像框 10：金2 紫3 蓝5 ——
  const GachaCatalogEntry(
    id: 'frame_01',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.legendary,
    name: '日冕圣环',
    subtitle: '三层金质光晕 + 扫光外环 + 内缘高光',
    previewAsset: 'assets/pictures/frame_01.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_02',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.legendary,
    name: '霜辉月环',
    subtitle: '银白扫光圆环 + 弦月微饰',
    previewAsset: 'assets/pictures/frame_02.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_03',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.epic,
    name: '极光棱框',
    subtitle: '紫青折射渐变环 + 双色外晕',
    previewAsset: 'assets/pictures/frame_03.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_04',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.epic,
    name: '蔷薇圆窗',
    subtitle: '圆形放射花窗纹 + 紫粉弧段',
    previewAsset: 'assets/pictures/frame_04.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_05',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.epic,
    name: '电脉圆环',
    subtitle: '正圆分段青光电弧 + 光晕',
    previewAsset: 'assets/pictures/frame_05.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_06',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.rare,
    name: '浅蓝细线',
    subtitle: '冰蓝双环圆框 + 柔光',
    previewAsset: 'assets/pictures/frame_06.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_07',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.rare,
    name: '磨砂晶环',
    subtitle: '磨砂玻璃厚圆边 + 内缘高光',
    previewAsset: 'assets/pictures/frame_07.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_08',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.rare,
    name: '燕麦柔环',
    subtitle: '暖米白双层正圆 + 软阴影',
    previewAsset: 'assets/pictures/frame_08.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_09',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.rare,
    name: '铂银双环',
    subtitle: '渐变金属质感双环',
    previewAsset: 'assets/pictures/frame_09.png',
  ),
  const GachaCatalogEntry(
    id: 'frame_10',
    kind: GachaAssetKind.avatarFrame,
    quality: GachaQuality.rare,
    name: '雾灰圆环',
    subtitle: '双层低饱和雾面正圆',
    previewAsset: 'assets/pictures/frame_10.png',
  ),

  // —— 卡面 15：金3 紫5 蓝7（预览前缀 card）——
  const GachaCatalogEntry(
    id: 'card_01',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.legendary,
    name: '终焉星图',
    previewAsset: 'assets/pictures/card_01.png',
  ),
  const GachaCatalogEntry(
    id: 'card_02',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.legendary,
    name: '熵减圣殿',
    previewAsset: 'assets/pictures/card_02.png',
  ),
  const GachaCatalogEntry(
    id: 'card_03',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.legendary,
    name: '零号协议',
    previewAsset: 'assets/pictures/card_03.png',
  ),
  const GachaCatalogEntry(
    id: 'card_04',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.epic,
    name: '雨港霓虹',
    previewAsset: 'assets/pictures/card_04.png',
  ),
  const GachaCatalogEntry(
    id: 'card_05',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.epic,
    name: '深空信标',
    previewAsset: 'assets/pictures/card_05.png',
  ),
  const GachaCatalogEntry(
    id: 'card_06',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.epic,
    name: '月台回声',
    previewAsset: 'assets/pictures/card_06.png',
  ),
  const GachaCatalogEntry(
    id: 'card_07',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.epic,
    name: '砂时计庭',
    previewAsset: 'assets/pictures/card_07.png',
  ),
  const GachaCatalogEntry(
    id: 'card_08',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.epic,
    name: '青焰编年史',
    previewAsset: 'assets/pictures/card_08.png',
  ),
  const GachaCatalogEntry(
    id: 'card_09',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '晨读窗台',
    previewAsset: 'assets/pictures/card_09.png',
  ),
  const GachaCatalogEntry(
    id: 'card_10',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '薄荷公式',
    previewAsset: 'assets/pictures/card_10.png',
  ),
  const GachaCatalogEntry(
    id: 'card_11',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '云隙光',
    previewAsset: 'assets/pictures/card_11.png',
  ),
  const GachaCatalogEntry(
    id: 'card_12',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '旧磁带',
    previewAsset: 'assets/pictures/card_12.png',
  ),
  const GachaCatalogEntry(
    id: 'card_13',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '盐系海岸',
    previewAsset: 'assets/pictures/card_13.png',
  ),
  const GachaCatalogEntry(
    id: 'card_14',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '糖纸折光',
    previewAsset: 'assets/pictures/card_14.png',
  ),
  const GachaCatalogEntry(
    id: 'card_15',
    kind: GachaAssetKind.cardFace,
    quality: GachaQuality.rare,
    name: '晚风站台',
    previewAsset: 'assets/pictures/card_15.png',
  ),

  // —— 昵称流彩 10：金2 紫3 蓝5（渐变语义，UI 可用 ShaderMask 实现）——
  const GachaCatalogEntry(
    id: 'flow_01',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.legendary,
    name: '熔金晨曦',
    subtitle: 'FFD700 → FF6B35',
    previewAsset: 'assets/pictures/flow_01.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_02',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.legendary,
    name: '星海紫雾',
    subtitle: '7C3AED → 22D3EE',
    previewAsset: 'assets/pictures/flow_02.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_03',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.epic,
    name: '薰衣草雾',
    subtitle: 'A78BFA → E9D5FF',
    previewAsset: 'assets/pictures/flow_03.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_04',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.epic,
    name: '薄荷电涌',
    subtitle: '2DD4BF → 38BDF8',
    previewAsset: 'assets/pictures/flow_04.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_05',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.epic,
    name: '薄暮珊瑚',
    subtitle: 'FB7185 → FBBF24',
    previewAsset: 'assets/pictures/flow_05.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_06',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.rare,
    name: '冰川蓝',
    subtitle: '60A5FA → 93C5FD',
    previewAsset: 'assets/pictures/flow_06.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_07',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.rare,
    name: '苔绿呼吸',
    subtitle: '34D399 → 6EE7B7',
    previewAsset: 'assets/pictures/flow_07.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_08',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.rare,
    name: '银灰刻度',
    subtitle: '94A3B8 → CBD5E1',
    previewAsset: 'assets/pictures/flow_08.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_09',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.rare,
    name: '淡杏糖霜',
    subtitle: 'FDE68A → FBBF24',
    previewAsset: 'assets/pictures/flow_09.png',
  ),
  const GachaCatalogEntry(
    id: 'flow_10',
    kind: GachaAssetKind.nameFlow,
    quality: GachaQuality.rare,
    name: '靛夜深空',
    subtitle: '312E81 → 6366F1',
    previewAsset: 'assets/pictures/flow_10.png',
  ),
];

GachaCatalogEntry? catalogEntryById(String id) {
  for (final e in gachaCatalog) {
    if (e.id == id) return e;
  }
  return null;
}

/// 直购商城：头像框 / 卡面 / 昵称流彩 的 E 点标价（与品质挂钩）。
int directShopPriceEPoints(GachaCatalogEntry e) {
  switch (e.quality) {
    case GachaQuality.legendary:
      return 5200;
    case GachaQuality.epic:
      return 2400;
    case GachaQuality.rare:
      return 680;
  }
}

/// 可在直购商城购买的条目（与抽卡图鉴一致）。
Iterable<GachaCatalogEntry> get directShopCatalogEntries => gachaCatalog.where(
      (GachaCatalogEntry e) =>
          e.kind == GachaAssetKind.avatarFrame ||
          e.kind == GachaAssetKind.cardFace ||
          e.kind == GachaAssetKind.nameFlow,
    );
