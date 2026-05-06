import 'package:web/web.dart' as web;

/// Flutter Web 将资源发布到 `build/web/assets/<pubspec 路径>`，
/// 故需解析为可请求的绝对 URL（并尊重 `<base href>`）。
String modelViewerGlbSrc(String pubspecAssetKey) {
  final String key = pubspecAssetKey.startsWith('/')
      ? pubspecAssetKey.substring(1)
      : pubspecAssetKey;
  final web.Element? baseEl = web.document.querySelector('base');
  final String? hrefAttr = baseEl?.getAttribute('href');
  final String normalizedBase =
      (hrefAttr == null || hrefAttr.isEmpty) ? '/' : hrefAttr;
  final String origin = web.window.location.origin;
  final Uri baseUri = Uri.parse('$origin$normalizedBase');
  return baseUri.resolve('assets/$key').toString();
}
