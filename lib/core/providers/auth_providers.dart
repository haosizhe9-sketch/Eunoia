import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_data_service.dart';

import 'service_providers.dart';

/// 当前登录用户；未初始化 [AppDataService] 或未登录时为 `null`。
final authUserProvider = StreamProvider<User?>((Ref ref) {
  return ref.watch(appDataServiceProvider).watchAuthUser();
});

/// Debug 下可使用测试账号「本地会话」（仅存本机）。
final devMockLoginProvider = StateProvider<bool>((Ref ref) => false);

/// 本地调试会话下编辑的昵称与个性签名（未持久化前仅存内存）。
final devMockProfileProvider = StateProvider<DevMockProfile?>((Ref ref) => null);

/// 个人资料从服务端或本地刷新（保存昵称/签名后递增以重载 UI）。
final profileRevisionProvider = StateProvider<int>((Ref ref) => 0);

class DevMockProfile {
  const DevMockProfile({required this.displayName, required this.bio});

  final String displayName;
  final String bio;
}
