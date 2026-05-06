import 'package:flutter/foundation.dart';

/// 本地联调用的固定测试账号（符合 6～12 位字母数字规则）。
/// [showDevHelpers] 仅在调试构建下为 true，用于一键填入 / 启动时尝试注册。
abstract final class TestCredentials {
  TestCredentials._();

  static const String account = '111111';
  static const String password = '111111';
  static const String displayName = '测试账号';

  static bool get showDevHelpers => kDebugMode;
}
