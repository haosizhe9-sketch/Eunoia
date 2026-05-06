import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_engine_service.dart';
import '../services/news_mock_ai_service.dart';
import '../services/app_data_service.dart';

final appDataServiceProvider = Provider<AppDataService>(
  (Ref ref) => AppDataService(),
);

final aiEngineServiceProvider = Provider<AIEngineService>(
  (Ref ref) => AIEngineService(),
);

final newsMockAiServiceProvider = Provider<NewsMockAIService>(
  (Ref ref) => NewsMockAIService(),
);

/// 每日练习任务卡片刷新（提交批改后 +1）。
final practiceDailyTickProvider = StateProvider<int>((Ref ref) => 0);
