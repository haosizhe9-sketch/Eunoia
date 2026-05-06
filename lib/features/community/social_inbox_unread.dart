import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/community_social_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart';
import 'community_social_repository.dart';

/// Social 顶栏消息按钮是否显示未读角标（新号默认无未读）。
final ValueNotifier<bool> socialInboxUnreadNotifier = ValueNotifier<bool>(false);

/// 根据服务端未读通知与待处理好友请求刷新角标（登录态 / 会话变化时调用）。
Future<void> refreshSocialInboxUnreadBadge(WidgetRef ref) async {
  final AppDataService store = ref.read(appDataServiceProvider);
  if (!store.isBackendAvailable || store.currentUser == null) {
    socialInboxUnreadNotifier.value = false;
    return;
  }
  final CommunitySocialRepository repo = ref.read(communitySocialRepositoryProvider);
  final int unread = await repo.countUnreadNotifications();
  if (unread > 0) {
    socialInboxUnreadNotifier.value = true;
    return;
  }
  if ((await repo.listIncomingFriendRequests()).isNotEmpty) {
    socialInboxUnreadNotifier.value = true;
    return;
  }
  socialInboxUnreadNotifier.value = false;
}
