import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../core/assets/model_glb_url.dart';
import '../../core/assets/showcase_remote_preview.dart';
import 'handoff_model_viewer.dart';

/// 档案展柜中 E 宠统一视口（逻辑像素）；屏宽不足时等比缩小。
Size epetShowcaseViewportSize(BoxConstraints stageConstraints) {
  const double w = 132;
  const double h = 224;
  final double maxW = stageConstraints.maxWidth * 0.36;
  if (maxW >= w) {
    return const Size(w, h);
  }
  final double s = maxW / w;
  return Size(maxW, h * s);
}

/// 档案页右侧 E 宠：固定正视、不可拖拽旋转；不支持平台时显示 emoji。
class EpetFigureViewer extends StatelessWidget {
  const EpetFigureViewer({
    super.key,
    required this.glbAssetPath,
    required this.width,
    required this.height,
    required this.fallbackEmoji,
  });

  final String glbAssetPath;
  final double width;
  final double height;
  final String fallbackEmoji;

  @override
  Widget build(BuildContext context) {
    if (!handoffModelViewerSupported()) {
      return Center(
        child: Text(fallbackEmoji, style: TextStyle(fontSize: math.min(48, width * 0.35))),
      );
    }

    final String? thumbPath =
        useShowcaseThumbnailInsteadOfGlb()
            ? showcaseThumbnailAssetPath(glbAssetPath)
            : null;
    if (thumbPath != null) {
      return IgnorePointer(
        child: SizedBox(
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
                  style: TextStyle(fontSize: math.min(52, width * 0.42)),
                ),
              );
            },
          ),
        ),
      );
    }

    return IgnorePointer(
      child: SizedBox(
        key: ValueKey<String>(glbAssetPath),
        width: width,
        height: height,
        child: ModelViewer(
          src: modelViewerGlbSrc(glbAssetPath),
          alt: 'E 宠 3D 模型',
          backgroundColor: Colors.transparent,
          ar: false,
          autoRotate: false,
          cameraControls: false,
          disableZoom: true,
          disablePan: true,
          disableTap: true,
          touchAction: TouchAction.none,
          interactionPrompt: InteractionPrompt.none,
          debugLogging: kDebugMode,
          environmentImage: 'neutral',
          exposure: 1,
          // 更小比例 + 更远相机 + 更宽 FOV，适配偏高/偏宽的 E 宠 glb
          scale: '0.72 0.72 0.72',
          fieldOfView: '65deg',
          cameraOrbit: '90deg 90deg 175%',
          cameraTarget: 'auto auto auto',
          minCameraOrbit: '90deg 90deg 175%',
          maxCameraOrbit: '90deg 90deg 175%',
          relatedCss: '''
model-viewer {
  width: 100%;
  height: 100%;
  display: block;
  pointer-events: none;
}
body { margin: 0; overflow: hidden; }
''',
        ),
      ),
    );
  }
}
