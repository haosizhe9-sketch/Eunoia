import 'package:flutter/material.dart';

import '../../../core/theme/html_design_tokens.dart';

/// 口语录音实时输入电平（与 `record` 振幅映射配合使用）。
class MicInputLevelMeter extends StatelessWidget {
  const MicInputLevelMeter({super.key, required this.level, required this.active});

  final double level;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const int segments = 14;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(segments, (int i) {
        final double threshold = (i + 1) / segments;
        final bool lit = active && level + 0.03 >= threshold;
        final Color segColor = i >= segments * 0.72
            ? const Color(0xFFF43F5E)
            : i >= segments * 0.46
                ? const Color(0xFFFBBF24)
                : HtmlDesignTokens.accent;
        final double h = 6 + i * 2.15;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 72),
            curve: Curves.easeOut,
            width: 5,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: lit ? segColor : Colors.white.withValues(alpha: active ? 0.16 : 0.09),
              boxShadow: lit
                  ? <BoxShadow>[
                      BoxShadow(color: segColor.withValues(alpha: 0.38), blurRadius: 6),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
