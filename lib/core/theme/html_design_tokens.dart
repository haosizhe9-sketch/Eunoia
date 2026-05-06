import 'package:flutter/material.dart';

/// Values mirrored from root `index.html` (:root + inline styles).
abstract final class HtmlDesignTokens {
  HtmlDesignTokens._();

  static const Color bgDeep = Color(0xFF130B2B);
  static const Color chromeBackdrop = Color(0xFF2D2A3B);
  static const Color primary = Color(0xFF7C3AED);
  /// `--primary-light`
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color accent = Color(0xFF2DD4BF);
  static const Color accentDeep = Color(0xFF14B8A6);
  static const Color gachaSubBg = Color(0xFF0D071C);
  static const Color textMain = Color(0xFFFFFFFF);
  static const Color textSub = Color(0xFF9CA3AF);

  static Color get glassCard => Colors.white.withValues(alpha: 0.03);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.08);

  /// `linear-gradient(145deg, #1A103C 0%, #0D071C 100%)`
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF1A103C),
      Color(0xFF0D071C),
    ],
  );

  static const double radiusXl = 32;
  static const double radiusLg = 24;
  static const double radiusMd = 16;

  static Color get navBarFill => const Color(0xFF1A103C).withValues(alpha: 0.6);
  static Color get navBarBorder => Colors.white.withValues(alpha: 0.1);

  static const double phoneWidth = 375;
  static const double phoneHeight = 812;

  /// 主 Tab 壳与 Web 手机框内「刘海下」首行内容的统一顶距（略大于原 55，避免顶栏贴边）。
  static const double contentTopInset = 58;

  /// 与 [MainShell] 底部栏 `Positioned(bottom: 30)` 一致：内容区与屏边留白，顶/底对称。
  static const double shellEdgeGap = 30;

  /// Web 手机框底部安全区（与常见 Home 指示条视觉对齐）。
  static const double phoneSimulatedBottomInset = 28;

  /// 子页顶栏：返回 + 标题（左右 12）。
  static const EdgeInsets subpageAppBarPadding = EdgeInsets.fromLTRB(12, 12, 12, 8);

  /// 子页顶栏：左右 20（商城 / 抽卡等）。
  static const EdgeInsets stackedPageAppBarPadding = EdgeInsets.fromLTRB(20, 14, 20, 8);

  /// 子页顶栏：左右较窄（如每日任务入口）。
  static const EdgeInsets compactSubpageAppBarPadding = EdgeInsets.fromLTRB(8, 12, 16, 8);

  /// 群聊等左右 8 的顶栏。
  static const EdgeInsets narrowSubpageAppBarPadding = EdgeInsets.fromLTRB(8, 12, 8, 12);
}
