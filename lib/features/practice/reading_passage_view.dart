import 'package:flutter/material.dart';

/// 阅读正文：`&#x20;` 等实体、`**加粗**`，段落按空行分段，段间留一行间距。
class ReadingPassageView extends StatelessWidget {
  const ReadingPassageView({
    super.key,
    required this.passage,
    this.emptyPlaceholder = '（未解析到正文，请检查 resource/阅读.md）',
  });

  final String passage;
  final String emptyPlaceholder;

  static const TextStyle _defaultBody = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 15,
    height: 1.8,
    color: Color(0xFFD9D9D9),
  );

  static String normalizeEntities(String s) {
    return s
        .replaceAll('&#x20;', ' ')
        .replaceAll('&#32;', ' ')
        .replaceAll('&nbsp;', ' ');
  }

  /// 以「空行」分段；段内单独换行合并为空格，避免 MD 软换行破坏排版。
  static List<String> splitParagraphs(String s) {
    final String t = s.trim();
    if (t.isEmpty) {
      return <String>[];
    }
    return t
        .split(RegExp(r'\n\s*\n+'))
        .map((String e) => e.replaceAll(RegExp(r'[ \t]*\n[ \t]*'), ' ').trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  static List<InlineSpan> boldSpans(String paragraph, TextStyle base) {
    final List<InlineSpan> out = <InlineSpan>[];
    final RegExp re = RegExp(r'\*\*([^*]+)\*\*');
    int cursor = 0;
    for (final Match m in re.allMatches(paragraph)) {
      if (m.start > cursor) {
        out.add(TextSpan(text: paragraph.substring(cursor, m.start)));
      }
      out.add(
        TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      cursor = m.end;
    }
    if (cursor < paragraph.length) {
      out.add(TextSpan(text: paragraph.substring(cursor)));
    }
    if (out.isEmpty) {
      out.add(TextSpan(text: paragraph));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (passage.isEmpty) {
      return Text(
        emptyPlaceholder,
        style: _defaultBody.copyWith(color: const Color(0xFF9CA3AF)),
      );
    }
    final String norm = normalizeEntities(passage);
    final List<String> paras = splitParagraphs(norm);
    if (paras.isEmpty) {
      return SelectableText.rich(
        TextSpan(style: _defaultBody, children: boldSpans(norm, _defaultBody)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < paras.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 27),
          SelectableText.rich(
            TextSpan(
              style: _defaultBody,
              children: boldSpans(paras[i], _defaultBody),
            ),
          ),
        ],
      ],
    );
  }
}
