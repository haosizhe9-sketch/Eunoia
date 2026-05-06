import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speaking_question_bank.dart';

/// 从 `resource/` 导入剑雅题库：听力 1 套 40 题；阅读 Test1–4 各 40 题；写作 1 套。
abstract final class DailyTaskResourceLoader {
  DailyTaskResourceLoader._();

  static const String _listeningAnswerPath = 'resource/听力答案及解析.md';
  static const String _readingPassagePath = 'resource/阅读.md';
  static const String _readingQaPath = 'resource/阅读答案及解析.md';
  static const String _readingTest1JsonPath = 'resource/reading_test1.json';
  static const String _writingPath = 'resource/写作.md';
  static const String _speakingPath = 'resource/口语.md';

  static const String listeningAudioAsset = 'resource/listening.mp3';
  static const String listeningMapImageAsset = 'resource/listening.png';
  static const String writingTask1ImageAsset = 'resource/writing.png';

  static Future<ListeningTaskContent> loadListening() async {
    final String ans = await rootBundle.loadString(_listeningAnswerPath);
    final Map<int, String> key = _parseListeningAnswerKey(ans);

    return ListeningTaskContent(
      part1Notes: _listeningPart1Notes,
      questions: _listeningQuestionsByPaper,
      answers: key,
    );
  }

  /// [testNumber] 取 1–4，对应 `阅读.md` 中 Test 区块。
  static Future<ReadingTaskContent> loadReading({int testNumber = 1}) async {
    final int t = testNumber.clamp(1, 4);
    final String passageFile = await rootBundle.loadString(_readingPassagePath);
    final Map<String, String> passages = _extractReadingPassagesForTest(passageFile, t);

    List<ReadingQuestionItem> items = <ReadingQuestionItem>[];
    try {
      final String jsonRaw = await rootBundle.loadString(_readingTest1JsonPath);
      items = _readingQuestionsFromStructuredJson(jsonRaw);
    } on Object catch (e, st) {
      debugPrint('Reading structured JSON load failed: $e\n$st');
      items = <ReadingQuestionItem>[];
    }
    if (items.length != 40) {
      final String qaFile = await rootBundle.loadString(_readingQaPath);
      items = _buildReadingQuestionsForTest(qaFile, t);
      if (items.length != 40) {
        debugPrint(
          'Reading import: Test $t expected 40 questions, got ${items.length}. '
          'Check reading_test1.json or 阅读答案及解析.md.',
        );
      }
    }

    return ReadingTaskContent(
      testNumber: t,
      passageA: passages['A'] ?? '',
      passageB: passages['B'] ?? '',
      passageC: passages['C'] ?? '',
      questions: items,
    );
  }

  static Future<WritingTaskContent> loadWriting() async {
    final String raw = await rootBundle.loadString(_writingPath);
    final RegExp task1 = RegExp(
      r'WRITING TASK 1\s*([\s\S]+?)(?=WRITING TASK 2)',
      caseSensitive: false,
    );
    // 勿用 `\Z` 结尾：在 Dart 中与全文组合时常无法匹配，导致 Task 2 整段丢失。
    final RegExp task2 = RegExp(
      r'WRITING TASK 2\s*([\s\S]+)',
      caseSensitive: false,
    );
    final Match? m1 = task1.firstMatch(raw);
    final Match? m2 = task2.firstMatch(raw);
    return WritingTaskContent(
      task1Body: (m1?.group(1) ?? '').trim(),
      task2Body: (m2?.group(1) ?? '').trim(),
      task1ImageAsset: writingTask1ImageAsset,
      modelEssayTask1: _task1Sample,
      modelEssayTask2: _task2Sample,
    );
  }

  static Future<SpeakingTaskContent> loadSpeaking() async {
    final String raw = await rootBundle.loadString(_speakingPath);
    final ({List<String> part1, List<String> part2}) p = SpeakingQuestionBank.parseMarkdown(raw);
    return SpeakingTaskContent(part1Questions: p.part1, part2CueCards: p.part2);
  }

  /// 与 [loadSpeaking] 同源题库，供匿名语聊等模块随机破冰话题。
  static Future<List<String>> loadSpeakingIcebreakerPool() async {
    final String raw = await rootBundle.loadString(_speakingPath);
    final ({List<String> part1, List<String> part2}) p = SpeakingQuestionBank.parseMarkdown(raw);
    final List<String> pool = SpeakingQuestionBank.allIcebreakerPool(p);
    if (pool.isEmpty) {
      return <String>[
        'Describe a memorable journey you have made.',
        'Do you like spending time by yourself?',
      ];
    }
    return pool;
  }

  // --- Listening helpers ---

  static Map<int, String> _parseListeningAnswerKey(String raw) {
    final Map<int, String> map = <int, String>{};
    for (final Match m in RegExp(r'(\d+)\.\s*\*\*([^*]+)\*\*').allMatches(raw)) {
      final int? n = int.tryParse(m.group(1)!);
      if (n != null && n >= 1 && n <= 40) {
        map[n] = m.group(2)!.trim();
      }
    }
    for (final Match m in RegExp(
      r'(\d+)\s*&\s*(\d+)（[^）]*）\s*：\*\*([A-Z\s]+)\*\*',
    ).allMatches(raw)) {
      final String letters = m.group(3)!.trim().replaceAll(RegExp(r'\s+'), ' ');
      map[int.parse(m.group(1)!)] = letters;
      map[int.parse(m.group(2)!)] = letters;
    }
    return map;
  }

  static const String _listeningPart1Notes =
      'Hinchingbrooke Country Park\n\n'
      'The park\n'
      'Area: (1) __________ hectares\n'
      'Habitats: wetland, grassland and woodland\n'
      'Wetland: lakes, ponds and a (2) __________\n'
      'Wildlife includes birds, insects and animals\n\n'
      'Subjects studied in educational visits include\n'
      'Science: Children look at (3) __________ about plants, etc.\n'
      'Geography: includes learning to use a (4) __________ and compass\n'
      'History: changes in land use\n'
      'Leisure and tourism: mostly concentrates on the park’s (5) __________\n'
      'Music: Children make (6) __________ with natural materials, and experiment with rhythm and speed.\n\n'
      'Benefits of outdoor educational visits\n'
      'They give children a feeling of (7) __________ that they may not have elsewhere.\n'
      'Children learn new (8) __________ and gain self-confidence.\n\n'
      'Practical issues\n'
      'Cost per child: (9) £ __________\n'
      'Adults, such as (10) __________, free';

  static const List<ListeningQuestion> _listeningQuestionsByPaper = <ListeningQuestion>[
    ListeningQuestion(number: 1, kind: ListeningQuestionKind.fillIn, stem: 'Area'),
    ListeningQuestion(number: 2, kind: ListeningQuestionKind.fillIn, stem: 'Wetland: lakes, ponds and a'),
    ListeningQuestion(number: 3, kind: ListeningQuestionKind.fillIn, stem: 'Children look at'),
    ListeningQuestion(number: 4, kind: ListeningQuestionKind.fillIn, stem: 'includes learning to use a'),
    ListeningQuestion(number: 5, kind: ListeningQuestionKind.fillIn, stem: 'mostly concentrates on the park’s'),
    ListeningQuestion(number: 6, kind: ListeningQuestionKind.fillIn, stem: 'Children make'),
    ListeningQuestion(number: 7, kind: ListeningQuestionKind.fillIn, stem: 'a feeling of'),
    ListeningQuestion(number: 8, kind: ListeningQuestionKind.fillIn, stem: 'Children learn new'),
    ListeningQuestion(number: 9, kind: ListeningQuestionKind.fillIn, stem: 'Cost per child: £'),
    ListeningQuestion(number: 10, kind: ListeningQuestionKind.fillIn, stem: 'Adults, such as'),
    ListeningQuestion(
      number: 11,
      kind: ListeningQuestionKind.mcq,
      stem: 'During the visit to Malatte, in France, members especially enjoyed',
      options: <String, String>{
        'A': 'going to a theme park.',
        'B': 'experiencing a river trip.',
        'C': 'visiting a cheese factory.',
      },
    ),
    ListeningQuestion(
      number: 12,
      kind: ListeningQuestionKind.mcq,
      stem: 'What will happen in Stanthorpe to mark the 25th anniversary of the Twinning Association?',
      options: <String, String>{
        'A': 'A tree will be planted.',
        'B': 'A garden seat will be bought.',
        'C': 'A footbridge will be built.',
      },
    ),
    ListeningQuestion(
      number: 13,
      kind: ListeningQuestionKind.mcq,
      stem: 'Which event raised most funds this year?',
      options: <String, String>{
        'A': 'the film show',
        'B': 'the pancake evening',
        'C': 'the cookery demonstration',
      },
    ),
    ListeningQuestion(
      number: 14,
      kind: ListeningQuestionKind.mcq,
      stem: 'For the first evening with the French visitors host families are advised to',
      options: <String, String>{
        'A': 'take them for a walk round the town.',
        'B': 'go to a local restaurant.',
        'C': 'have a meal at home.',
      },
    ),
    ListeningQuestion(
      number: 15,
      kind: ListeningQuestionKind.mcq,
      stem: 'On Saturday evening there will be the chance to',
      options: <String, String>{
        'A': 'listen to a concert.',
        'B': 'watch a match.',
        'C': 'take part in a competition.',
      },
    ),
    ListeningQuestion(number: 16, kind: ListeningQuestionKind.mapLetter, stem: 'Farm shop'),
    ListeningQuestion(number: 17, kind: ListeningQuestionKind.mapLetter, stem: 'Disabled entry'),
    ListeningQuestion(number: 18, kind: ListeningQuestionKind.mapLetter, stem: 'Adventure playground'),
    ListeningQuestion(number: 19, kind: ListeningQuestionKind.mapLetter, stem: 'Kitchen gardens'),
    ListeningQuestion(number: 20, kind: ListeningQuestionKind.mapLetter, stem: 'The Temple of the Four Winds'),
    ListeningQuestion(
      number: 21,
      kind: ListeningQuestionKind.multiPair,
      stem: 'Which TWO things did Colin find most satisfying about his bread reuse project?',
      options: <String, String>{
        'A': 'receiving support from local restaurants',
        'B': 'finding a good way to prevent waste',
        'C': 'overcoming problems in a basic process',
        'D': 'experimenting with designs and colours',
        'E': 'learning how to apply 3-D printing',
      },
    ),
    ListeningQuestion(
      number: 23,
      kind: ListeningQuestionKind.multiPair,
      stem: 'Which TWO ways do the students agree that touch-sensitive sensors for food labels could be developed in future?',
      options: <String, String>{
        'A': 'for use on medical products',
        'B': 'to show that food is no longer fit to eat',
        'C': 'for use with drinks as well as foods',
        'D': 'to provide applications for blind people',
        'E': 'to indicate the weight of certain foods',
      },
    ),
    ListeningQuestion(number: 25, kind: ListeningQuestionKind.matchingLetter, stem: 'Use of local products', options: <String, String>{'A': 'This is only relevant to young people.', 'B': 'This may have disappointing results.', 'C': 'This already seems to be widespread.', 'D': 'Retailers should do more to encourage this.', 'E': 'More financial support is needed for this.', 'F': 'Most people know little about this.', 'G': 'There should be stricter regulations about this.', 'H': 'This could be dangerous.'}),
    ListeningQuestion(number: 26, kind: ListeningQuestionKind.matchingLetter, stem: 'Reduction in unnecessary packaging', options: <String, String>{'A': 'This is only relevant to young people.', 'B': 'This may have disappointing results.', 'C': 'This already seems to be widespread.', 'D': 'Retailers should do more to encourage this.', 'E': 'More financial support is needed for this.', 'F': 'Most people know little about this.', 'G': 'There should be stricter regulations about this.', 'H': 'This could be dangerous.'}),
    ListeningQuestion(number: 27, kind: ListeningQuestionKind.matchingLetter, stem: 'Gluten-free and lactose-free food', options: <String, String>{'A': 'This is only relevant to young people.', 'B': 'This may have disappointing results.', 'C': 'This already seems to be widespread.', 'D': 'Retailers should do more to encourage this.', 'E': 'More financial support is needed for this.', 'F': 'Most people know little about this.', 'G': 'There should be stricter regulations about this.', 'H': 'This could be dangerous.'}),
    ListeningQuestion(number: 28, kind: ListeningQuestionKind.matchingLetter, stem: 'Use of branded products related to celebrity chefs', options: <String, String>{'A': 'This is only relevant to young people.', 'B': 'This may have disappointing results.', 'C': 'This already seems to be widespread.', 'D': 'Retailers should do more to encourage this.', 'E': 'More financial support is needed for this.', 'F': 'Most people know little about this.', 'G': 'There should be stricter regulations about this.', 'H': 'This could be dangerous.'}),
    ListeningQuestion(number: 29, kind: ListeningQuestionKind.matchingLetter, stem: "Development of 'ghost kitchens' for takeaway food", options: <String, String>{'A': 'This is only relevant to young people.', 'B': 'This may have disappointing results.', 'C': 'This already seems to be widespread.', 'D': 'Retailers should do more to encourage this.', 'E': 'More financial support is needed for this.', 'F': 'Most people know little about this.', 'G': 'There should be stricter regulations about this.', 'H': 'This could be dangerous.'}),
    ListeningQuestion(number: 30, kind: ListeningQuestionKind.matchingLetter, stem: 'Use of mushrooms for common health concerns', options: <String, String>{'A': 'This is only relevant to young people.', 'B': 'This may have disappointing results.', 'C': 'This already seems to be widespread.', 'D': 'Retailers should do more to encourage this.', 'E': 'More financial support is needed for this.', 'F': 'Most people know little about this.', 'G': 'There should be stricter regulations about this.', 'H': 'This could be dangerous.'}),
    ListeningQuestion(number: 31, kind: ListeningQuestionKind.fillIn, stem: 'stones beneath the bog surface were once'),
    ListeningQuestion(number: 32, kind: ListeningQuestionKind.fillIn, stem: 'His'),
    ListeningQuestion(number: 33, kind: ListeningQuestionKind.fillIn, stem: 'used by local people to dig for'),
    ListeningQuestion(number: 34, kind: ListeningQuestionKind.fillIn, stem: 'a lack of'),
    ListeningQuestion(number: 35, kind: ListeningQuestionKind.fillIn, stem: 'Houses were'),
    ListeningQuestion(number: 36, kind: ListeningQuestionKind.fillIn, stem: 'pots used for storage and to make'),
    ListeningQuestion(number: 37, kind: ListeningQuestionKind.fillIn, stem: 'Each field at Céide was large enough to support a big'),
    ListeningQuestion(number: 38, kind: ListeningQuestionKind.fillIn, stem: 'to house them during'),
    ListeningQuestion(number: 39, kind: ListeningQuestionKind.fillIn, stem: 'a decline in'),
    ListeningQuestion(number: 40, kind: ListeningQuestionKind.fillIn, stem: 'an increase in'),
  ];

  // --- Reading: passages ---

  /// 按 `test1`…`test4` 行界截取（勿使用 `(?=…|\Z)`：Dart 中 `\Z` 会在全文末尾匹配，导致 `*?` 过早结束）。
  static Map<String, String> _extractReadingPassagesForTest(String raw, int testNum) {
    final int chunkStart = _findLineTestMarker(raw, testNum);
    if (chunkStart == -1) {
      return <String, String>{};
    }
    final String marker = 'test$testNum';
    final int bodyAfterMarker = chunkStart + marker.length;
    int chunkEnd = raw.length;
    if (testNum < 4) {
      final int next = _findLineTestMarker(raw, testNum + 1);
      if (next != -1) {
        chunkEnd = next;
      }
    }
    if (chunkEnd <= bodyAfterMarker) {
      return <String, String>{};
    }
    final String chunk = raw.substring(bodyAfterMarker, chunkEnd);

    String between(String start, String? end) {
      final int i = chunk.indexOf(start);
      if (i == -1) {
        return '';
      }
      final int from = i + start.length;
      if (end == null) {
        return chunk.substring(from);
      }
      final int j = chunk.indexOf(end, from);
      final String body = j == -1 ? chunk.substring(from) : chunk.substring(from, j);
      return body.replaceAll('&#x20;', ' ').trim();
    }

    return <String, String>{
      'A': between('阅读A篇', '阅读B篇'),
      'B': between('阅读B篇', '阅读C篇'),
      'C': between('阅读C篇', null),
    };
  }

  /// 定位独立成行（前后为换行或文件边界）的 `test1`…`test4`。
  static int _findLineTestMarker(String raw, int n) {
    if (n < 1 || n > 4) {
      return -1;
    }
    final String marker = 'test$n';
    int from = 0;
    while (from < raw.length) {
      final int i = raw.indexOf(marker, from);
      if (i == -1) {
        return -1;
      }
      final bool okBefore = i == 0 || raw[i - 1] == '\n' || raw[i - 1] == '\r';
      final int after = i + marker.length;
      final bool okAfter = after >= raw.length || raw[after] == '\n' || raw[after] == '\r';
      if (okBefore && okAfter) {
        return i;
      }
      from = i + 1;
    }
    return -1;
  }

  // --- Reading: structured JSON (Test 1) ---

  /// `reading_test1.json`：优先 `question_groups`（题组）；否则兼容旧版扁平 `questions`。
  static List<ReadingQuestionItem> _readingQuestionsFromStructuredJson(String jsonRaw) {
    final Object? decoded = jsonDecode(jsonRaw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('reading_test1.json: root must be a JSON array');
    }
    const List<String> letters = <String>['A', 'B', 'C'];
    final List<ReadingQuestionItem> out = <ReadingQuestionItem>[];
    int nextFallback = 1;
    for (int pi = 0; pi < decoded.length && pi < letters.length; pi++) {
      final Object? passageObj = decoded[pi];
      if (passageObj is! Map<String, dynamic>) {
        continue;
      }
      final String passageLetter = letters[pi];
      final Object? groupsRaw = passageObj['question_groups'];
      if (groupsRaw is List<dynamic>) {
        for (final Object? gObj in groupsRaw) {
          if (gObj is! Map<String, dynamic>) {
            continue;
          }
          final Map<String, dynamic> g = gObj;
          final String groupType = (g['group_type'] as String?)?.trim() ?? '';
          final String groupInst = (g['group_instruction'] as String?)?.trim() ?? '';
          final Object? sharedRaw = g['shared_content'];
          final String? sharedStr = sharedRaw?.toString().trim();
          final Object? subs = g['questions'];
          if (subs is! List<dynamic>) {
            continue;
          }
          final Map<String, String>? groupOptions =
              _readingOptionsForGroupedQuestion(groupType, sharedStr, subs);
          for (int si = 0; si < subs.length; si++) {
            final Object? qObj = subs[si];
            if (qObj is! Map<String, dynamic>) {
              continue;
            }
            final Map<String, dynamic> q = qObj;
            final String questionText = (q['question_text'] as String?)?.trim() ?? '';
            final String correct = (q['correct_answer'] as String?)?.trim() ?? '';
            final String explanation = (q['explanation'] as String?)?.trim() ?? '';
            final int? rawNum = (q['question_number'] as num?)?.toInt();
            final int globalNum = (rawNum != null && rawNum >= 1 && rawNum <= 40)
                ? rawNum
                : nextFallback;
            if (rawNum != null && rawNum >= 1 && rawNum <= 40) {
              if (rawNum >= nextFallback) {
                nextFallback = rawNum + 1;
              }
            } else {
              nextFallback = globalNum + 1;
            }
            final bool isFirstInGroup = si == 0;
            out.add(
              ReadingQuestionItem(
                globalNumber: globalNum,
                passage: passageLetter,
                body: questionText,
                correctAnswer: correct,
                analysis: explanation,
                options: groupOptions,
                questionType: groupType.isEmpty ? null : groupType,
                groupInstruction: isFirstInGroup ? (groupInst.isEmpty ? null : groupInst) : null,
                sharedContent: isFirstInGroup && sharedStr != null && sharedStr.isNotEmpty ? sharedStr : null,
              ),
            );
          }
        }
        continue;
      }
      final Object? qList = passageObj['questions'];
      if (qList is! List<dynamic>) {
        continue;
      }
      for (final Object? qObj in qList) {
        if (qObj is! Map<String, dynamic>) {
          continue;
        }
        final Map<String, dynamic> q = qObj;
        final String type = (q['question_type'] as String?)?.trim() ?? '';
        final String instruction = (q['instruction'] as String?)?.trim() ?? '';
        final String questionText = (q['question_text'] as String?)?.trim() ?? '';
        final String correct = (q['correct_answer'] as String?)?.trim() ?? '';
        final String explanation = (q['explanation'] as String?)?.trim() ?? '';
        final List<dynamic>? optsRaw = q['options'] as List<dynamic>?;
        final Map<String, String>? options = _readingOptionsFromJson(optsRaw, type, correct);
        final String body = _readingBodyFromStructuredJson(instruction, questionText);
        final int? rawNum = (q['question_number'] as num?)?.toInt();
        final int globalNum = (rawNum != null && rawNum >= 1 && rawNum <= 40)
            ? rawNum
            : nextFallback;
        if (rawNum != null && rawNum >= 1 && rawNum <= 40) {
          if (rawNum >= nextFallback) {
            nextFallback = rawNum + 1;
          }
        } else {
          nextFallback = globalNum + 1;
        }
        out.add(
          ReadingQuestionItem(
            globalNumber: globalNum,
            passage: passageLetter,
            body: body,
            correctAnswer: correct,
            analysis: explanation,
            options: options,
            questionType: type.isEmpty ? null : type,
          ),
        );
      }
    }
    out.sort((ReadingQuestionItem a, ReadingQuestionItem b) => a.globalNumber.compareTo(b.globalNumber));
    return out;
  }

  /// 题组级选项：MCQ / 人物匹配从 `shared_content` 解析 A.、B.…；T/F/NG 整组统一。
  static Map<String, String>? _readingOptionsForGroupedQuestion(
    String groupType,
    String? sharedContent,
    List<dynamic> subs,
  ) {
    if (groupType == 'True/False/Not Given') {
      return <String, String>{
        'TRUE': 'TRUE',
        'FALSE': 'FALSE',
        'NOT GIVEN': 'NOT GIVEN',
      };
    }
    if (groupType == 'Multiple Choice' || groupType == 'Matching People with Statements') {
      return _parseOptionLetterLinesFromText(sharedContent ?? '');
    }
    if (subs.isNotEmpty && subs.first is Map<String, dynamic>) {
      final Map<String, dynamic> first = subs.first as Map<String, dynamic>;
      final String correct = (first['correct_answer'] as String?)?.trim() ?? '';
      if (_isTfngAnswer(correct)) {
        return <String, String>{
          'TRUE': 'TRUE',
          'FALSE': 'FALSE',
          'NOT GIVEN': 'NOT GIVEN',
        };
      }
    }
    return null;
  }

  static Map<String, String>? _parseOptionLetterLinesFromText(String text) {
    if (text.isEmpty) {
      return null;
    }
    final Map<String, String> m = <String, String>{};
    for (final String line in text.split('\n')) {
      final RegExpMatch? mm = RegExp(r'^([A-Z])\.\s*(.+)$').firstMatch(line.trim());
      if (mm != null) {
        m[mm.group(1)!] = mm.group(2)!.trim();
      }
    }
    return m.isEmpty ? null : m;
  }

  /// 题型单独放在 [ReadingQuestionItem.questionType]，此处只拼说明与题干，避免 UI 重复。
  static String _readingBodyFromStructuredJson(String instruction, String questionText) {
    final StringBuffer b = StringBuffer();
    if (instruction.isNotEmpty) {
      b.writeln(instruction);
      if (questionText.isNotEmpty) {
        b.writeln();
      }
    }
    if (questionText.isNotEmpty) {
      b.write(questionText);
    }
    return b.toString().trim();
  }

  static Map<String, String>? _readingOptionsFromJson(
    List<dynamic>? raw,
    String questionType,
    String correctAnswer,
  ) {
    if (raw != null && raw.isNotEmpty) {
      final Map<String, String> m = <String, String>{};
      for (final Object? e in raw) {
        final String s = e?.toString().trim() ?? '';
        final RegExpMatch? mm = RegExp(r'^([A-Z])\.\s*(.*)$').firstMatch(s);
        if (mm != null) {
          m[mm.group(1)!] = mm.group(2)!.trim();
        }
      }
      if (m.isNotEmpty) {
        return m;
      }
    }
    if (questionType == 'True/False/Not Given' || _isTfngAnswer(correctAnswer)) {
      return <String, String>{
        'TRUE': 'TRUE',
        'FALSE': 'FALSE',
        'NOT GIVEN': 'NOT GIVEN',
      };
    }
    return null;
  }

  // --- Reading: 40 questions from QA file ---

  /// 兼容 `## IELTS Reading Practice: ...` 与 `IELTS Reading Practice: ...`（无 ##，见于 Test 1–2 前半）。
  static List<String> _readingPassageHeaderCandidates(int testNum, String passage) {
    final String core = 'IELTS Reading Practice: Test $testNum, Passage $passage';
    return <String>['## $core', '\n$core', core];
  }

  static int _indexOfEarliest(String haystack, Iterable<String> needles, int from) {
    int best = -1;
    for (final String n in needles) {
      final int i = haystack.indexOf(n, from);
      if (i != -1 && (best == -1 || i < best)) {
        best = i;
      }
    }
    return best;
  }

  static String _extractReadingPassageSection(String full, int testNum, String passage) {
    final List<String> startNeedles = _readingPassageHeaderCandidates(testNum, passage);
    final int start = _indexOfEarliest(full, startNeedles, 0);
    if (start == -1) {
      return '';
    }
    String? matched;
    for (final String n in startNeedles) {
      if (full.startsWith(n, start)) {
        matched = n;
        break;
      }
    }
    if (matched == null) {
      return '';
    }
    final int bodyStart = start + matched.length;
    final int nextStart = _nextReadingSectionHeaderIndex(full, testNum, passage, bodyStart);
    if (nextStart == -1) {
      return full.substring(bodyStart);
    }
    return full.substring(bodyStart, nextStart);
  }

  /// Passage A→B→C→下一套 Test 的 Passage A。
  static int _nextReadingSectionHeaderIndex(String full, int testNum, String passage, int searchFrom) {
    if (passage == 'A') {
      return _indexOfEarliest(full, _readingPassageHeaderCandidates(testNum, 'B'), searchFrom);
    }
    if (passage == 'B') {
      return _indexOfEarliest(full, _readingPassageHeaderCandidates(testNum, 'C'), searchFrom);
    }
    if (passage == 'C' && testNum < 4) {
      return _indexOfEarliest(full, _readingPassageHeaderCandidates(testNum + 1, 'A'), searchFrom);
    }
    return -1;
  }

  static (String questions, String answers)? _splitReadingQuestionAndAnswerBlocks(String section) {
    const String k1 = '## Answer Key and Explanations';
    const String k2 = 'Answer Key and Explanations';
    final int i1 = section.indexOf(k1);
    final int i2 = section.indexOf(k2);
    int idx = -1;
    int keyLen = 0;
    if (i1 != -1 && (i2 == -1 || i1 <= i2)) {
      idx = i1;
      keyLen = k1.length;
    } else if (i2 != -1) {
      idx = i2;
      keyLen = k2.length;
    }
    if (idx == -1) {
      return null;
    }
    final String q = section.substring(0, idx).trim();
    final String a = section.substring(idx + keyLen).trim();
    return (q, a);
  }

  static List<ReadingQuestionItem> _buildReadingQuestionsForTest(String full, int testNum) {
    final List<ReadingQuestionItem> out = <ReadingQuestionItem>[];
    int globalOffset = 0;

    for (final String p in <String>['A', 'B', 'C']) {
      final String section = _extractReadingPassageSection(full, testNum, p);
      if (section.isEmpty) {
        continue;
      }
      final (String, String)? split = _splitReadingQuestionAndAnswerBlocks(section);
      if (split == null) {
        continue;
      }
      final String qBlock = split.$1;
      final String aBlock = split.$2;
      final Map<int, String> localAnswers = _parseReadingLocalAnswers(aBlock);
      final Map<int, String> localAnalysis = _parseReadingLocalAnalysis(aBlock);
      final int maxLocal = localAnswers.keys.isEmpty
          ? 0
          : localAnswers.keys.reduce((int a, int b) => a > b ? a : b);

      final Map<int, String> bodies = _extractQuestionBodies(qBlock);

      for (int local = 1; local <= maxLocal; local++) {
        final int global = globalOffset + local;
        final String body = bodies[local] ?? 'Question $global';
        final String ca = localAnswers[local] ?? '';
        Map<String, String>? opts = _inferOptionsFromBody(body);
        if (opts == null && _isTfngAnswer(ca)) {
          opts = <String, String>{
            'TRUE': 'TRUE',
            'FALSE': 'FALSE',
            'NOT GIVEN': 'NOT GIVEN',
          };
        }
        out.add(
          ReadingQuestionItem(
            globalNumber: global,
            passage: p,
            body: body,
            correctAnswer: ca,
            analysis: localAnalysis[local] ?? '',
            options: opts,
          ),
        );
      }
      globalOffset += maxLocal;
    }
    return out;
  }

  static Map<int, String> _parseReadingLocalAnswers(String answerBlock) {
    final Map<int, String> map = <int, String>{};
    for (final Match m in RegExp(r'###\s*(\d+)\.\s*([^\n]+)').allMatches(answerBlock)) {
      final int? n = int.tryParse(m.group(1)!);
      if (n != null) {
        map[n] = m.group(2)!.trim();
      }
    }
    for (final Match m in RegExp(r'^(\d+)\.\s+(.+)$', multiLine: true).allMatches(answerBlock)) {
      final int? n = int.tryParse(m.group(1)!);
      if (n != null && !map.containsKey(n)) {
        map[n] = m.group(2)!.trim();
      }
    }
    return map;
  }

  static String _normalizeAnalysisChunk(String s) {
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Map<int, String> _parseReadingLocalAnalysis(String answerBlock) {
    final Map<int, String> map = <int, String>{};
    for (final Match m in RegExp(
      r'###\s*(\d+)\.\s*[^\n]+\s*\n\*\*Analysis:\*\*\s*(.+?)(?=\n###\s*\d+\.|\nBased on|\Z)',
      dotAll: true,
    ).allMatches(answerBlock)) {
      map[int.parse(m.group(1)!)] = _normalizeAnalysisChunk(m.group(2)!);
    }
    for (final Match m in RegExp(
      r'^(\d+)\.\s*[^\n]+\s*\n(?:\*\*)?Analysis:\*?\s*(.+?)(?=^\d+\.\s|\n###\s*\d+\.|\nBased on|\Z)',
      multiLine: true,
      dotAll: true,
    ).allMatches(answerBlock)) {
      final int n = int.parse(m.group(1)!);
      if (!map.containsKey(n)) {
        map[n] = _normalizeAnalysisChunk(m.group(2)!);
      }
    }
    return map;
  }

  /// 题库中同时存在 `**1. 题干**`（选择题标题整段加粗）与 `**1.** 题干`（仅题号加粗）两种格式；
  /// 题干后常紧跟 A/B/C/D 等选项行，需一并并入 body 供 `_inferOptionsFromBody` 识别。
  static Map<int, String> _extractQuestionBodies(String questionBlock) {
    final Map<int, String> bodies = <int, String>{};
    final RegExp head = RegExp(
      r'(?:^|\n)\*\*(\d+)\.(?:\*\*\s*([^\r\n]+)|\s*([^\r\n]+?)\*\*)',
      multiLine: true,
    );
    final List<RegExpMatch> hits = head.allMatches(questionBlock).toList();
    for (int i = 0; i < hits.length; i++) {
      final RegExpMatch m = hits[i];
      final int n = int.parse(m.group(1)!);
      final String h = (m.group(2) ?? m.group(3) ?? '').trim();
      final int tailFrom = m.end;
      final int tailTo = i + 1 < hits.length ? hits[i + 1].start : questionBlock.length;
      String tail = questionBlock.substring(tailFrom, tailTo).trim();
      if (tail.startsWith('---')) {
        tail = tail.replaceFirst(RegExp(r'^---\s*'), '').trim();
      }
      final String body = tail.isEmpty ? h : '$h\n$tail'.trim();
      if (body.isNotEmpty) {
        bodies[n] = body;
      }
    }
    // 摘要填空等：文内 `**10. ……**`（非行首），上面未覆盖时补齐题号。
    for (final Match m in RegExp(r'\*\*(\d+)\.\s*([^*\r\n]+?)\*\*').allMatches(questionBlock)) {
      final int? n = int.tryParse(m.group(1)!);
      if (n == null || bodies.containsKey(n)) {
        continue;
      }
      bodies[n] = m.group(2)!.trim();
    }
    _mergePlainNumberedQuestionBodies(questionBlock, bodies);
    return bodies;
  }

  /// 无 Markdown 加粗时的 `1. ...` / `2. ...` 题干（Test 1 等旧版排版）。
  static void _mergePlainNumberedQuestionBodies(String qBlock, Map<int, String> bodies) {
    final RegExp re = RegExp(r'^(\d+)\.\s+([\s\S]+?)(?=^\d+\.\s|\Z)', multiLine: true);
    for (final Match m in re.allMatches(qBlock)) {
      final int n = int.parse(m.group(1)!);
      if (bodies.containsKey(n)) {
        continue;
      }
      final String body = m.group(2)!.trim();
      if (body.isNotEmpty) {
        bodies[n] = body;
      }
    }
  }

  static bool _isTfngAnswer(String a) {
    final String u = a.trim().toUpperCase();
    return u == 'TRUE' || u == 'FALSE' || u.contains('NOT GIVEN');
  }

  static Map<String, String>? _inferOptionsFromBody(String body) {
    final String flat = body.replaceAll('\n', ' ');
    if (body.contains('TRUE') && body.contains('FALSE') && body.contains('NOT GIVEN')) {
      return <String, String>{
        'TRUE': 'TRUE',
        'FALSE': 'FALSE',
        'NOT GIVEN': 'NOT GIVEN',
      };
    }
    if (RegExp(r'(^|\n)A\.\s').hasMatch(body) && RegExp(r'(^|\n)D\.\s').hasMatch(body)) {
      final Map<String, String> opts = <String, String>{};
      for (final Match m in RegExp(r'(?:^|\n)([A-D])\.\s*([^\n]+)').allMatches(body)) {
        opts[m.group(1)!] = m.group(2)!.trim();
      }
      return opts.isEmpty ? null : opts;
    }
    if (RegExp(r'(^|\n)A\.\s').hasMatch(body) && RegExp(r'(^|\n)E\.\s').hasMatch(body) && !flat.contains('NOT GIVEN')) {
      final Map<String, String> opts = <String, String>{};
      for (final Match m in RegExp(r'(?:^|\n)([A-E])\.\s*([^\n]+)').allMatches(body)) {
        opts[m.group(1)!] = m.group(2)!.trim();
      }
      return opts.isEmpty ? null : opts;
    }
    if (RegExp(r'(^|\n)A\.\s').hasMatch(body) && RegExp(r'(^|\n)G\.\s').hasMatch(body)) {
      final Map<String, String> opts = <String, String>{};
      for (final Match m in RegExp(r'(?:^|\n)([A-G])\.\s*([^\n]+)').allMatches(body)) {
        opts[m.group(1)!] = m.group(2)!.trim();
      }
      return opts.isEmpty ? null : opts;
    }
    return null;
  }

  static const String _task1Sample =
      'The line graph compares participation in four activities at a social centre in Melbourne between 2000 and 2020.\n\n'
      'Overall, the film club stayed the most popular option throughout the period, while amateur dramatics declined sharply. '
      'In contrast, table tennis rose dramatically and became the second most popular activity by 2020.\n\n'
      'In 2000, around 65 people attended the film club, compared with roughly 35 for martial arts and 25 for amateur dramatics. '
      'Musical performances attracted very few participants at first. Over the following two decades, film club figures fluctuated slightly but remained above 60. '
      'Table tennis increased steadily from about 15 to approximately 55 participants, overtaking martial arts by the end. '
      'By comparison, amateur dramatics dropped continuously to below 10 participants in 2020.\n\n'
      'This indicates a clear shift in preference from performance-based to more casual indoor activities.';

  static const String _task2Sample =
      'Competition is often considered the engine of progress, yet cooperation is equally important in modern life. I believe a balanced approach is most effective.\n\n'
      'On one hand, competition can improve performance. In schools, healthy academic competition may motivate students to study harder and develop better discipline. '
      'At work, it can encourage employees to innovate, meet deadlines and raise overall productivity. '
      'In daily life, personal competition, such as trying to beat one’s previous record, can also build confidence and resilience.\n\n'
      'On the other hand, excessive competition has clear disadvantages. It may create stress, reduce trust and even lead to unethical behaviour, especially when results matter more than process. '
      'In classrooms, some students become anxious rather than motivated. In companies, overly competitive cultures can damage teamwork and long-term performance. '
      'Cooperation, by contrast, allows people to combine strengths, share knowledge and solve complex problems more effectively.\n\n'
      'In my view, society should not reject competition, but it must be guided by cooperative values. '
      'Schools and workplaces should reward both individual achievement and collaborative contribution. '
      'When competition remains fair and cooperation remains central, people can improve without harming others.';
}

class ListeningMcq {
  const ListeningMcq({
    required this.stem,
    required this.a,
    required this.b,
    required this.c,
  });

  final String stem;
  final String a;
  final String b;
  final String c;
}

enum ListeningQuestionKind {
  fillIn,
  mcq,
  mapLetter,
  multiPair,
  matchingLetter,
}

class ListeningQuestion {
  const ListeningQuestion({
    required this.number,
    required this.kind,
    required this.stem,
    this.options,
  });

  final int number;
  final ListeningQuestionKind kind;
  final String stem;
  final Map<String, String>? options;
}

class ListeningTaskContent {
  const ListeningTaskContent({
    required this.part1Notes,
    required this.questions,
    required this.answers,
  });

  final String part1Notes;
  final List<ListeningQuestion> questions;
  final Map<int, String> answers;
}

class ReadingQuestionItem {
  const ReadingQuestionItem({
    required this.globalNumber,
    required this.passage,
    required this.body,
    required this.correctAnswer,
    required this.analysis,
    this.options,
    this.questionType,
    this.groupInstruction,
    this.sharedContent,
  });

  final int globalNumber;
  final String passage;
  /// 小题题干；题组模式下为 `question_text` 专属部分。
  final String body;
  final String correctAnswer;
  final String analysis;
  final Map<String, String>? options;
  /// 来自结构化 JSON 的题型标签（如 Multiple Choice）；Markdown 回退路线上常为 null。
  final String? questionType;
  /// 仅题组内第一题为非 null：整组共用说明。
  final String? groupInstruction;
  /// 仅题组内第一题为非 null：共用列表/小标题等（与 options 并存时 UI 按需展示）。
  final String? sharedContent;
}

class ReadingTaskContent {
  const ReadingTaskContent({
    required this.testNumber,
    required this.passageA,
    required this.passageB,
    required this.passageC,
    required this.questions,
  });

  final int testNumber;
  final String passageA;
  final String passageB;
  final String passageC;
  final List<ReadingQuestionItem> questions;
}

class WritingTaskContent {
  const WritingTaskContent({
    required this.task1Body,
    required this.task2Body,
    required this.task1ImageAsset,
    required this.modelEssayTask1,
    required this.modelEssayTask2,
  });

  final String task1Body;
  final String task2Body;
  final String task1ImageAsset;
  final String modelEssayTask1;
  final String modelEssayTask2;
}

class SpeakingTaskContent {
  const SpeakingTaskContent({
    required this.part1Questions,
    required this.part2CueCards,
  });

  /// Part 1 精选题（原文 `1.–60.`）。
  final List<String> part1Questions;
  /// Part 2&3 题卡描述（原文 `61.–100.`）。
  final List<String> part2CueCards;
}
