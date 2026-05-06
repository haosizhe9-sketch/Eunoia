import 'package:flutter/foundation.dart' show kIsWeb;

/// 匿名语聊信令与匹配服务（Socket.IO）基址。
///
/// - **未传 [VOICE_SIGNAL_URL] 时**：在 **Web** 下自动使用 [Uri.base.origin]（与当前页面同协议/同域），便于 Nginx 将 `/socket.io` 反代到本机 3847，避免 HTTPS 页面连接 `http://ip:3847` 被浏览器拦截。
/// - **移动端/桌面**：未配置时默认 `http://127.0.0.1:3847`（本机联调）。
///
/// 构建时仍可覆盖：`--dart-define=VOICE_SIGNAL_URL=https://www.example.com`
abstract final class VoiceMatchConfig {
  VoiceMatchConfig._();

  /// 编译时注入的原始值（可能为空，表示走 [resolveSignalUrl] 的自动策略）。
  static const String _envSignalUrl = String.fromEnvironment(
    'VOICE_SIGNAL_URL',
    defaultValue: '',
  );

  /// 实际用于 Socket.IO 连接的基址（无尾缀 `/`）。
  static String resolveSignalUrl() {
    final String fromEnv = _envSignalUrl.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'http://127.0.0.1:3847';
  }
}
