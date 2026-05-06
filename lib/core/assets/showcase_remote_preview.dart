import 'package:flutter/foundation.dart';

/// 手办/E 宠展柜是否用 **2D 预览图** 替代 GLB（与 GLB 同名映射到 `assets/pictures/*.png`）。
///
/// - **iOS / Android**：缩略图（省流量与 GPU）。
/// - **Web + 非 localhost**：缩略图（省带宽）。
/// - **Web + localhost / 127.0.0.1**：仍为 GLB（`flutter run -d chrome` 本地调试 3D）。
bool useShowcaseThumbnailInsteadOfGlb() {
  if (!kIsWeb) return true;
  final String host = Uri.base.host.toLowerCase();
  return host != 'localhost' &&
      host != '127.0.0.1' &&
      host != '::1';
}

/// 将 `pubspec` 中的 `.glb` 路径映射到图鉴约定下的预览图（与 [gachaCatalog] 一致）。
///
/// - `assets/models/model_01.glb` → `assets/pictures/model_01.png`
/// - `assets/models/epet_01.glb` → `assets/pictures/Epet_01.png`
String? showcaseThumbnailAssetPath(String glbAssetPath) {
  if (!glbAssetPath.toLowerCase().endsWith('.glb')) return null;
  final List<String> segments = glbAssetPath.split(RegExp(r'[/\\]'));
  final String file = segments.isEmpty ? glbAssetPath : segments.last;
  final String base =
      file.length > 4 ? file.substring(0, file.length - 4) : file;
  if (base.startsWith('epet_')) {
    final String suffix = base.substring('epet_'.length);
    return 'assets/pictures/Epet_$suffix.png';
  }
  return 'assets/pictures/$base.png';
}
