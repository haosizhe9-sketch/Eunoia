import 'package:flutter/foundation.dart';

import 'gacha/wealth_gacha.dart';

/// 与 [ShowcaseGlbAssets.defaultPath] 一致（避免 core 依赖 profile）。
const String kDefaultShowcaseFigureGlb = 'assets/models/model_00.glb';

/// 演示用背包：与补给舱、直购共用（后续可接服务端资产表）。
final ValueNotifier<Set<String>> demoOwnedAssetIdsNotifier = ValueNotifier<Set<String>>(<String>{});

/// 主页当前展示的藏品 ID（`figure_01`、`epet_03`、`frame_02`、`card_05`、`flow_01` 等）。
@immutable
class DemoProfileEquip {
  const DemoProfileEquip({
    this.equippedFigureId,
    this.equippedEpetId,
    this.equippedFrameId,
    this.equippedCardFaceId,
    this.equippedNameFlowId,
  });

  final String? equippedFigureId;
  final String? equippedEpetId;
  final String? equippedFrameId;
  final String? equippedCardFaceId;
  final String? equippedNameFlowId;
}

void _setEquip(DemoProfileEquip next) {
  demoProfileEquipNotifier.value = next;
}

void demoEquipSetFigure(String id) {
  final e = demoProfileEquipNotifier.value;
  _setEquip(DemoProfileEquip(
    equippedFigureId: id,
    equippedEpetId: e.equippedEpetId,
    equippedFrameId: e.equippedFrameId,
    equippedCardFaceId: e.equippedCardFaceId,
    equippedNameFlowId: e.equippedNameFlowId,
  ));
}

void demoEquipSetEpet(String id) {
  final e = demoProfileEquipNotifier.value;
  _setEquip(DemoProfileEquip(
    equippedFigureId: e.equippedFigureId,
    equippedEpetId: id,
    equippedFrameId: e.equippedFrameId,
    equippedCardFaceId: e.equippedCardFaceId,
    equippedNameFlowId: e.equippedNameFlowId,
  ));
}

void demoEquipSetFrame(String id) {
  final e = demoProfileEquipNotifier.value;
  _setEquip(DemoProfileEquip(
    equippedFigureId: e.equippedFigureId,
    equippedEpetId: e.equippedEpetId,
    equippedFrameId: id,
    equippedCardFaceId: e.equippedCardFaceId,
    equippedNameFlowId: e.equippedNameFlowId,
  ));
}

void demoEquipSetCardFace(String id) {
  final e = demoProfileEquipNotifier.value;
  _setEquip(DemoProfileEquip(
    equippedFigureId: e.equippedFigureId,
    equippedEpetId: e.equippedEpetId,
    equippedFrameId: e.equippedFrameId,
    equippedCardFaceId: id,
    equippedNameFlowId: e.equippedNameFlowId,
  ));
}

void demoEquipSetNameFlow(String id) {
  final e = demoProfileEquipNotifier.value;
  _setEquip(DemoProfileEquip(
    equippedFigureId: e.equippedFigureId,
    equippedEpetId: e.equippedEpetId,
    equippedFrameId: e.equippedFrameId,
    equippedCardFaceId: e.equippedCardFaceId,
    equippedNameFlowId: id,
  ));
}

final ValueNotifier<DemoProfileEquip> demoProfileEquipNotifier =
    ValueNotifier<DemoProfileEquip>(const DemoProfileEquip());

void demoInventoryAddOwned(String assetId) {
  final next = Set<String>.from(demoOwnedAssetIdsNotifier.value)..add(assetId);
  demoOwnedAssetIdsNotifier.value = next;
}

void demoInventoryAddAllOwned(Iterable<String> ids) {
  final next = Set<String>.from(demoOwnedAssetIdsNotifier.value)..addAll(ids);
  demoOwnedAssetIdsNotifier.value = next;
}

/// 手办图鉴 ID → `assets/models/model_XX.glb`
String demoFigureGlbPath(String? figureCatalogId) {
  if (figureCatalogId == null || !figureCatalogId.startsWith('figure_')) {
    return kDefaultShowcaseFigureGlb;
  }
  final tail = figureCatalogId.substring('figure_'.length);
  final n = int.tryParse(tail);
  if (n == null || n < 1 || n > 10) {
    return kDefaultShowcaseFigureGlb;
  }
  return 'assets/models/model_${n.toString().padLeft(2, '0')}.glb';
}

/// E 宠图鉴 ID → `assets/models/epet_XX.glb`
String? demoEpetGlbPath(String? epetCatalogId) {
  if (epetCatalogId == null || !epetCatalogId.startsWith('epet_')) {
    return null;
  }
  final tail = epetCatalogId.substring('epet_'.length);
  final n = int.tryParse(tail);
  if (n == null || n < 1 || n > 10) {
    return null;
  }
  return 'assets/models/epet_${n.toString().padLeft(2, '0')}.glb';
}

int demoTotalWealthFromOwned() {
  var sum = 0;
  for (final id in demoOwnedAssetIdsNotifier.value) {
    final e = catalogEntryById(id);
    if (e != null) {
      sum += wealthContribution(e);
    }
  }
  return sum;
}
