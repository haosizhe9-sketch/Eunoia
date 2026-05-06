import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/community/community_social_repository.dart';
import 'service_providers.dart';

final communitySocialRepositoryProvider = Provider<CommunitySocialRepository>((Ref ref) {
  return CommunitySocialRepository(ref.watch(appDataServiceProvider));
});
