import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:record/record.dart';

import '../i18n/app_strings.dart';

/// Web 上麦克风失败的细分原因（用于文案）。
enum MicPermissionFailureKind {
  /// 非安全上下文（远程需 HTTPS；本地仅 localhost / 127.0.0.1 等）。
  secureContextRequired,

  /// 用户拒绝、关闭授权条，或未授予权限。
  permissionDenied,

  /// 未找到音频输入设备。
  deviceNotFound,

  /// 其它（附 [technicalDetail]）。
  unknown,
}

/// [resolveRecorderMicPermission] 的返回值。
final class MicPermissionResult {
  const MicPermissionResult._({
    required this.isGranted,
    this.failureKind,
    this.technicalDetail,
  });

  const MicPermissionResult.granted()
      : this._(isGranted: true, failureKind: null, technicalDetail: null);

  const MicPermissionResult.failure(
    MicPermissionFailureKind kind, [
    String? technicalDetail,
  ]) : this._(
          isGranted: false,
          failureKind: kind,
          technicalDetail: technicalDetail,
        );

  final bool isGranted;
  final MicPermissionFailureKind? failureKind;
  final String? technicalDetail;
}

bool _webInSecureAudioContext() {
  final Uri u = Uri.base;
  if (u.scheme == 'https') {
    return true;
  }
  final String host = u.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '[::1]';
}

MicPermissionResult _classifyWebException(Object e) {
  final String msg = e.toString();
  final String lower = msg.toLowerCase();
  if (lower.contains('notallowederror') ||
      lower.contains('permission denied') ||
      lower.contains('notallowed')) {
    return MicPermissionResult.failure(MicPermissionFailureKind.permissionDenied);
  }
  if (lower.contains('notfounderror') ||
      (lower.contains('notfound') && lower.contains('microphone'))) {
    return MicPermissionResult.failure(MicPermissionFailureKind.deviceNotFound);
  }
  if (lower.contains('securityerror') ||
      lower.contains('only secure origins') ||
      lower.contains('secure context')) {
    return MicPermissionResult.failure(MicPermissionFailureKind.secureContextRequired);
  }
  return MicPermissionResult.failure(MicPermissionFailureKind.unknown, msg);
}

/// 请求麦克风并返回细分结果；Web 上会先判断安全上下文。
///
/// Web：优先调用 [AudioRecorder.hasPermission](request: true)。若插件未注册
/// `hasPermission`（[MissingPluginException]），则视为通过并由后续 [AudioRecorder.start]
/// 经浏览器 getUserMedia 触发授权。
Future<MicPermissionResult> resolveRecorderMicPermission(AudioRecorder recorder) async {
  if (kIsWeb && !_webInSecureAudioContext()) {
    return MicPermissionResult.failure(MicPermissionFailureKind.secureContextRequired);
  }
  try {
    final bool ok = await recorder.hasPermission(request: true);
    if (ok) {
      return MicPermissionResult.granted();
    }
    if (kIsWeb) {
      return MicPermissionResult.failure(MicPermissionFailureKind.permissionDenied);
    }
    return MicPermissionResult.failure(MicPermissionFailureKind.unknown);
  } on MissingPluginException catch (e) {
    // 此 try 内仅调用了 hasPermission；Web 上插件偶发未注册该方法时放行，由 start() 走 getUserMedia。
    if (kIsWeb) {
      return MicPermissionResult.granted();
    }
    return MicPermissionResult.failure(
      MicPermissionFailureKind.unknown,
      e.toString(),
    );
  } on Object catch (e) {
    if (kIsWeb) {
      return _classifyWebException(e);
    }
    return MicPermissionResult.failure(
      MicPermissionFailureKind.unknown,
      e.toString(),
    );
  }
}

extension MicPermissionResultMessage on MicPermissionResult {
  /// 展示给用户看的说明（仅 [isGranted] 为 false 时使用）。
  String userFacingMessage(AppStrings s) {
    if (isGranted) {
      return '';
    }
    if (!kIsWeb) {
      final String? d = technicalDetail;
      if (d != null && d.isNotEmpty) {
        return s.micWebOther(d);
      }
      return s.micNativeDenied;
    }
    switch (failureKind!) {
      case MicPermissionFailureKind.secureContextRequired:
        return s.micWebNotSecure;
      case MicPermissionFailureKind.permissionDenied:
        return s.micWebPermissionDenied;
      case MicPermissionFailureKind.deviceNotFound:
        return s.micWebNoDevice;
      case MicPermissionFailureKind.unknown:
        final String? d = technicalDetail;
        if (d != null && d.isNotEmpty) {
          return s.micWebOther(d);
        }
        return s.micWebUnknownShort;
    }
  }
}
