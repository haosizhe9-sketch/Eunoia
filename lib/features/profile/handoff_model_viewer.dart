import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../core/assets/model_glb_url.dart';
import '../../core/assets/showcase_remote_preview.dart';
import 'leaderboard_entry.dart';

bool handoffModelViewerSupported() {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

/// 档案页中央手办：支持平台用 [ModelViewer] 拖拽绕竖直轴旋转，否则显示 emoji。
class HandoffFigureViewer extends StatelessWidget {
  const HandoffFigureViewer({
    super.key,
    required this.width,
    required this.height,
    required this.fallbackEmoji,
    required this.fallbackEmojiStyle,
    this.glbAssetPath = ShowcaseGlbAssets.defaultPath,
  });

  final double width;
  final double height;
  final String fallbackEmoji;
  final TextStyle fallbackEmojiStyle;
  /// 与 `pubspec.yaml` 中注册的 glb 路径一致。
  final String glbAssetPath;

  @override
  Widget build(BuildContext context) {
    if (!handoffModelViewerSupported()) {
      return Center(
        child: Text(
          fallbackEmoji,
          textAlign: TextAlign.center,
          style: fallbackEmojiStyle,
        ),
      );
    }

    final String? thumbPath =
        useShowcaseThumbnailInsteadOfGlb()
            ? showcaseThumbnailAssetPath(glbAssetPath)
            : null;
    if (thumbPath != null) {
      return SizedBox(
        key: ValueKey<String>('thumb-$glbAssetPath'),
        width: width,
        height: height,
        child: Image.asset(
          thumbPath,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (BuildContext context, Object error, StackTrace? st) {
            return Center(
              child: Text(
                fallbackEmoji,
                textAlign: TextAlign.center,
                style: fallbackEmojiStyle,
              ),
            );
          },
        ),
      );
    }

    // 避免 ClipRRect：部分机型上 WebView/PlatformView 与圆角裁剪组合会导致画面空白。
    return SizedBox(
      key: ValueKey<String>(glbAssetPath),
      width: width,
      height: height,
      child: ModelViewer(
        src: modelViewerGlbSrc(glbAssetPath),
        alt: '手办 3D 模型',
        backgroundColor: Colors.transparent,
        ar: false,
        autoRotate: false,
        cameraControls: true,
        touchAction: TouchAction.none,
        disableZoom: true,
        disablePan: false,
        // 默认点击会触发 tap-to-recenter / 重新取景，视觉上像「突然缩小」。
        disableTap: true,
        interactionPrompt: InteractionPrompt.none,
        debugLogging: kDebugMode,
        environmentImage: 'neutral',
        exposure: 1,
        // 全身入画：略缩小场景内模型 + 更远相机 + 更宽竖直 FOV；三轴 scale 合法
        scale: '0.88 0.88 0.88',
        fieldOfView: '58deg',
        minFieldOfView: '30deg',
        maxFieldOfView: '75deg',
        // phi 从场景顶部起算：90° = 相机在水平面内环绕（正视/平视），小于 90° 会俯视
        cameraOrbit: '90deg 90deg 142%',
        cameraTarget: 'auto auto auto',
        minCameraOrbit: '-Infinity 88deg 35%',
        maxCameraOrbit: 'Infinity 92deg 165%',
        // 让内嵌 WebView 铺满父级，避免 canvas 高度不足造成「上下被切」
        relatedCss: '''
model-viewer {
  width: 100%;
  height: 100%;
  display: block;
}
body { margin: 0; overflow: hidden; }
''',
      ),
    );
  }
}
