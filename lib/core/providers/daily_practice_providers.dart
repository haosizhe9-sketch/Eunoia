import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_data_service.dart' show DailyPracticeTodayView, User;
import 'auth_providers.dart';
import 'service_providers.dart';

/// 今日听力 / 阅读 / 写作任务进度与估分（日历日切换时由服务端视图重置）。
final dailyPracticeTodayProvider =
    FutureProvider.autoDispose<DailyPracticeTodayView?>((Ref ref) async {
  ref.watch(profileRevisionProvider);
  if (ref.watch(devMockLoginProvider)) {
    return ref.read(appDataServiceProvider).fetchDailyPracticeTodayView();
  }
  final User? u = ref.watch(appDataServiceProvider).currentUser ??
      ref.watch(authUserProvider).maybeWhen(data: (User? x) => x, orElse: () => null);
  if (u == null) {
    return null;
  }
  return ref.read(appDataServiceProvider).fetchDailyPracticeTodayView();
});
