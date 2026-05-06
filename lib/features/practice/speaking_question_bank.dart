/// 解析 `resource/口语.md`：Part 1（题号 1–60）、Part 2&3（61–100）。
abstract final class SpeakingQuestionBank {
  SpeakingQuestionBank._();

  /// 匹配行首 `数字. 题干`（忽略 `###` 等小标题行）。
  static final RegExp _numberedLine = RegExp(
    r'^\s*(\d{1,3})\.\s+(.+)$',
    multiLine: true,
  );

  /// 从 Markdown 正文解析；题号不在 1–100 的忽略。
  static ({List<String> part1, List<String> part2}) parseMarkdown(String raw) {
    final List<String> part1 = <String>[];
    final List<String> part2 = <String>[];
    for (final RegExpMatch m in _numberedLine.allMatches(raw)) {
      final int? n = int.tryParse(m.group(1)!);
      if (n == null) {
        continue;
      }
      final String text = m.group(2)!.trim();
      if (text.isEmpty) {
        continue;
      }
      if (n >= 1 && n <= 60) {
        part1.add(text);
      } else if (n >= 61 && n <= 100) {
        part2.add(text);
      }
    }
    return (part1: part1, part2: part2);
  }

  /// 破冰话题：Part1 + Part2 全部题干（去重保持顺序）。
  static List<String> allIcebreakerPool(({List<String> part1, List<String> part2}) parsed) {
    return <String>[...parsed.part1, ...parsed.part2];
  }
}
