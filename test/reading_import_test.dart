import 'package:flutter_test/flutter_test.dart';

import 'package:eunoia/features/practice/daily_task_resource_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('阅读 Test 1 导入 40 题，Passage A/B/C 与 阅读.md / 阅读答案及解析.md 对齐', () async {
    final ReadingTaskContent c = await DailyTaskResourceLoader.loadReading();
    expect(c.testNumber, 1);
    expect(c.passageA.isNotEmpty, true, reason: 'Passage A 正文为空');
    expect(c.passageB.isNotEmpty, true, reason: 'Passage B 正文为空');
    expect(c.passageC.isNotEmpty, true, reason: 'Passage C 正文为空');
    expect(c.questions.length, 40, reason: '题量应为 40');
    final int a = c.questions.where((ReadingQuestionItem q) => q.passage == 'A').length;
    final int b = c.questions.where((ReadingQuestionItem q) => q.passage == 'B').length;
    final int cc = c.questions.where((ReadingQuestionItem q) => q.passage == 'C').length;
    expect(a + b + cc, 40);
    for (final ReadingQuestionItem q in c.questions) {
      expect(q.correctAnswer.isNotEmpty, true, reason: 'Q${q.globalNumber} 缺少标答');
    }
  });
}
