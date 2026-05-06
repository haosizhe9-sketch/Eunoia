/// LLM 能力占位；雅思批改请使用 [NewsMockAIService.gradeDailyWritingFullExam] 等百炼对接实现。
class AIEngineService {
  AIEngineService();

  /// 雅思写作批改（返回分数、维度点评、改写建议等，结构以后端为准）。
  Future<Map<String, dynamic>> gradeWriting(String essayText) async {
    return <String, dynamic>{};
  }

  /// 爬词塔：从 [startLevel] 起连续 [count] 层的词与选项（结构以后端为准）。
  Future<List<Map<String, dynamic>>> fetchWordTowerLevels({
    required int startLevel,
    int count = 10,
  }) async {
    // TODO: POST Edge Function → 词库 / 生成
    return <Map<String, dynamic>>[];
  }
}
