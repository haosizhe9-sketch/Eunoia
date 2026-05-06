import 'model_glb_url_stub.dart' if (dart.library.html) 'model_glb_url_web.dart' as impl;

/// 将 `pubspec.yaml` 中的 GLB 路径转为 model-viewer 可用的 [src]。
///
/// Web：`assets/models/x.glb` → 站点根下 `/assets/assets/models/x.glb`（或带 base-href 前缀）。
/// 其它平台：原样返回，供原生 WebView / 本地加载使用。
String modelViewerGlbSrc(String pubspecAssetKey) =>
    impl.modelViewerGlbSrc(pubspecAssetKey);
