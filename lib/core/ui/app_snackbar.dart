import 'package:flutter/material.dart';

/// 挂在 [MaterialApp] 上，以便 [showAppTopSnackBarAfterPop] 在关闭子路由后仍能显示提示。
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 在 [context.pop] 等关闭当前页**之后**显示顶部 SnackBar（下一帧执行，避免提示挂在已移除的页面上）。
void showAppTopSnackBarAfterPop(
  Widget content, {
  Duration? duration,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final BuildContext? ctx = appScaffoldMessengerKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      return;
    }
    showAppTopSnackBar(ctx, content, duration: duration);
  });
}

/// 在屏幕**上方**显示 SnackBar，避免与底部 Tab 导航重叠。
void showAppTopSnackBar(
  BuildContext context,
  Widget content, {
  Duration? duration,
}) {
  final MediaQueryData mq = MediaQuery.of(context);
  final double top = mq.viewPadding.top + 8;
  // 预留足够高度以容纳单行 / 双行文案（与 [SnackBar] 默认 padding 一致）
  const double barSlotHeight = 96;
  final double bottom = mq.size.height - top - barSlotHeight;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: content,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(left: 16, right: 16, top: top, bottom: bottom),
      duration: duration ?? const Duration(seconds: 2),
    ),
  );
}
