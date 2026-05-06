import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 阿里云百炼 / DashScope OpenAI 兼容接口。
/// 编译时注入：`flutter run --dart-define=DASHSCOPE_API_KEY=sk-xxxx`
const String kDashScopeApiKey = String.fromEnvironment(
  'DASHSCOPE_API_KEY',
  defaultValue: '',
);

const String _dashScopeChatUrl =
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

/// 默认模型（可在控制台开通后按需改为 qwen-max 等）。
const String kDefaultDashScopeModel = 'qwen-plus';

/// 每日全员同卷分发：静态资源根路径（勿尾缀 `/`）。
/// 客户端请求：`{BASE}/news_mock_daily_{yyyy-MM-dd}.json`（日期为东八区日历日）。
/// 例：`flutter run --dart-define=NEWS_MOCK_DAILY_BASE_URL=https://cdn.example.com/eunoia`
const String kNewsMockDailyBaseUrl = String.fromEnvironment(
  'NEWS_MOCK_DAILY_BASE_URL',
  defaultValue: '',
);

/// 若设置则优先于 [kNewsMockDailyBaseUrl]；将 `{date}` 替换为东八区 `yyyy-MM-dd`。
/// 例：`https://xxx.com/path/news_mock_daily_{date}.json`
const String kNewsMockDailyUrlPattern = String.fromEnvironment(
  'NEWS_MOCK_DAILY_URL_PATTERN',
  defaultValue: '',
);

// --- Paper ---

class NewsMockReadingQuestion {
  const NewsMockReadingQuestion({
    required this.question,
    required this.options,
    this.optionTags,
    this.correctIndex,
    this.answerExplanation,
  });

  final String question;
  final List<String> options;
  final List<String>? optionTags;
  /// 生成阶段由模型给出，用于本地核对或二次批改；不向用户展示。
  final int? correctIndex;
  final String? answerExplanation;

  factory NewsMockReadingQuestion.fromJson(Map<String, dynamic> j) {
    final List<dynamic>? opts = j['options'] as List<dynamic>?;
    final List<String> options =
        opts?.map((Object? e) => '$e'.trim()).where((String s) => s.isNotEmpty).toList() ??
            <String>[];
    final List<dynamic>? tags = j['option_tags'] as List<dynamic>?;
    final List<String>? optionTags = tags == null
        ? null
        : tags.map((Object? e) => '$e'.trim()).where((String s) => s.isNotEmpty).toList();
    final Object? ci = j['correct_index'];
    final int? correctIndex =
        ci is num ? ci.toInt() : int.tryParse('$ci');
    return NewsMockReadingQuestion(
      question: '${j['question'] ?? ''}'.trim(),
      options: options,
      optionTags: optionTags,
      correctIndex: correctIndex,
      answerExplanation: '${j['explanation'] ?? ''}'.trim().isEmpty
          ? null
          : '${j['explanation']}'.trim(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'question': question,
        'options': options,
        if (optionTags != null) 'option_tags': optionTags,
        if (correctIndex != null) 'correct_index': correctIndex,
        if (answerExplanation != null && answerExplanation!.trim().isNotEmpty)
          'explanation': answerExplanation,
      };
}

class NewsMockPaper {
  const NewsMockPaper({
    required this.paperId,
    required this.title,
    required this.articlePreview,
    required this.articleFull,
    required this.reading,
    required this.writingPrompt,
    required this.speakingCue,
    required this.speakingHints,
    this.generatedAtUtc,
  });

  final String paperId;
  final String title;
  final String articlePreview;
  final String articleFull;
  final List<NewsMockReadingQuestion> reading;
  final String writingPrompt;
  final String speakingCue;
  final String speakingHints;
  final DateTime? generatedAtUtc;

  factory NewsMockPaper.fromJson(Map<String, dynamic> j) {
    final List<dynamic>? r = j['reading'] as List<dynamic>?;
    final List<NewsMockReadingQuestion> reading = <NewsMockReadingQuestion>[];
    if (r != null) {
      for (final Object? e in r) {
        if (e is Map<String, dynamic>) {
          reading.add(NewsMockReadingQuestion.fromJson(e));
        }
      }
    }
    return NewsMockPaper(
      paperId: '${j['paper_id'] ?? j['paperId'] ?? 'paper_local'}'.trim(),
      title: '${j['title'] ?? ''}'.trim(),
      articlePreview: '${j['article_preview'] ?? j['articlePreview'] ?? ''}'.trim(),
      articleFull: '${j['article_full'] ?? j['articleFull'] ?? ''}'.trim(),
      reading: reading,
      writingPrompt: '${j['writing_prompt'] ?? j['writingPrompt'] ?? ''}'.trim(),
      speakingCue: '${j['speaking_cue'] ?? j['speakingCue'] ?? ''}'.trim(),
      speakingHints:
          '${j['speaking_hints'] ?? j['speakingHints'] ?? ''}'.trim(),
      generatedAtUtc: DateTime.tryParse('${j['generated_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'paper_id': paperId,
        'title': title,
        'article_preview': articlePreview,
        'article_full': articleFull,
        'reading': reading
            .map((NewsMockReadingQuestion q) => q.toJson())
            .toList(),
        'writing_prompt': writingPrompt,
        'speaking_cue': speakingCue,
        'speaking_hints': speakingHints,
        if (generatedAtUtc != null)
          'generated_at': generatedAtUtc!.toUtc().toIso8601String(),
      };
}

// --- Grade ---

class NewsMockReadingGradeItem {
  const NewsMockReadingGradeItem({
    required this.indexOneBased,
    required this.userChoiceIndex,
    required this.userChoiceLabel,
    required this.correct,
    required this.correctChoiceLabel,
    required this.explanationZh,
  });

  final int indexOneBased;
  final int? userChoiceIndex;
  final String userChoiceLabel;
  final bool correct;
  final String correctChoiceLabel;
  final String explanationZh;
}

class NewsMockWritingGrade {
  const NewsMockWritingGrade({
    required this.taskResponse,
    required this.coherence,
    required this.lexical,
    required this.grammar,
    required this.overall,
    required this.feedbackZh,
  });

  final double taskResponse;
  final double coherence;
  final double lexical;
  final double grammar;
  final double overall;
  final String feedbackZh;
}

class NewsMockSpeakingGrade {
  const NewsMockSpeakingGrade({
    required this.fluency,
    required this.lexical,
    required this.grammar,
    required this.pronunciation,
    required this.overall,
    required this.feedbackZh,
  });

  final double fluency;
  final double lexical;
  final double grammar;
  final double pronunciation;
  final double overall;
  final String feedbackZh;
}

class NewsMockGradeResult {
  const NewsMockGradeResult({
    required this.readingItems,
    required this.readingCorrectCount,
    required this.writing,
    required this.speaking,
    required this.summaryZh,
  });

  final List<NewsMockReadingGradeItem> readingItems;
  final int readingCorrectCount;
  final NewsMockWritingGrade writing;
  final NewsMockSpeakingGrade speaking;
  final String summaryZh;
}

/// 每日练习模块 · 写作 Task1+Task2 合一批改。
class DailyWritingAiGrade {
  const DailyWritingAiGrade({
    required this.taskResponse,
    required this.coherence,
    required this.lexical,
    required this.grammar,
    required this.overall,
    required this.feedbackZh,
    this.task1FeedbackZh,
    this.task2FeedbackZh,
  });

  final double taskResponse;
  final double coherence;
  final double lexical;
  final double grammar;
  final double overall;
  final String feedbackZh;
  final String? task1FeedbackZh;
  final String? task2FeedbackZh;
}

/// 每日练习模块 · 口语真题演练 AI 点评。
class DailySpeakingAiGrade {
  const DailySpeakingAiGrade({
    required this.fluency,
    required this.lexical,
    required this.grammar,
    required this.pronunciation,
    required this.overall,
    required this.feedbackZh,
  });

  final double fluency;
  final double lexical;
  final double grammar;
  final double pronunciation;
  final double overall;
  final String feedbackZh;
}

/// 环球快讯模考：每日全员同卷由服务端/静态资源分发；客户端 [loadDailyPaperSharedByAllUsers] 拉取。
/// [generatePaper] 仅供运维或脚本生成 JSON；批改仍可走百炼 [gradeSubmission]。
class NewsMockAIService {
  NewsMockAIService({String? apiKey, String? model})
      : _apiKey = apiKey ?? kDashScopeApiKey,
        _model = model ?? kDefaultDashScopeModel;

  final String _apiKey;
  final String _model;

  static const String _kPrefsDailyJsonPrefix = 'news_mock_daily_json_v1_';

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  /// 东八区日历日 `yyyy-MM-dd`，与分发文件名一致，保证全员同一天键。
  static String chinaCalendarDateKey() {
    final DateTime utc = DateTime.now().toUtc();
    final DateTime china = utc.add(const Duration(hours: 8));
    return '${china.year}-${china.month.toString().padLeft(2, '0')}-${china.day.toString().padLeft(2, '0')}';
  }

  /// 无密钥或未联网时使用内置演示试卷。
  NewsMockPaper fallbackPaper() => _staticFallbackPaper();

  /// 加载「当日全员同一份」试卷：优先本地缓存 → HTTP 分发地址 → 内置演示卷。
  /// 需在构建时配置 [kNewsMockDailyBaseUrl] 或 [kNewsMockDailyUrlPattern]。
  Future<NewsMockPaper> loadDailyPaperSharedByAllUsers() async {
    return loadPaperForChinaCalendarDate(chinaCalendarDateKey());
  }

  /// 指定东八区日历日 `yyyy-MM-dd` 的语料卷（Pro 可模考往期）；校验格式后与全日员卷同源加载逻辑。
  Future<NewsMockPaper> loadPaperForChinaCalendarDate(String dateKey) async {
    final RegExp re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!re.hasMatch(dateKey)) {
      throw ArgumentError('dateKey 须为 yyyy-MM-dd');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String cacheKey = '$_kPrefsDailyJsonPrefix$dateKey';
    final String? cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final Object? raw = jsonDecode(cached);
        if (raw is Map<String, dynamic>) {
          final NewsMockPaper paper = NewsMockPaper.fromJson(raw);
          if (paper.articleFull.isNotEmpty && paper.reading.length == 5) {
            return paper;
          }
        }
      } on Object catch (_) {}
    }

    final Uri? uri = _dailyPaperUri(dateKey);
    if (uri == null) {
      return fallbackPaper();
    }

    try {
      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final String body = utf8.decode(res.bodyBytes);
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('响应不是 JSON 对象');
      }
      final NewsMockPaper paper = NewsMockPaper.fromJson(decoded);
      if (paper.articleFull.isEmpty || paper.reading.length != 5) {
        throw StateError('试卷不完整');
      }
      await prefs.setString(cacheKey, body);
      return paper;
    } on Object {
      if (cached != null && cached.isNotEmpty) {
        try {
          final Object? raw = jsonDecode(cached);
          if (raw is Map<String, dynamic>) {
            return NewsMockPaper.fromJson(raw);
          }
        } on Object catch (_) {}
      }
      return fallbackPaper();
    }
  }

  Uri? _dailyPaperUri(String dateKey) {
    final String pattern = kNewsMockDailyUrlPattern.trim();
    if (pattern.isNotEmpty) {
      return Uri.parse(pattern.replaceAll('{date}', dateKey));
    }
    final String base = kNewsMockDailyBaseUrl.trim();
    if (base.isEmpty) return null;
    final String normalized =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized/news_mock_daily_$dateKey.json');
  }

  /// 运维/脚本：调用模型生成一份可上传分发的 JSON（勿在正式 App 首屏对每用户调用）。
  Future<NewsMockPaper> generatePaper() async {
    if (!hasApiKey) {
      return fallbackPaper();
    }
    final String raw = await _chatCompletion(<Map<String, String>>[
      Map<String, String>.from(<String, String>{
        'role': 'system',
        'content':
            'You are an IELTS content designer. Output MUST be valid JSON only, no markdown fences.',
      }),
      Map<String, String>.from(<String, String>{
        'role': 'user',
        'content': _generatePrompt(),
      }),
    ]);
    final Map<String, dynamic>? json = _extractJsonObject(raw);
    if (json == null) {
      throw StateError('模型返回无法解析为 JSON：${raw.length > 200 ? raw.substring(0, 200) : raw}');
    }
    final NewsMockPaper paper = NewsMockPaper.fromJson(json);
    if (paper.articleFull.isEmpty || paper.reading.length != 5) {
      throw StateError('生成结果不完整（需要正文与 5 道阅读题）');
    }
    return paper;
  }

  /// 无 API Key 时用本地标准答案比对阅读；写作/口语为简短占位反馈。
  NewsMockGradeResult gradeSubmissionLocal({
    required NewsMockPaper paper,
    required List<int?> readingChoiceIndices,
    required String essayText,
    required String speakingText,
    bool feedbackEnglish = false,
  }) {
    final List<NewsMockReadingGradeItem> items = <NewsMockReadingGradeItem>[];
    int correct = 0;
    for (int i = 0; i < paper.reading.length; i++) {
      final NewsMockReadingQuestion q = paper.reading[i];
      final int? userIdx =
          i < readingChoiceIndices.length ? readingChoiceIndices[i] : null;
      final int? ci = q.correctIndex;
      final bool ok =
          ci != null && userIdx != null && ci == userIdx && userIdx >= 0;
      if (ok) correct++;
      String userLabel = feedbackEnglish ? 'Not answered' : '未作答';
      if (userIdx != null &&
          userIdx >= 0 &&
          userIdx < q.options.length) {
        userLabel = _optionLabelForQuestion(q, userIdx);
      }
      String correctLabel = '—';
      if (ci != null && ci >= 0 && ci < q.options.length) {
        correctLabel = _optionLabelForQuestion(q, ci);
      }
      items.add(
        NewsMockReadingGradeItem(
          indexOneBased: i + 1,
          userChoiceIndex: userIdx,
          userChoiceLabel: userLabel,
          correct: ok,
          correctChoiceLabel: correctLabel,
          explanationZh: q.answerExplanation ??
              (ok
                  ? (feedbackEnglish
                      ? 'Matches the correct answer.'
                      : '与标准答案一致。')
                  : (feedbackEnglish
                      ? 'Review the passage and options again.'
                      : '请对照原文与选项再次确认。')),
        ),
      );
    }
    final int words = essayText.trim().isEmpty
        ? 0
        : essayText.trim().split(RegExp(r'\s+')).length;
    final NewsMockWritingGrade wg = NewsMockWritingGrade(
      taskResponse: words >= 250 ? 6.0 : 5.0,
      coherence: 5.5,
      lexical: 5.5,
      grammar: 5.5,
      overall: words >= 250 ? 5.5 : 5.0,
      feedbackZh: feedbackEnglish
          ? 'DashScope API key not configured — placeholder writing feedback. Configure DASHSCOPE_API_KEY for full AI grading. Word count ≈ $words.'
          : '当前未连接百炼 API，此为占位反馈。请配置 DASHSCOPE_API_KEY 后获得完整写作批改。字数约 $words。',
    );
    final NewsMockSpeakingGrade sg = NewsMockSpeakingGrade(
      fluency: speakingText.trim().length >= 80 ? 6.0 : 5.0,
      lexical: 5.5,
      grammar: 5.5,
      pronunciation: 5.5,
      overall: speakingText.trim().isEmpty ? 4.0 : 5.5,
      feedbackZh: speakingText.trim().isEmpty
          ? (feedbackEnglish
              ? 'No speaking text submitted — add notes or connect the DashScope API for detailed feedback.'
              : '未提交口语文本，无法详评。请填写口述要点或连接百炼 API。')
          : (feedbackEnglish
              ? 'DashScope API key not configured — placeholder speaking feedback. Configure the key for criterion-by-criterion comments.'
              : '当前未连接百炼 API，此为占位反馈。配置密钥后可获得分项口语评价。'),
    );
    return NewsMockGradeResult(
      readingItems: items,
      readingCorrectCount: correct,
      writing: wg,
      speaking: sg,
      summaryZh: feedbackEnglish
          ? 'Local mode: reading checked against built-in keys ($correct/5). Connect DashScope for full AI grading.'
          : '本地模式：阅读按内置答案核对（$correct/5）。连接阿里云百炼后可使用完整 AI 批改。',
    );
  }

  String _optionLabelForQuestion(NewsMockReadingQuestion q, int index) {
    if (q.optionTags != null &&
        index < q.optionTags!.length &&
        q.optionTags![index].isNotEmpty) {
      return q.optionTags![index];
    }
    return String.fromCharCode(65 + index);
  }

  /// 客户端直连 DashScope（`flutter run/build ... --dart-define=DASHSCOPE_API_KEY=`）。
  /// 返回 JSON 中含 **`writing`**：分项分数与 `feedback` 为对用户提交的 **英文作文**（环球快讯 Task 2）的 AI 评价。
  /// 无密钥时不会发起 HTTP 请求，改为 [gradeSubmissionLocal]（写作为简短占位说明）。
  Future<NewsMockGradeResult> gradeSubmission({
    required NewsMockPaper paper,
    required List<int?> readingChoiceIndices,
    required String essayText,
    required String speakingText,
    bool feedbackEnglish = false,
  }) async {
    if (!hasApiKey) {
      return gradeSubmissionLocal(
        paper: paper,
        readingChoiceIndices: readingChoiceIndices,
        essayText: essayText,
        speakingText: speakingText,
        feedbackEnglish: feedbackEnglish,
      );
    }
    final String raw = await _chatCompletion(
      <Map<String, String>>[
        Map<String, String>.from(<String, String>{
          'role': 'system',
          'content': feedbackEnglish
              ? 'You are an IELTS examiner. Output JSON only. Use English for every narrative field: reading explanations, writing/speaking feedback paragraphs, and the overall summary.'
              : 'You are an IELTS examiner. Respond with JSON only. Use Chinese (简体中文) for all explanations and feedback fields.',
        }),
        Map<String, String>.from(<String, String>{
          'role': 'user',
          'content': _gradePrompt(
            paper: paper,
            readingChoiceIndices: readingChoiceIndices,
            essayText: essayText,
            speakingText: speakingText,
            feedbackEnglish: feedbackEnglish,
          ),
        }),
      ],
      maxTokens: 8192,
    );
    final Map<String, dynamic>? json = _extractJsonObject(raw);
    if (json == null) {
      throw StateError('批改结果无法解析为 JSON');
    }
    return _parseGradeJson(
      json,
      paper,
      readingChoiceIndices,
      feedbackEnglish: feedbackEnglish,
    );
  }

  Future<String> _chatCompletion(
    List<Map<String, String>> messages, {
    double temperature = 0.4,
    int maxTokens = 2048,
  }) async {
    final http.Response res = await http
        .post(
          Uri.parse(_dashScopeChatUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: utf8.encode(
            jsonEncode(<String, dynamic>{
              'model': _model,
              'messages': messages,
              'temperature': temperature,
              'max_tokens': maxTokens,
            }),
          ),
        )
        .timeout(const Duration(seconds: 180));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('DashScope HTTP ${res.statusCode}: ${utf8.decode(res.bodyBytes)}');
    }
    final Object? decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('DashScope 响应格式异常');
    }
    final List<dynamic>? choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('DashScope 无 choices');
    }
    final Object? msg = (choices.first as Map<String, dynamic>)['message'];
    if (msg is! Map<String, dynamic>) {
      throw StateError('DashScope 无 message');
    }
    final String content = '${msg['content'] ?? ''}'.trim();
    if (content.isEmpty) {
      throw StateError('模型返回空内容');
    }
    return content;
  }

  NewsMockGradeResult _parseGradeJson(
    Map<String, dynamic> json,
    NewsMockPaper paper,
    List<int?> readingChoiceIndices, {
    bool feedbackEnglish = false,
  }) {
    final Map<String, dynamic>? writingMap =
        json['writing'] as Map<String, dynamic>? ??
            json['writing_grade'] as Map<String, dynamic>?;
    final Map<String, dynamic>? speakingMap =
        json['speaking'] as Map<String, dynamic>? ??
            json['speaking_grade'] as Map<String, dynamic>?;

    final NewsMockWritingGrade wg = NewsMockWritingGrade(
      taskResponse: _pickIeltsBandFromJsonScoped(
        json,
        writingMap,
        <String>['task_response', 'TR', 'tr', 'taskResponse', 'task_achievement'],
      ),
      coherence: _pickIeltsBandFromJsonScoped(
        json,
        writingMap,
        <String>['coherence', 'CC', 'cc', 'coherence_and_cohesion'],
      ),
      lexical: _pickIeltsBandFromJsonScoped(
        json,
        writingMap,
        <String>['lexical', 'LR', 'lr', 'lexical_resource'],
      ),
      grammar: _pickIeltsBandFromJsonScoped(
        json,
        writingMap,
        <String>['grammar', 'GRA', 'gra', 'grammatical_range'],
      ),
      overall: _pickIeltsBandFromJsonScoped(
        json,
        writingMap,
        <String>['overall', 'band', 'overall_band', 'score'],
      ),
      feedbackZh:
          '${writingMap?['feedback'] ?? writingMap?['feedback_en'] ?? writingMap?['feedback_zh'] ?? ''}'.trim(),
    );

    final NewsMockSpeakingGrade sg = NewsMockSpeakingGrade(
      fluency: _pickIeltsBandFromJsonScoped(
        json,
        speakingMap,
        <String>['fluency', 'fc', 'fluency_and_coherence'],
      ),
      lexical: _pickIeltsBandFromJsonScoped(json, speakingMap, <String>['lexical', 'lr']),
      grammar: _pickIeltsBandFromJsonScoped(json, speakingMap, <String>['grammar']),
      pronunciation: _pickIeltsBandFromJsonScoped(
        json,
        speakingMap,
        <String>['pronunciation', 'pr', 'pron'],
      ),
      overall: _pickIeltsBandFromJsonScoped(json, speakingMap, <String>['overall', 'band']),
      feedbackZh:
          '${speakingMap?['feedback'] ?? speakingMap?['feedback_en'] ?? speakingMap?['feedback_zh'] ?? ''}'.trim(),
    );

    final List<NewsMockReadingGradeItem> items = <NewsMockReadingGradeItem>[];
    int correct = 0;
    final List<dynamic>? rlist =
        json['reading'] as List<dynamic>? ?? json['reading_results'] as List<dynamic>?;

    for (int i = 0; i < paper.reading.length; i++) {
      final int idx = i + 1;
      final int? userIdx =
          i < readingChoiceIndices.length ? readingChoiceIndices[i] : null;
      String userLabel = feedbackEnglish ? 'Not answered' : '未作答';
      if (userIdx != null &&
          userIdx >= 0 &&
          userIdx < paper.reading[i].options.length) {
        userLabel = _optionLabelForQuestion(paper.reading[i], userIdx);
      }
      String explain = '';
      String correctLabel = '';
      bool ok = false;
      if (rlist != null && i < rlist.length && rlist[i] is Map<String, dynamic>) {
        final Map<String, dynamic> rm = rlist[i] as Map<String, dynamic>;
        ok = rm['correct'] == true || rm['is_correct'] == true;
        explain =
            '${rm['explanation'] ?? rm['explanation_en'] ?? rm['explanation_zh'] ?? ''}'.trim();
        correctLabel = '${rm['correct_answer'] ?? rm['correct_label'] ?? ''}'.trim();
      } else {
        final int? ci = paper.reading[i].correctIndex;
        if (ci != null &&
            userIdx != null &&
            ci >= 0 &&
            ci < paper.reading[i].options.length) {
          ok = ci == userIdx;
          correctLabel = _optionLabelForQuestion(paper.reading[i], ci);
          explain = paper.reading[i].answerExplanation ?? '';
        }
      }
      if (ok) correct++;
      items.add(
        NewsMockReadingGradeItem(
          indexOneBased: idx,
          userChoiceIndex: userIdx,
          userChoiceLabel: userLabel,
          correct: ok,
          correctChoiceLabel: correctLabel.isEmpty ? '—' : correctLabel,
          explanationZh: explain.isEmpty
              ? (feedbackEnglish ? 'See explanation above.' : '见题目解析。')
              : explain,
        ),
      );
    }

    return NewsMockGradeResult(
      readingItems: items,
      readingCorrectCount: correct,
      writing: wg,
      speaking: sg,
      summaryZh:
          '${json['summary'] ?? json['summary_en'] ?? json['summary_zh'] ?? ''}'.trim(),
    );
  }

  /// 听说读写 · 写作全真（Task1 + Task2）批改；**两篇考生英文作文**的点评由 DashScope 生成（客户端直连，需 `--dart-define=DASHSCOPE_API_KEY`）。
  Future<DailyWritingAiGrade> gradeDailyWritingFullExam({
    required String task1Prompt,
    required String task2Prompt,
    required String task1Essay,
    required String task2Essay,
    bool feedbackEnglish = false,
  }) async {
    if (!hasApiKey) {
      throw StateError('未配置 DASHSCOPE_API_KEY');
    }
    final String userPrompt = feedbackEnglish
        ? '''
Assess Task 1 and Task 2 using IELTS Writing criteria (TR/CC/LR/GRA). Output ONE JSON object (no markdown).

【Task 1 prompt】
$task1Prompt

【Task 1 essay】
$task1Essay

【Task 2 prompt】
$task2Prompt

【Task 2 essay】
$task2Essay

Schema (required — use JSON numbers for scores, NOT strings; place scores at top level):
{
  "task_response": 6.5,
  "coherence": 6.5,
  "lexical": 6.5,
  "grammar": 6.5,
  "overall": 6.5,
  "feedback": "English: overall summary with rewrite suggestions",
  "task1_feedback": "English: detailed Task 1 comments",
  "task2_feedback": "English: detailed Task 2 comments"
}

Bands 0–9, halves allowed. You MUST assign task_response, coherence, lexical, grammar, and overall yourself from the two essays (do not omit or leave default). Weight Task 2 more heavily in overall if appropriate.
'''
        : '''
请根据雅思写作四项评分标准（TR/CC/LR/GRA）评估下列 Task1 与 Task2。输出一个 JSON 对象（不要 markdown）。

【Task 1 题干】
$task1Prompt

【Task 1 考生作文】
$task1Essay

【Task 2 题干】
$task2Prompt

【Task 2 考生作文】
$task2Essay

输出格式（**分项与总分必须为 JSON 数字**，不要用字符串；字段放在根级）：
{
  "task_response": 6.5,
  "coherence": 6.5,
  "lexical": 6.5,
  "grammar": 6.5,
  "overall": 6.5,
  "feedback": "中文总评与改写建议（合并）",
  "task1_feedback": "中文：针对 Task1 的具体点评",
  "task2_feedback": "中文：针对 Task2 的具体点评"
}

你必须根据两篇作文真实打出 task_response、coherence、lexical、grammar、overall 五项分数（不得省略或使用占位）。分数均为雅思 0–9，可为半分。overall 建议 Task2 权重更高。
''';
    final String raw = await _chatCompletion(
      <Map<String, String>>[
        Map<String, String>.from(<String, String>{
          'role': 'system',
          'content': feedbackEnglish
              ? 'You are an IELTS writing examiner. Respond with JSON only. Use English for feedback, task1_feedback, and task2_feedback. '
                  'Include numeric scores task_response, coherence, lexical, grammar, overall as JSON numbers (0–9, halves allowed), judged from the essays.'
              : 'You are an IELTS writing examiner. Respond with JSON only. Use Chinese (简体中文) for all feedback text fields. '
                  '必须在 JSON 根级给出 task_response、coherence、lexical、grammar、overall 五项分数（数字类型，雅思 0–9，可为半分），并根据两篇作文真实打分。',
        }),
        Map<String, String>.from(<String, String>{
          'role': 'user',
          'content': userPrompt,
        }),
      ],
      maxTokens: 4096,
    );
    final Map<String, dynamic>? json = _extractJsonObject(raw);
    if (json == null) {
      throw StateError('写作批改 JSON 解析失败');
    }

    return DailyWritingAiGrade(
      taskResponse: _pickIeltsBandFromJson(
        json,
        <String>[
          'task_response',
          'TR',
          'tr',
          'taskResponse',
          'task_achievement',
        ],
      ),
      coherence: _pickIeltsBandFromJson(
        json,
        <String>['coherence', 'CC', 'cc', 'coherence_and_cohesion'],
      ),
      lexical: _pickIeltsBandFromJson(
        json,
        <String>[
          'lexical',
          'LR',
          'lr',
          'lexical_resource',
          'lexical_resources',
        ],
      ),
      grammar: _pickIeltsBandFromJson(
        json,
        <String>[
          'grammar',
          'GRA',
          'gra',
          'grammatical_range',
          'grammatical_range_and_accuracy',
        ],
      ),
      overall: _pickIeltsBandFromJson(
        json,
        <String>[
          'overall',
          'band',
          'overall_band',
          'total',
          'weighted_overall',
          'score',
        ],
      ),
      feedbackZh:
          '${json['feedback'] ?? json['feedback_en'] ?? json['feedback_zh'] ?? ''}'.trim(),
      task1FeedbackZh: '${json['task1_feedback'] ?? json['task1_feedback_en'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['task1_feedback'] ?? json['task1_feedback_en']}'.trim(),
      task2FeedbackZh: '${json['task2_feedback'] ?? json['task2_feedback_en'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['task2_feedback'] ?? json['task2_feedback_en']}'.trim(),
    );
  }

  /// 口语真题演练：基于题目与考生自述文本稿点评（第二引擎：规则估分为辅时可并列展示）。
  /// 若无文本稿仅有录音，请先使用语音识别或请考生听写要点。
  Future<DailySpeakingAiGrade> gradeDailySpeakingExam({
    required String cue,
    required String transcript,
    Duration? recordingDuration,
    bool feedbackEnglish = false,
  }) async {
    if (!hasApiKey) {
      throw StateError('未配置 DASHSCOPE_API_KEY');
    }
    final String dur = recordingDuration == null
        ? (feedbackEnglish ? 'unknown' : '未知')
        : (feedbackEnglish
            ? '${recordingDuration.inMinutes}m ${recordingDuration.inSeconds % 60}s'
            : '${recordingDuration.inMinutes}分${recordingDuration.inSeconds % 60}秒');
    final String userPrompt = feedbackEnglish
        ? '''
Speaking cue:
$cue

Candidate transcript (typed or ASR):
$transcript

Approx. recording duration: $dur

Return JSON only (no markdown). Score IELTS Speaking Part 2–style from the text (pronunciation is inferred without audio):
{
  "fluency": 0,
  "lexical": 0,
  "grammar": 0,
  "pronunciation": 0,
  "overall": 0,
  "feedback": "English: ≥300 words; criterion-by-criterion with examples, errors, drills; state that pronunciation is estimated from text only."
}
Bands 0–9, halves allowed.
'''
        : '''
口语题目 / Cue:
$cue

考生自述文本稿（可能来自听写或 ASR）:
$transcript

录音时长参考: $dur

请按雅思口语四项（流利度与连贯性、词汇、语法、发音）输出 JSON（不要 markdown）：
{
  "fluency": 0,
  "lexical": 0,
  "grammar": 0,
  "pronunciation": 0,
  "overall": 0,
  "feedback": "中文：不少于 350 字的全方位详评；分项给出例证、典型错误与可执行练习；若仅有文本无音频，须说明发音分为推断。"
}
分数为 0–9，可为半分。
''';
    final String raw = await _chatCompletion(
      <Map<String, String>>[
        Map<String, String>.from(<String, String>{
          'role': 'system',
          'content': feedbackEnglish
              ? 'You are an IELTS speaking examiner. Respond with JSON only. Use English for the feedback field. If only a transcript is available, pronunciation must be explicitly marked as approximate.'
              : 'You are an IELTS speaking examiner. Respond with JSON only. Use Chinese (简体中文) for feedback. Pronunciation score may be approximate when only text transcript is available.',
        }),
        Map<String, String>.from(<String, String>{
          'role': 'user',
          'content': userPrompt,
        }),
      ],
      maxTokens: 4096,
    );
    final Map<String, dynamic>? json = _extractJsonObject(raw);
    if (json == null) {
      throw StateError('口语批改 JSON 解析失败');
    }

    return DailySpeakingAiGrade(
      fluency: _pickIeltsBandFromJson(json, <String>['fluency', 'fc', 'fluency_and_coherence']),
      lexical: _pickIeltsBandFromJson(json, <String>['lexical', 'lr']),
      grammar: _pickIeltsBandFromJson(json, <String>['grammar']),
      pronunciation: _pickIeltsBandFromJson(json, <String>['pronunciation', 'pr', 'pron']),
      overall: _pickIeltsBandFromJson(json, <String>['overall', 'band']),
      feedbackZh:
          '${json['feedback'] ?? json['feedback_en'] ?? json['feedback_zh'] ?? ''}'.trim(),
    );
  }

  /// 无 API Key 时口语本地占位估分（仅供兜底）。
  DailySpeakingAiGrade gradeDailySpeakingLocal({
    required String cue,
    required String transcript,
    Duration? recordingDuration,
    bool feedbackEnglish = false,
  }) {
    final int n = transcript.trim().length;
    final double base = n >= 200 ? 6.0 : (n >= 80 ? 5.5 : 5.0);
    return DailySpeakingAiGrade(
      fluency: base,
      lexical: base - 0.5,
      grammar: base - 0.5,
      pronunciation: base - 0.5,
      overall: base,
      feedbackZh: feedbackEnglish
          ? 'DashScope API key not configured — placeholder speaking feedback. Configure DASHSCOPE_API_KEY for full scoring. Transcript length ≈ $n characters.'
          : '当前未连接百炼 API，此为占位反馈。请配置 DASHSCOPE_API_KEY 后获得完整点评。文本长度约 $n 字。',
    );
  }

  /// 全科批改：优先在 `writing` / `speaking` 子对象中取分，避免与另一科的同名字段混淆。
  static double _pickIeltsBandFromJsonScoped(
    Map<String, dynamic> root,
    Map<String, dynamic>? primary,
    List<String> keys,
  ) {
    if (primary != null) {
      final double? scoped = _pickBandFromSingleMap(primary, keys);
      if (scoped != null) {
        return scoped;
      }
    }
    return _pickIeltsBandFromJson(root, keys);
  }

  static double? _pickBandFromSingleMap(Map<String, dynamic> m, List<String> keys) {
    for (final String key in keys) {
      for (final String kk in <String>{key, key.toLowerCase()}) {
        final double? d = _jsonBandToDouble(m[kk]);
        if (d != null) {
          return _clampIeltsBand(d);
        }
      }
    }
    return null;
  }

  /// 从模型返回的 JSON（含嵌套 `scores`/`writing`、字符串数字）中提取分项分数。
  static double _pickIeltsBandFromJson(Map<String, dynamic> root, List<String> keys) {
    for (final Map<String, dynamic> m in _gradeJsonNestedMaps(root)) {
      for (final String key in keys) {
        for (final String kk in <String>{key, key.toLowerCase()}) {
          final double? d = _jsonBandToDouble(m[kk]);
          if (d != null) {
            return _clampIeltsBand(d);
          }
        }
      }
    }
    return 6.0;
  }

  static List<Map<String, dynamic>> _gradeJsonNestedMaps(Map<String, dynamic> root) {
    final List<Map<String, dynamic>> maps = <Map<String, dynamic>>[root];
    for (final String nestedKey in <String>[
      'writing',
      'speaking',
      'scores',
      'bands',
      'writing_grade',
      'speaking_grade',
      'criteria',
      'result',
      'data',
      'grade',
      'task1_task2',
    ]) {
      final Object? o = root[nestedKey];
      if (o is Map<String, dynamic>) {
        maps.add(o);
      }
    }
    return maps;
  }

  static double? _jsonBandToDouble(Object? v) {
    if (v == null) {
      return null;
    }
    if (v is num) {
      return v.toDouble();
    }
    if (v is String) {
      final String t = v.trim();
      final RegExp re = RegExp(r'[-+]?\d+(?:\.\d+)?');
      final Match? m = re.firstMatch(t);
      if (m != null) {
        return double.tryParse(m.group(0)!);
      }
    }
    return null;
  }

  static double _clampIeltsBand(double v) {
    if (v.isNaN) {
      return 6.0;
    }
    if (v < 0) {
      return 0;
    }
    if (v > 9) {
      return 9;
    }
    return v;
  }

  static Map<String, dynamic>? _extractJsonObject(String raw) {
    String s = raw.trim();
    final int fence = s.indexOf('```');
    if (fence != -1) {
      final int start = s.indexOf('{', fence);
      final int end = s.lastIndexOf('}');
      if (start != -1 && end > start) {
        s = s.substring(start, end + 1);
      }
    }
    final int start = s.indexOf('{');
    final int end = s.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    s = s.substring(start, end + 1);
    try {
      final Object? o = jsonDecode(s);
      return o is Map<String, dynamic> ? o : null;
    } on Object catch (_) {
      return null;
    }
  }

  String _generatePrompt() {
    final String day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return '''
请基于近几日国际新闻主题（科技、环境、教育、健康、经济民生等），合成一篇适合雅思 Academic Reading 难度的英文语料，长度约 650-900 词。
严禁涉及政治、军事、暴力恐怖、宗教冲突、敏感地缘话题；若材料疑似敏感则改写为中立科普/产业视角。

请仅输出一个 JSON 对象（不要 markdown），字段与要求如下：
{
  "paper_id": "字符串，可用日期+随机后缀",
  "title": "英文标题",
  "article_preview": "英文，截取正文前约 120 词，末尾用 …",
  "article_full": "完整英文正文",
  "reading": [
    {
      "question": "题干英文；若为 TFNG 第一行写 TRUE / FALSE / NOT GIVEN:",
      "options": ["选项英文…"],
      "option_tags": ["T","F","NG"] 或 null；四选一题用 null,
      "correct_index": 0 表示 options 中正确项下标,
      "explanation": "简短英文解析（一句）"
    }
  ],
  "writing_prompt": "英文 Task2 提示（讨论类）",
  "speaking_cue": "英文 Part2 主问题一句",
  "speaking_hints": "英文 bullet 提示（You should say …）",
  "generated_at": "$day"
}

要求 reading 数组恰好 5 题：其中第 1 题为 TRUE/FALSE/NOT GIVEN（3 选项）；其余 4 题为四选一（4 选项）。所有题目必须可根据 article_full 作答。
''';
  }

  String _gradePrompt({
    required NewsMockPaper paper,
    required List<int?> readingChoiceIndices,
    required String essayText,
    required String speakingText,
    required bool feedbackEnglish,
  }) {
    final StringBuffer readingDesc = StringBuffer();
    for (int i = 0; i < paper.reading.length; i++) {
      final NewsMockReadingQuestion q = paper.reading[i];
      final int? u = i < readingChoiceIndices.length ? readingChoiceIndices[i] : null;
      readingDesc.writeln('Q${i + 1}: ${q.question}');
      readingDesc.writeln('Options: ${q.options.join(" | ")}');
      readingDesc.writeln('User selected index: ${u ?? "null"}');
    }
    if (feedbackEnglish) {
      return '''
You are grading one full mock exam with the user's answers. Output ONE JSON object only (no markdown).

【Reading passage】
${paper.articleFull}

【Reading questions and candidate option indices】
$readingDesc

【Writing — candidate essay】
$essayText

【Speaking cue】
${paper.speakingCue}
${paper.speakingHints}

【Speaking — candidate text】 (notes or transcript)
$speakingText

JSON schema:
{
  "reading": [
    {
      "index": 1,
      "correct": true,
      "correct_answer": "Correct letter or T/F/NG tag",
      "explanation": "English explanation citing evidence from the passage"
    }
  ],
  "writing": {
    "task_response": 0,
    "coherence": 0,
    "lexical": 0,
    "grammar": 0,
    "overall": 0,
    "feedback": "Detailed English feedback and rewrite suggestions (at least ~250 words)"
  },
  "speaking": {
    "fluency": 0,
    "lexical": 0,
    "grammar": 0,
    "pronunciation": 0,
    "overall": 0,
    "feedback": "English: comprehensive feedback (≥300 words); cover FC/LR/GRA/PR with examples and actionable practice tips"
  },
  "summary": "One English paragraph summarising reading/writing/speaking performance and study priorities"
}

Bands are IELTS 0–9, halves allowed (e.g. 6.5). Reading "correct" must match the passage. Avoid vague praise; be specific.
''';
    }
    return '''
下面是同一套模考试卷与用户答案。请批改并只输出一个 JSON（不要 markdown）。

【阅读文章】
${paper.articleFull}

【阅读题与考生选项下标】
$readingDesc

【写作考生作文】
$essayText

【口语题】
${paper.speakingCue}
${paper.speakingHints}

【口语考生作答文本】（可能来自口述要点或转写）
$speakingText

请输出 JSON，结构如下：
{
  "reading": [
    {
      "index": 1,
      "correct": true,
      "correct_answer": "给出正确选项的字母或 T/F/NG 标签",
      "explanation": "中文解析，指出依据原文哪部分"
    }
  ],
  "writing": {
    "task_response": 0,
    "coherence": 0,
    "lexical": 0,
    "grammar": 0,
    "overall": 0,
    "feedback": "中文详细点评与改写建议（不少于 300 字）"
  },
  "speaking": {
    "fluency": 0,
    "lexical": 0,
    "grammar": 0,
    "pronunciation": 0,
    "overall": 0,
    "feedback": "中文：不少于 350 字的全方位详评；按流利度、词汇、语法、发音分项给出例证与可执行练习建议"
  },
  "summary": "中文总评一段（可含阅读/写作/口语整体策略）"
}

评分使用雅思 0-9，可为半分（如 6.5）。阅读 correct 需严格对照文章。写作与口语 feedback 均需充实细节，避免泛泛而谈。
''';
  }

  static NewsMockPaper _staticFallbackPaper() {
    return NewsMockPaper(
      paperId: 'local_fallback',
      title: 'AI breakthrough allows robots to evaluate context before acting',
      articlePreview:
          'A new generation of artificial intelligence is giving robots the ability to pause and evaluate their surroundings before executing a task. This marks a shift away from rigid instruction sets…',
      articleFull:
          'A new generation of artificial intelligence is giving robots the ability to pause and evaluate their surroundings before executing a task. This development marks a significant departure from traditional programming, where machines follow fixed rules regardless of environmental changes. Researchers have proposed a framework that introduces a deliberate "cognitive pause" before action.\n\n'
          'The implications range from safer autonomous systems to more adaptable manufacturing. Critics warn that greater autonomy also raises questions about predictability when scenarios are open-ended.',
      reading: const <NewsMockReadingQuestion>[
        NewsMockReadingQuestion(
          question:
              'TRUE / FALSE / NOT GIVEN:\nThe "Cognitive Pause" framework was developed by a team at Stanford University.',
          options: <String>['TRUE', 'FALSE', 'NOT GIVEN'],
          optionTags: <String>['T', 'F', 'NG'],
          correctIndex: 1,
        ),
        NewsMockReadingQuestion(
          question:
              'According to the passage, what is a key benefit of introducing a deliberate pause before robot action?',
          options: <String>[
            'It reduces hardware manufacturing costs.',
            'It allows robots to adapt to changing environments.',
            'It removes the need for human monitoring entirely.',
            'It guarantees identical behavior in all contexts.',
          ],
          correctIndex: 1,
        ),
        NewsMockReadingQuestion(
          question: 'Which concern is raised by critics in the article?',
          options: <String>[
            'The framework cannot be used outside laboratories.',
            'Robots may become slower than human workers in all tasks.',
            'Higher autonomy may reduce predictability in open-ended scenarios.',
            'Only large companies can access this framework.',
          ],
          correctIndex: 2,
        ),
        NewsMockReadingQuestion(
          question:
              'What does the passage suggest about potential applications of the framework?',
          options: <String>[
            'Only entertainment robots can benefit from it.',
            'It is mainly useful for social media recommendation systems.',
            'It may contribute to safer autonomous systems and flexible manufacturing.',
            'Its primary use is replacing human teachers in schools.',
          ],
          correctIndex: 2,
        ),
        NewsMockReadingQuestion(
          question:
              'Which statement best summarizes the overall tone of the article?',
          options: <String>[
            'Entirely pessimistic about AI development.',
            'Balanced: highlights both opportunities and unresolved risks.',
            'Focused only on economic profits.',
            'Purely technical with no social implications.',
          ],
          correctIndex: 1,
        ),
      ],
      writingPrompt:
          'Some people believe that robots with "cognitive" abilities will eventually replace humans in the workforce. Others argue they will create new categories of jobs.\n\nDiscuss both views and give your own opinion.',
      speakingCue:
          'Describe an intelligent machine or AI application you have used or heard about.',
      speakingHints:
          'You should say what it is, how it works, and explain how you feel about its impact.',
    );
  }
}
