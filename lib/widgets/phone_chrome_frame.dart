import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/html_design_tokens.dart';

/// Web 手机预览区：保留最小「安全区」，避免顶底占满屏导致可用内容过少（与本地浏览器观感对齐）。
const EdgeInsets _kPhoneSimulatedSafe = EdgeInsets.only(
  top: 8,
  bottom: 8,
);

/// Centers a 375×812 phone mock (HTML `.phone-simulator`) on the gray canvas.
/// Only applied on **web** so Chrome matches `index.html` layout.
class PhoneChromeFrame extends StatelessWidget {
  const PhoneChromeFrame({super.key, required this.child});

  final Widget child;

  static const double _innerW = HtmlDesignTokens.phoneWidth - 16;
  static const double _innerH = HtmlDesignTokens.phoneHeight - 16;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final parentMq = MediaQuery.of(context);

    return ColoredBox(
      color: HtmlDesignTokens.chromeBackdrop,
      child: Center(
        child: Container(
          width: HtmlDesignTokens.phoneWidth,
          height: HtmlDesignTokens.phoneHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 80,
                offset: const Offset(0, 40),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Colors.black, width: 8),
            ),
            child: SizedBox(
              width: _innerW,
              height: _innerH,
              child: MediaQuery(
                data: parentMq.copyWith(
                  size: const Size(_innerW, _innerH),
                  padding: _kPhoneSimulatedSafe,
                  viewPadding: _kPhoneSimulatedSafe,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
