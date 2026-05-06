import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/app_strings.dart';
import '../core/theme/html_design_tokens.dart';

/// HTML `.bottom-nav` + `.nav-item`：未选中仅图标（窄格），选中展开显示文案，其余格收缩。
class HtmlMatchedBottomNav extends StatelessWidget {
  const HtmlMatchedBottomNav({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final double barHeight = kIsWeb ? 56 : 72;
    final EdgeInsets barPadding = kIsWeb
        ? const EdgeInsets.fromLTRB(6, 6, 6, 6)
        : const EdgeInsets.fromLTRB(8, 12, 8, 12);
    final AppStrings s = AppStrings.of(context);
    final List<_HtmlNavItem> items = <_HtmlNavItem>[
      _HtmlNavItem(branchIndex: 0, glyph: '⚲', label: s.navPractice),
      _HtmlNavItem(branchIndex: 1, glyph: '⌬', label: s.navSocial),
      _HtmlNavItem(branchIndex: 2, glyph: '◈', label: s.navStore),
      _HtmlNavItem(branchIndex: 3, glyph: '◬', label: s.navProfile),
    ];
    final selected = navigationShell.currentIndex;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: HtmlDesignTokens.navBarFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: HtmlDesignTokens.navBarBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SizedBox(
            height: barHeight,
            child: Padding(
              padding: barPadding,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final totalW = c.maxWidth;
                  final rowHeight = c.maxHeight;
                  var inactiveW = totalW * 0.17;
                  const minInactive = 40.0;
                  const minActive = 108.0;
                  if (inactiveW < minInactive) {
                    inactiveW = minInactive;
                  }
                  var activeW = totalW - 3 * inactiveW;
                  if (activeW < minActive) {
                    activeW = minActive;
                    inactiveW = (totalW - activeW) / 3;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      for (var i = 0; i < items.length; i++)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              navigationShell.goBranch(
                                items[i].branchIndex,
                                initialLocation:
                                    items[i].branchIndex == navigationShell.currentIndex,
                              );
                            },
                            borderRadius: BorderRadius.circular(999),
                            splashColor: HtmlDesignTokens.accent.withValues(alpha: 0.15),
                            highlightColor: Colors.white.withValues(alpha: 0.06),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              width: i == selected ? activeW : inactiveW,
                              height: rowHeight,
                              padding: EdgeInsets.symmetric(
                                horizontal: i == selected ? 10 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: i == selected ? HtmlDesignTokens.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: i == selected
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: HtmlDesignTokens.primary.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: SizedBox(
                                height: rowHeight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    _NavGlyph(
                                      glyph: items[i].glyph,
                                      active: i == selected,
                                    ),
                                    if (i == selected) ...<Widget>[
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          items[i].label,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: kIsWeb ? 13 : 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            fontFamily: 'system-ui',
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HtmlNavItem {
  const _HtmlNavItem({
    required this.branchIndex,
    required this.glyph,
    required this.label,
  });

  final int branchIndex;
  final String glyph;
  final String label;
}

/// 各 Unicode 在 sans-serif / Web 回退字体里度量差很大：统一槽位 + 单独 scale/dy 做光学对齐。
class _GlyphTune {
  const _GlyphTune({this.scale = 1, this.dy = 0});

  final double scale;
  /// 垂直微调（逻辑像素），正值略下移。
  final double dy;
}

const Map<String, _GlyphTune> _kNavGlyphTune = <String, _GlyphTune>{
  '⚲': _GlyphTune(scale: 1.0, dy: 0),
  '⌬': _GlyphTune(scale: 1.0, dy: 0.5),
  // ◈ 多数字体里偏大，略缩小并略下移与其它格视觉中线对齐
  '◈': _GlyphTune(scale: 0.82, dy: 1.25),
  // ◬ 多数字体里偏小，略放大并略上移
  '◬': _GlyphTune(scale: 1.14, dy: -0.75),
};

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({
    required this.glyph,
    required this.active,
  });

  final String glyph;
  final bool active;

  static const double _slot = 32;
  static const double _fontSize = 20;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? Colors.white : HtmlDesignTokens.textSub;
    const String fontFamily = 'sans-serif';
    final _GlyphTune tune = _kNavGlyphTune[glyph] ?? const _GlyphTune();

    final TextStyle style = TextStyle(
      fontSize: _fontSize,
      height: 1,
      color: color,
      fontFamily: fontFamily,
    );

    final Widget letter = Text(
      glyph,
      textAlign: TextAlign.center,
      style: style,
      strutStyle: StrutStyle(
        fontSize: _fontSize,
        height: 1,
        leading: 0,
        fontFamily: fontFamily,
        forceStrutHeight: true,
      ),
    );

    final Widget tuned = Transform.translate(
      offset: Offset(0, tune.dy),
      child: Transform.scale(
        scale: tune.scale,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        child: letter,
      ),
    );

    return SizedBox(
      width: _slot,
      height: _slot,
      child: ClipRect(
        child: Align(
          alignment: Alignment.center,
          child: tuned,
        ),
      ),
    );
  }
}
