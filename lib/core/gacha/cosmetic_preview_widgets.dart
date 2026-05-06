import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'wealth_gacha.dart';

Color _hex6(String raw) {
  final h = raw.trim();
  final v = int.parse(h, radix: 16);
  return Color(0xFF000000 | v);
}

/// 从 `subtitle` 解析 `AABBCC → DDEEFF` 双色（无 `#`）。
List<Color>? _parseFlowColors(String? subtitle) {
  if (subtitle == null || subtitle.isEmpty) return null;
  final parts = subtitle.split(RegExp(r'\s*→\s*'));
  if (parts.length != 2) return null;
  try {
    return <Color>[_hex6(parts[0]), _hex6(parts[1])];
  } catch (_) {
    return null;
  }
}

/// 统一示例头像（渐变圆形 + 顶光高光 + 剪影），用于所有头像框预览。
class _DemoAvatarCircle extends StatelessWidget {
  const _DemoAvatarCircle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: <Color>[Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF312E81)],
          stops: <double>[0, 0.45, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, size: diameter * 0.52, color: Colors.white.withValues(alpha: 0.92)),
    );
  }
}

/// 头像框内圈：默认定制渐变头像，或 [custom] 返回的 Widget（如个人 emoji）。
Widget gachaAvatarFrameCenterSlot(double diameter, Widget Function(double diameter)? custom) {
  if (custom != null) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFF0C0618),
          child: Center(child: custom(diameter)),
        ),
      ),
    );
  }
  return _DemoAvatarCircle(diameter: diameter);
}

/// 头像框：示例头像 + 按 [frameId] 区分的边框样式（`frame_01` … `frame_10`）。
class AvatarFramePreview extends StatelessWidget {
  const AvatarFramePreview({
    super.key,
    required this.frameId,
    required this.size,
    this.avatarBuilder,
  });

  final String frameId;
  final double size;

  /// 自定义内圈（如排行榜档案的 emoji）；为 null 时用默认渐变头像。
  final Widget Function(double diameter)? avatarBuilder;

  @override
  Widget build(BuildContext context) {
    final avatarD = size * 0.58;
    final Widget Function(double)? ab = avatarBuilder;

    final Widget core = switch (frameId) {
      'frame_01' => _frameSolarCorona(size, avatarD, ab),
      'frame_02' => _frameMoonFrost(size, avatarD, ab),
      'frame_03' => _frameAuroraPrism(size, avatarD, ab),
      'frame_04' => _frameRoseRound(size, avatarD, ab),
      'frame_05' => _frameElectricRing(size, avatarD, ab),
      'frame_06' => _frameThinBlue(size, avatarD, ab),
      'frame_07' => _frameFrosted(size, avatarD, ab),
      'frame_08' => _frameOatWarm(size, avatarD, ab),
      'frame_09' => _frameDoubleLine(size, avatarD, ab),
      'frame_10' => _frameMistGrey(size, avatarD, ab),
      _ => _frameThinBlue(size, avatarD, ab),
    };

    return SizedBox(
      width: size,
      height: size,
      child: Center(child: core),
    );
  }

  /// 日冕圣环：三层金质光晕 + 扫光外环 + 内圈高光边
  static Widget _frameSolarCorona(double size, double avatarD, Widget Function(double)? af) {
    final outer = avatarD * 1.26;
    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: const Color(0x44FACC15), blurRadius: outer * 0.28, spreadRadius: 1),
                BoxShadow(color: const Color(0x33F59E0B), blurRadius: outer * 0.12, spreadRadius: 0),
              ],
            ),
          ),
          Container(
            width: avatarD + 12,
            height: avatarD + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                startAngle: -math.pi / 2,
                endAngle: 1.5 * math.pi,
                colors: <Color>[
                  Color(0xFFFFFBEB),
                  Color(0xFFFDE047),
                  Color(0xFFF59E0B),
                  Color(0xFFFBBF24),
                  Color(0xFFFFFBEB),
                ],
                stops: <double>[0, 0.22, 0.5, 0.78, 1],
              ),
            ),
            padding: const EdgeInsets.all(3.2),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0C0618)),
              padding: const EdgeInsets.all(2.2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xEEFDE68A), width: 1.4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: const Color(0x44FACC15), blurRadius: 6, spreadRadius: -1),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: gachaAvatarFrameCenterSlot(avatarD - 12, af),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 霜辉月环（替代碎星）：银白扫光圆环 + 月相微饰，整体正圆
  static Widget _frameMoonFrost(double size, double avatarD, Widget Function(double)? af) {
    final d = avatarD + 12;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: d + 4,
            height: d + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: const Color(0x55C7D2FE), blurRadius: 14, spreadRadius: 0),
                BoxShadow(color: const Color(0x33F8FAFC), blurRadius: 8),
              ],
            ),
          ),
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                startAngle: 0,
                endAngle: 2 * math.pi,
                colors: <Color>[
                  Color(0xFFF1F5F9),
                  Color(0xFFE2E8F0),
                  Color(0xFFC7D2FE),
                  Color(0xFFF8FAFC),
                  Color(0xFFE2E8F0),
                ],
                stops: <double>[0, 0.25, 0.5, 0.72, 1],
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B1220)),
              padding: const EdgeInsets.all(2),
              child: SizedBox(
                width: avatarD - 6,
                height: avatarD - 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Center(child: gachaAvatarFrameCenterSlot(avatarD - 6, af)),
                    CustomPaint(painter: _MoonCrescentAccentPainter()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 极光棱框：加粗折射环 + 双色外晕
  static Widget _frameAuroraPrism(double size, double avatarD, Widget Function(double)? af) {
    final box = avatarD + 10;
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF9333EA), Color(0xFF7C3AED), Color(0xFF22D3EE), Color(0xFF06B6D4)],
          stops: <double>[0, 0.35, 0.65, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0x667C3AED), blurRadius: 18, spreadRadius: -2),
          BoxShadow(color: const Color(0x4422D3EE), blurRadius: 12),
        ],
      ),
      padding: const EdgeInsets.all(3.2),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF080510)),
        padding: const EdgeInsets.all(2),
        child: gachaAvatarFrameCenterSlot(avatarD - 6, af),
      ),
    );
  }

  /// 蔷薇圆窗：正圆头像 + 外圈放射花窗纹理（环形装饰）
  static Widget _frameRoseRound(double size, double avatarD, Widget Function(double)? af) {
    final d = avatarD + 16;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(d),
            painter: _RoseLatticeRingPainter(),
          ),
          Container(
            width: avatarD + 4,
            height: avatarD + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF4C1D95), Color(0xFF6D28D9)],
              ),
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(
              child: gachaAvatarFrameCenterSlot(avatarD - 2, af),
            ),
          ),
        ],
      ),
    );
  }

  /// 电脉圆环：正圆 + 分段青色电弧
  static Widget _frameElectricRing(double size, double avatarD, Widget Function(double)? af) {
    final d = avatarD + 12;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(d),
            painter: _ElectricArcsRingPainter(),
          ),
          Container(
            width: avatarD + 3,
            height: avatarD + 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF134E4A), width: 1),
              boxShadow: <BoxShadow>[
                BoxShadow(color: const Color(0x552DD4BF), blurRadius: 14),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: gachaAvatarFrameCenterSlot(avatarD - 4, af),
          ),
        ],
      ),
    );
  }

  /// 浅蓝细线：冰蓝环 + 柔光
  static Widget _frameThinBlue(double size, double avatarD, Widget Function(double)? af) {
    return Container(
      width: avatarD + 8,
      height: avatarD + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0x4460A5FA), blurRadius: 10, spreadRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x332563EB), width: 1),
        ),
        padding: const EdgeInsets.all(1.5),
        child: gachaAvatarFrameCenterSlot(avatarD - 8, af),
      ),
    );
  }

  /// 磨砂晶环：厚玻璃边 + 内缘高光
  static Widget _frameFrosted(double size, double avatarD, Widget Function(double)? af) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: avatarD + 14,
          height: avatarD + 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 3.5),
            boxShadow: <BoxShadow>[
              BoxShadow(color: Colors.white.withValues(alpha: 0.12), blurRadius: 8, spreadRadius: -2),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            padding: const EdgeInsets.all(1.5),
            child: gachaAvatarFrameCenterSlot(avatarD - 8, af),
          ),
        ),
      ),
    );
  }

  /// 燕麦柔环：暖米白双层正圆 + 柔和投影
  static Widget _frameOatWarm(double size, double avatarD, Widget Function(double)? af) {
    final d = avatarD + 10;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF5E6D3),
        border: Border.all(color: const Color(0xFFE8D5C4), width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0x4D78350F), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: const Color(0x22F5E6D3), blurRadius: 6, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFBF5),
          border: Border.all(color: const Color(0xFFD4C4B0), width: 1),
        ),
        padding: const EdgeInsets.all(2),
        child: gachaAvatarFrameCenterSlot(avatarD - 8, af),
      ),
    );
  }

  /// 极简双线：铂银渐变材质双环（仅环身着色，内为头像）
  static Widget _frameDoubleLine(double size, double avatarD, Widget Function(double)? af) {
    return Container(
      width: avatarD + 16,
      height: avatarD + 16,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFFF8FAFC), Color(0xFF94A3B8)],
          stops: <double>[0, 0.35, 0.65, 1],
        ),
      ),
      padding: const EdgeInsets.all(1.8),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D071C)),
        padding: const EdgeInsets.all(1.6),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-0.8, -0.9),
              end: Alignment(0.9, 0.8),
              colors: <Color>[Color(0xFFF1F5F9), Color(0xFFCBD5E1), Color(0xFFE2E8F0)],
            ),
          ),
          padding: const EdgeInsets.all(1.4),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D071C)),
            padding: const EdgeInsets.all(2),
            child: gachaAvatarFrameCenterSlot(avatarD - 10, af),
          ),
        ),
      ),
    );
  }

  /// 雾灰圆环：低对比双层雾面正圆
  static Widget _frameMistGrey(double size, double avatarD, Widget Function(double)? af) {
    return Container(
      width: avatarD + 12,
      height: avatarD + 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x1A1E293B),
        border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.45), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(color: const Color(0x330F172A), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF475569).withValues(alpha: 0.35), width: 1),
        ),
        padding: const EdgeInsets.all(2.5),
        child: gachaAvatarFrameCenterSlot(avatarD - 8, af),
      ),
    );
  }
}

/// 月相：右上角极淡的弦月饰线（不破坏圆形轮廓）
class _MoonCrescentAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.72, size.height * 0.22);
    final paint = Paint()
      ..color = const Color(0x55E2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, 4, paint);
    canvas.drawCircle(Offset(c.dx + 1.2, c.dy), 3.2, Paint()..color = const Color(0xFF0B1220)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 环形蔷薇格：外圈紫粉分段弧
class _RoseLatticeRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ro = size.shortestSide / 2 - 0.5;
    final ri = ro - 5.5;
    const n = 10;
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(const Color(0xFF7E22CE), const Color(0xFFF0ABFC), t)!;
      final start = (i * 2 * math.pi / n) + 0.08;
      final sweep = 2 * math.pi / n - 0.16;
      canvas.drawArc(Rect.fromCircle(center: center, radius: (ro + ri) / 2), start, sweep, false, paint);
    }
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66C4B5FD);
    canvas.drawCircle(center, ro, rim);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 环形电弧：青绿分段发光弧段
class _ElectricArcsRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 1;
    const segments = 6;
    for (var i = 0; i < segments; i++) {
      final start = i * math.pi / 3 + 0.12;
      final sweep = math.pi / 4;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x442DD4BF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5EEAD4);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r - 1), start, sweep, false, glow);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r - 1), start, sweep, false, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 昵称流彩：示例昵称 + 沿 subtitle 双色流动的渐变字（可关动画）。
class NameFlowPreview extends StatefulWidget {
  const NameFlowPreview({
    super.key,
    required this.entry,
    required this.maxWidth,
    required this.fontSize,
    this.animate = true,
    this.displayText = '玩家昵称',
    /// 为 true 时与单行 `Text` 左对齐一致（档案页切换流彩时不挪位）。
    this.leftAlign = false,
    /// 固定行高；与默认金色昵称行对齐时可设为 30 左右。
    this.fixedHeight,
  });

  final GachaCatalogEntry entry;
  final double maxWidth;
  final double fontSize;
  final bool animate;

  /// 展示的昵称文案（档案页传入真实昵称）。
  final String displayText;

  final bool leftAlign;

  /// 非空时外层 `SizedBox` 限高，避免与相邻 `ShaderMask` 昵称垂直错位。
  final double? fixedHeight;

  @override
  State<NameFlowPreview> createState() => _NameFlowPreviewState();
}

class _NameFlowPreviewState extends State<NameFlowPreview> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    if (widget.animate) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(NameFlowPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        _c.repeat();
      } else {
        _c.stop();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _parseFlowColors(widget.entry.subtitle) ?? const <Color>[Color(0xFF94A3B8), Color(0xFFE2E8F0)];
    final textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      fontFamily: 'system-ui',
    );

    Widget textWithShader(double shift) {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            colors: <Color>[colors[0], colors[1], colors[0]],
            stops: const <double>[0, 0.5, 1],
            begin: Alignment(-1.2 + shift * 2.4, 0),
            end: Alignment(0.2 + shift * 2.4, 0),
          ).createShader(bounds);
        },
        child: Text(
          widget.displayText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle.copyWith(color: Colors.white),
        ),
      );
    }

    final Widget animatedOrStatic = widget.animate
        ? AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, _) => textWithShader(_c.value),
          )
        : textWithShader(0.35);

    if (widget.leftAlign) {
      return SizedBox(
        width: widget.maxWidth.isFinite ? widget.maxWidth : double.infinity,
        height: widget.fixedHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: animatedOrStatic,
        ),
      );
    }

    return SizedBox(
      width: widget.maxWidth,
      height: widget.fixedHeight,
      child: Center(child: animatedOrStatic),
    );
  }
}

/// 抽卡 / 商城统一入口：头像框与昵称流彩用程序绘制，其余仍走静态图（由调用方处理）。
Widget buildCosmeticOrAssetPreview(
  GachaCatalogEntry entry, {
  required double maxSide,
  required double flowFontSize,
  bool animateFlow = true,
}) {
  switch (entry.kind) {
    case GachaAssetKind.avatarFrame:
      return AvatarFramePreview(frameId: entry.id, size: maxSide);
    case GachaAssetKind.nameFlow:
      return NameFlowPreview(
        entry: entry,
        maxWidth: math.max(maxSide * 2.6, 72),
        fontSize: flowFontSize,
        animate: animateFlow,
      );
    case GachaAssetKind.figure:
    case GachaAssetKind.ePet:
    case GachaAssetKind.cardFace:
      return Image.asset(
        entry.previewAsset,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
            Icon(Icons.image_not_supported_outlined, size: maxSide * 0.45, color: Colors.white38),
      );
  }
}
