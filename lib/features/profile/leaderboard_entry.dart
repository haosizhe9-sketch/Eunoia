import 'package:flutter/material.dart';

/// 档案页 3D 手办 glb：`model_00` 为无库存默认；`model_01`～`model_10` 对应榜内第 1～10 名（便于测试）。
abstract final class ShowcaseGlbAssets {
  ShowcaseGlbAssets._();

  static const String defaultPath = 'assets/models/model_00.glb';
}

/// 领奖台与分数展示用色（与 `rank.html` 一致）。
abstract final class LeaderboardTokens {
  LeaderboardTokens._();

  static const Color goldGlow = Color(0xFFFBBF24);
  static const Color silver = Color(0xFF9CA3AF);
  static const Color bronze = Color(0xFFD97706);
}

/// 与根目录 `rank.html` 演示一致的排行榜条目（后续可接服务端排行）。
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.uid,
    required this.emoji,
    required this.score,
    required this.isTowerBoard,
    this.avatarGradient,
  });

  final int rank;
  final String name;
  final String uid;
  final String emoji;
  final int score;
  final bool isTowerBoard;
  final List<Color>? avatarGradient;

  /// 游客未登录时底部栏占位行（[uid] 为 [kGuestLeaderboardUid]）。
  static const String kGuestLeaderboardUid = '__guest__';

  bool get isGuestSelfRow => uid == kGuestLeaderboardUid;

  /// 名次 1～10 → `model_01.glb` … `model_10.glb`；其余（含自己 42/128 名等）→ [ShowcaseGlbAssets.defaultPath]。
  String get showcaseGlbAssetPath {
    if (rank >= 1 && rank <= 10) {
      return 'assets/models/model_${rank.toString().padLeft(2, '0')}.glb';
    }
    return ShowcaseGlbAssets.defaultPath;
  }

  /// 仅名次 1～10 展示 E 宠 3D；无默认模型，`null` 时不渲染 E 宠位。
  String? get epetGlbAssetPath {
    if (rank >= 1 && rank <= 10) {
      return 'assets/models/epet_${rank.toString().padLeft(2, '0')}.glb';
    }
    return null;
  }

  String get scoreDisplay {
    if (isTowerBoard) return '$score 层';
    return formatLeaderboardWealth(score);
  }
}

String formatLeaderboardWealth(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
