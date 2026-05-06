import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/html_design_tokens.dart';
import 'reading_passage_view.dart';

/// 黄色高亮（半透），叠在文字下方由 [TextSpan.backgroundColor] 绘制。
const Color _kMarkerYellow = Color(0x99FFEB3B);

/// 管理各题干区域的划选高亮与撤销栈。
class ExamMarkerController extends ChangeNotifier {
  final Map<String, List<(int start, int end)>> _ranges = <String, List<(int, int)>>{};
  final List<({String key, int start, int end})> _undoStack = <({String key, int start, int end})>[];

  List<(int start, int end)> rangesFor(String key) =>
      List<(int, int)>.from(_ranges[key] ?? const <(int, int)>[]);

  bool get canUndo => _undoStack.isNotEmpty;

  void addHighlight(String key, int start, int end) {
    if (end <= start || start < 0) {
      return;
    }
    _ranges.putIfAbsent(key, () => <(int, int)>[]).add((start, end));
    _undoStack.add((key: key, start: start, end: end));
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    final ({String key, int start, int end}) last = _undoStack.removeLast();
    final List<(int, int)>? list = _ranges[last.key];
    if (list == null) {
      return;
    }
    for (int i = list.length - 1; i >= 0; i--) {
      if (list[i].$1 == last.start && list[i].$2 == last.end) {
        list.removeAt(i);
        break;
      }
    }
    if (list.isEmpty) {
      _ranges.remove(last.key);
    }
    notifyListeners();
  }

  static List<(int, int)> mergeIntervals(List<(int, int)> raw) {
    if (raw.isEmpty) {
      return <(int, int)>[];
    }
    final List<(int, int)> sorted = List<(int, int)>.from(raw)
      ..sort(((int, int) a, (int, int) b) => a.$1.compareTo(b.$1));
    final List<(int, int)> out = <(int, int)>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      final (int a, int b) = sorted[i];
      final (int la, int lb) = out.last;
      if (a <= lb) {
        out[out.length - 1] = (la, math.max(lb, b));
      } else {
        out.add((a, b));
      }
    }
    return out;
  }
}

/// 顶部工具条：标记笔（点按进入单次划选模式）、撤销。
class ExamMarkerToolbar extends StatelessWidget {
  const ExamMarkerToolbar({
    super.key,
    required this.penActive,
    required this.onPenPressed,
    required this.onUndo,
    required this.canUndo,
  });

  final bool penActive;
  final VoidCallback onPenPressed;
  final VoidCallback onUndo;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: <Widget>[
              Tooltip(
                message: penActive ? '划选一段文字添加高亮（完成后自动退出）' : '标记笔：点按后在题干上划选添加黄色高亮',
                child: InkWell(
                  onTap: onPenPressed,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.brush_rounded,
                          size: 20,
                          color: penActive ? HtmlDesignTokens.accent : HtmlDesignTokens.textMain,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          penActive ? '划选高亮…' : '标记笔',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: penActive ? HtmlDesignTokens.accent : HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: '撤销上一处高亮',
                child: IconButton(
                  onPressed: canUndo ? onUndo : null,
                  icon: Icon(
                    Icons.undo_rounded,
                    color: canUndo ? HtmlDesignTokens.textMain : HtmlDesignTokens.textSub.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 纯文本题干：底层高亮 + 透明只读 [TextField] 承接划选。
class HighlightableExamText extends StatefulWidget {
  const HighlightableExamText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.highlightKey,
    required this.marker,
    required this.penActive,
    required this.onHighlightCommitted,
    this.strutStyle,
  });

  final String text;
  final TextStyle textStyle;
  final StrutStyle? strutStyle;
  final String highlightKey;
  final ExamMarkerController marker;
  final bool penActive;
  final VoidCallback onHighlightCommitted;

  @override
  State<HighlightableExamText> createState() => _HighlightableExamTextState();
}

class _HighlightableExamTextState extends State<HighlightableExamText> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(HighlightableExamText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      final int len = _controller.selection.isValid ? _controller.selection.start : 0;
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: len.clamp(0, widget.text.length)),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerUp() {
    if (!widget.penActive || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.penActive) {
        return;
      }
      final TextSelection sel = _controller.selection;
      if (sel.isValid && !sel.isCollapsed) {
        final int a = math.min(sel.start, sel.end);
        final int b = math.max(sel.start, sel.end);
        if (a >= 0 && b <= _controller.text.length && b > a) {
          widget.marker.addHighlight(widget.highlightKey, a, b);
          _controller.selection = TextSelection.collapsed(offset: b);
          widget.onHighlightCommitted();
        }
      }
    });
  }

  TextSpan _spanForPlain(String plain, List<(int, int)> merged) {
    if (merged.isEmpty) {
      return TextSpan(text: plain, style: widget.textStyle);
    }
    final List<InlineSpan> children = <InlineSpan>[];
    int cursor = 0;
    for (final (int s, int e) in merged) {
      final int ss = s.clamp(0, plain.length);
      final int ee = e.clamp(0, plain.length);
      if (ss > cursor) {
        children.add(TextSpan(text: plain.substring(cursor, ss), style: widget.textStyle));
      }
      if (ee > ss) {
        children.add(
          TextSpan(
            text: plain.substring(ss, ee),
            style: widget.textStyle.copyWith(backgroundColor: _kMarkerYellow),
          ),
        );
      }
      cursor = math.max(cursor, ee);
    }
    if (cursor < plain.length) {
      children.add(TextSpan(text: plain.substring(cursor), style: widget.textStyle));
    }
    return TextSpan(style: widget.textStyle, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final StrutStyle strut = widget.strutStyle ?? StrutStyle.fromTextStyle(widget.textStyle, forceStrutHeight: true);
    return ListenableBuilder(
      listenable: widget.marker,
      builder: (BuildContext context, _) {
        final List<(int, int)> merged =
            ExamMarkerController.mergeIntervals(widget.marker.rangesFor(widget.highlightKey));
        return Listener(
          onPointerUp: (_) => _onPointerUp(),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              return SizedBox(
                width: w,
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    Text.rich(
                      _spanForPlain(widget.text, merged),
                      strutStyle: strut,
                    ),
                    SizedBox(
                      width: w,
                      child: TextField(
                        controller: _controller,
                        readOnly: true,
                        maxLines: null,
                        minLines: 1,
                        style: widget.textStyle.copyWith(color: Colors.transparent, height: widget.textStyle.height),
                        strutStyle: strut,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        cursorColor:
                            widget.penActive ? HtmlDesignTokens.accent.withValues(alpha: 0.5) : Colors.transparent,
                        showCursor: false,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

const String _kBlankFill = '\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0';

/// 阅读小题含 `[BLANK]`：与划选层索引一致的纯文本 + 填空处下划线样式。
(String plain, List<(int, int)> blankZones) readingStemPlainAndBlankZones(String body) {
  final List<String> parts = body.split('[BLANK]');
  final StringBuffer buf = StringBuffer();
  final List<(int, int)> zones = <(int, int)>[];
  for (int i = 0; i < parts.length; i++) {
    buf.write(parts[i]);
    if (i < parts.length - 1) {
      final int start = buf.length;
      buf.write(_kBlankFill);
      zones.add((start, buf.length));
    }
  }
  return (buf.toString(), zones);
}

TextSpan readingStemHighlightedSpan({
  required String plain,
  required TextStyle baseStyle,
  required List<(int, int)> blankZones,
  required List<(int, int)> highlightMerged,
}) {
  if (plain.isEmpty) {
    return TextSpan(text: '', style: baseStyle);
  }
  final List<(int, int)> hl = highlightMerged;

  bool inZone(int index, List<(int, int)> ranges) {
    for (final (int a, int b) in ranges) {
      if (index >= a && index < b) {
        return true;
      }
    }
    return false;
  }

  final List<InlineSpan> out = <InlineSpan>[];
  int i = 0;
  while (i < plain.length) {
    final bool h0 = inZone(i, hl);
    final bool b0 = inZone(i, blankZones);
    int j = i + 1;
    while (j < plain.length) {
      if (inZone(j, hl) != h0 || inZone(j, blankZones) != b0) {
        break;
      }
      j++;
    }
    TextStyle runStyle = baseStyle;
    if (b0) {
      runStyle = runStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: HtmlDesignTokens.textSub.withValues(alpha: 0.9),
        decorationThickness: 1.4,
      );
    }
    if (h0) {
      runStyle = runStyle.copyWith(backgroundColor: _kMarkerYellow);
    }
    out.add(TextSpan(text: plain.substring(i, j), style: runStyle));
    i = j;
  }
  return TextSpan(style: baseStyle, children: out);
}

/// 与 [ReadingPassageView] 对齐的纯文本（用于划选索引）；去掉 `**加粗**` 标记。
String readingPassagePlainForHighlight(String passage) {
  if (passage.isEmpty) {
    return '';
  }
  String norm = ReadingPassageView.normalizeEntities(passage);
  // Dart 的 replaceAll 不会展开 $1，必须用 replaceAllMapped 才能去掉 **加粗** 并保留中间文字。
  norm = norm.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*'),
    (Match m) => m.group(1)!,
  );
  final List<String> paras = ReadingPassageView.splitParagraphs(norm);
  if (paras.isEmpty) {
    return norm.trim();
  }
  return paras.join('\n\n');
}

/// 阅读题干（含 [BLANK]）：高亮 + 透明划选层，索引与 [readingStemPlainAndBlankZones] 一致。
class HighlightableReadingStem extends StatefulWidget {
  const HighlightableReadingStem({
    super.key,
    required this.body,
    required this.textStyle,
    required this.highlightKey,
    required this.marker,
    required this.penActive,
    required this.onHighlightCommitted,
  });

  final String body;
  final TextStyle textStyle;
  final String highlightKey;
  final ExamMarkerController marker;
  final bool penActive;
  final VoidCallback onHighlightCommitted;

  @override
  State<HighlightableReadingStem> createState() => _HighlightableReadingStemState();
}

class _HighlightableReadingStemState extends State<HighlightableReadingStem> {
  late final TextEditingController _controller;
  late (String, List<(int, int)>) _plainZones;

  @override
  void initState() {
    super.initState();
    _plainZones = readingStemPlainAndBlankZones(widget.body);
    _controller = TextEditingController(text: _plainZones.$1);
  }

  @override
  void didUpdateWidget(HighlightableReadingStem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      _plainZones = readingStemPlainAndBlankZones(widget.body);
      _controller.text = _plainZones.$1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerUp() {
    if (!widget.penActive || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.penActive) {
        return;
      }
      final TextSelection sel = _controller.selection;
      if (sel.isValid && !sel.isCollapsed) {
        final int a = math.min(sel.start, sel.end);
        final int b = math.max(sel.start, sel.end);
        if (a >= 0 && b <= _controller.text.length && b > a) {
          widget.marker.addHighlight(widget.highlightKey, a, b);
          _controller.selection = TextSelection.collapsed(offset: b);
          widget.onHighlightCommitted();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final StrutStyle strut = StrutStyle.fromTextStyle(widget.textStyle, forceStrutHeight: true);
    return ListenableBuilder(
      listenable: widget.marker,
      builder: (BuildContext context, _) {
        final List<(int, int)> merged =
            ExamMarkerController.mergeIntervals(widget.marker.rangesFor(widget.highlightKey));
        return Listener(
          onPointerUp: (_) => _onPointerUp(),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              return SizedBox(
                width: w,
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: <Widget>[
                    Text.rich(
                      readingStemHighlightedSpan(
                        plain: _plainZones.$1,
                        baseStyle: widget.textStyle,
                        blankZones: _plainZones.$2,
                        highlightMerged: merged,
                      ),
                      strutStyle: strut,
                    ),
                    SizedBox(
                      width: w,
                      child: TextField(
                        controller: _controller,
                        readOnly: true,
                        maxLines: null,
                        minLines: 1,
                        style: widget.textStyle.copyWith(color: Colors.transparent, height: widget.textStyle.height),
                        strutStyle: strut,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor:
                            widget.penActive ? HtmlDesignTokens.accent.withValues(alpha: 0.5) : Colors.transparent,
                        showCursor: false,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
