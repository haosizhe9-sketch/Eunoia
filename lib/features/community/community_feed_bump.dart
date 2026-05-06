import 'package:flutter/foundation.dart';

/// 广场动态会话有变更时递增，供「我的发布」等页刷新列表。
final ValueNotifier<int> communityFeedBumpNotifier = ValueNotifier<int>(0);
