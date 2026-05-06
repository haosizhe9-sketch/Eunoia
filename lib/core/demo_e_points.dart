import 'package:flutter/foundation.dart';

/// 商城 E 点与补给舱共用；与账号注册赠送逻辑一致（本地 JSON，默认 1000 E 点起）。
final ValueNotifier<int> demoEPointsNotifier = ValueNotifier<int>(0);

/// 抽卡盲盒券：补给舱单抽 / 十连消耗；在商城用 E 点兑换（100 E点/张，与 [GachaEngine] 常量一致）。
final ValueNotifier<int> demoGachaTicketsNotifier = ValueNotifier<int>(0);
