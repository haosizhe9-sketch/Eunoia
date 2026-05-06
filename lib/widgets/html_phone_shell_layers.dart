import 'package:flutter/material.dart';

/// Radial glow orbs from `index.html` (`.bg-glow-1`, `.bg-glow-2`).
class HtmlBackgroundGlows extends StatelessWidget {
  const HtmlBackgroundGlows({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              top: -0.1 * h,
              left: -0.2 * w,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0x407C3AED),
                        Colors.transparent,
                      ],
                      stops: const <double>[0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0.2 * h,
              right: -0.2 * w,
              child: IgnorePointer(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0x1A2DD4BF),
                        Colors.transparent,
                      ],
                      stops: const <double>[0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// HTML `.notch`
class HtmlNotch extends StatelessWidget {
  const HtmlNotch({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 140,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}
