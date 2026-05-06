import '../services/app_data_service.dart';

/// 将 Auth UUID 压成短串，用于默认昵称「烤鸭xxxx」等展示。
String shortUidForDisplay(String userId) {
  final String s = userId.replaceAll('-', '');
  if (s.length >= 8) {
    return s.substring(0, 8);
  }
  if (s.isEmpty) {
    return '00000000';
  }
  return s.padRight(8, '0');
}

/// 同步可用的展示名：优先 metadata，否则 `烤鸭` + 短 UID（与注册未填昵称规则一致）。
String syncDisplayNameOrRoastDuckUid(User user) {
  final Object? meta = user.userMetadata['display_name'];
  if (meta is String && meta.trim().isNotEmpty) {
    return meta.trim();
  }
  return '烤鸭${shortUidForDisplay(user.id)}';
}
