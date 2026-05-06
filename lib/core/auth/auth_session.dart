import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/service_providers.dart';
import '../services/app_data_service.dart';

User? readAuthUser(WidgetRef ref) {
  return ref.watch(appDataServiceProvider).currentUser ??
      ref.watch(authUserProvider).maybeWhen(data: (User? u) => u, orElse: () => null);
}

bool isLoggedIn(WidgetRef ref) {
  if (ref.watch(devMockLoginProvider)) {
    return true;
  }
  return readAuthUser(ref) != null;
}

void pushLoginPage(BuildContext context) {
  context.push('/profile/auth');
}
