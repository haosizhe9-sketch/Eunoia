import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 底部四 Tab 根路径每次变为「当前完整路由」时递增对应分支计数，
/// 供各主界面把自身滚动条拉回顶部。
class ShellBranchActivationController extends StateNotifier<Map<int, int>> {
  ShellBranchActivationController()
      : super(<int, int>{for (int i = 0; i < 4; i++) i: 0});

  void bump(int branchIndex) {
    if (branchIndex < 0 || branchIndex > 3) {
      return;
    }
    final Map<int, int> m = Map<int, int>.from(state);
    m[branchIndex] = (m[branchIndex] ?? 0) + 1;
    state = m;
  }
}

final StateNotifierProvider<ShellBranchActivationController, Map<int, int>>
    shellBranchActivationProvider =
    StateNotifierProvider<ShellBranchActivationController, Map<int, int>>(
  (Ref ref) => ShellBranchActivationController(),
);

/// 仅当 [path] 等于某一 shell 分支根路径（无子页后缀）时返回分支索引 0–3。
int? shellRootBranchIndexForPath(String path) {
  switch (path) {
    case '/practice':
      return 0;
    case '/community':
      return 1;
    case '/store':
      return 2;
    case '/profile':
      return 3;
    default:
      return null;
  }
}
