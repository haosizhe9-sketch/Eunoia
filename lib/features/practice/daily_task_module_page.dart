import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/practice/simulated_speaking.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/news_mock_ai_service.dart';
import '../../core/services/app_data_service.dart' show DailyPracticeApplyResult;
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/ai_feedback_loading_dialog.dart';
import '../../core/ui/app_snackbar.dart';
import 'daily_task_resource_loader.dart';
import 'exam_marker_layer.dart';
import 'widgets/mic_input_level_meter.dart';

String _formatDurationMmSs(Duration d) {
  final int m = d.inMinutes;
  final int s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatSpeakMmss(Duration d) {
  final int m = d.inMinutes.remainder(60);
  final int s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 单技能任务页（从 `resource/` 题库加载正文）。
class DailyTaskModulePage extends ConsumerStatefulWidget {
  const DailyTaskModulePage({super.key, required this.kind, this.paperSet = 1});

  final String kind;
  /// 套题序号：阅读对应 Test 1–4；听力 / 写作目前题库为单套时仍为 1。
  final int paperSet;

  @override
  ConsumerState<DailyTaskModulePage> createState() => _DailyTaskModulePageState();
}

class _DailyTaskModulePageState extends ConsumerState<DailyTaskModulePage> {
  static const Color _pinkGlow = Color(0xFFFF61D2);

  _KindMeta? _meta;
  Future<Object?>? _future;
  bool _futureReady = false;
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(60 * 60);
  Timer? _timer;
  bool _timerStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _meta ??= _KindMeta.fromSlug(widget.kind, AppStrings.of(context));
    if (_futureReady) {
      return;
    }
    _futureReady = true;
    final _KindMeta? currentMeta = _meta;
    if (currentMeta == null) {
      _future = Future<Object?>.value(null);
      return;
    }
    _future = _loadFuture(currentMeta);
    final _DailyKind kind = currentMeta.kind;
    if (kind == _DailyKind.listening) {
      _secondsLeft.value = 30 * 60;
    } else if (kind != _DailyKind.speaking) {
      _secondsLeft.value = 60 * 60;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsLeft.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_timerStarted) {
      return;
    }
    _timerStarted = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_secondsLeft.value <= 0) {
        _timer?.cancel();
        return;
      }
      _secondsLeft.value -= 1;
    });
  }

  String _mmSs(int totalSec) {
    final int m = totalSec ~/ 60;
    final int s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final _KindMeta? meta = _meta;
    if (meta == null) {
      return Scaffold(
        backgroundColor: HtmlDesignTokens.gachaSubBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(s.dailyUnknownTask, style: const TextStyle(color: HtmlDesignTokens.textMain))),
      );
    }

    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Column(
        children: <Widget>[
          _TaskHeader(
            title: meta.title,
            meta: _resolvedMetaLine(meta),
            timeBuilder: meta.kind == _DailyKind.speaking
                ? null
                : ValueListenableBuilder<int>(
                    valueListenable: _secondsLeft,
                    builder: (BuildContext context, int value, _) {
                      return Text(
                        _mmSs(value),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HtmlDesignTokens.textMain,
                          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                          fontFamily: 'system-ui',
                        ),
                      );
                    },
                  ),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: FutureBuilder<Object?>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<Object?> snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: HtmlDesignTokens.primaryLight));
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.dailyLoadFailed(snap.error),
                        style: const TextStyle(color: HtmlDesignTokens.textSub),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return _buildBody(meta, snap.data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<Object?> _loadFuture(_KindMeta meta) {
    final int set = widget.paperSet.clamp(1, 99);
    switch (meta.kind) {
      case _DailyKind.listening:
        return DailyTaskResourceLoader.loadListening();
      case _DailyKind.reading:
        return DailyTaskResourceLoader.loadReading(testNumber: set);
      case _DailyKind.writing:
        return DailyTaskResourceLoader.loadWriting();
      case _DailyKind.speaking:
        return DailyTaskResourceLoader.loadSpeaking();
    }
  }

  String _resolvedMetaLine(_KindMeta meta) {
    final AppStrings str = AppStrings.of(context);
    final int set = widget.paperSet.clamp(1, 99);
    switch (meta.kind) {
      case _DailyKind.reading:
        return str.dailyReadingMetaLine(set);
      case _DailyKind.listening:
        return str.dailyListeningMetaLine(set);
      case _DailyKind.writing:
        return str.dailyWritingMetaLine(set);
      case _DailyKind.speaking:
        return meta.subtitle;
    }
  }

  Widget _buildBody(_KindMeta meta, Object? data) {
    switch (meta.kind) {
      case _DailyKind.listening:
        return _ListeningBody(
          ref: ref,
          content: data! as ListeningTaskContent,
          onTimerTrigger: _startTimer,
          timeLeft: _secondsLeft,
        );
      case _DailyKind.reading:
        return _ReadingBody(
          ref: ref,
          content: data! as ReadingTaskContent,
          timeLeft: _secondsLeft,
        );
      case _DailyKind.writing:
        return _WritingBody(
          content: data! as WritingTaskContent,
          timeLeft: _secondsLeft,
        );
      case _DailyKind.speaking:
        return _SpeakingBody(
          content: data! as SpeakingTaskContent,
          pink: _pinkGlow,
        );
    }
  }
}

enum _DailyKind { listening, reading, writing, speaking }

class _KindMeta {
  const _KindMeta({
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final _DailyKind kind;
  final String title;
  final String subtitle;

  static _KindMeta? fromSlug(String slug, AppStrings s) {
    switch (slug) {
      case 'listening':
        return const _KindMeta(
          kind: _DailyKind.listening,
          title: 'Listening Test',
          subtitle: 'Part 1 · Part 2',
        );
      case 'reading':
        return const _KindMeta(
          kind: _DailyKind.reading,
          title: 'Reading Test',
          subtitle: 'Test 1 · 40 Questions',
        );
      case 'writing':
        return const _KindMeta(
          kind: _DailyKind.writing,
          title: 'Writing Task',
          subtitle: 'Task 1 & Task 2',
        );
      case 'speaking':
        return _KindMeta(
          kind: _DailyKind.speaking,
          title: s.dailySpeakingTitle,
          subtitle: s.dailySpeakingSubtitle,
        );
      default:
        return null;
    }
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.title,
    required this.meta,
    this.timeBuilder,
    required this.onBack,
  });

  final String title;
  final String meta;
  final Widget? timeBuilder;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 8, 16, 12),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: HtmlDesignTokens.glassBorder)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, color: HtmlDesignTokens.textMain, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: HtmlDesignTokens.glassCard,
              side: BorderSide(color: HtmlDesignTokens.glassBorder),
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'system-ui',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: HtmlDesignTokens.accent,
                    fontFamily: 'system-ui',
                  ),
                ),
              ],
            ),
          ),
          timeBuilder ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _ListeningBody extends StatefulWidget {
  const _ListeningBody({
    required this.ref,
    required this.content,
    required this.onTimerTrigger,
    required this.timeLeft,
  });

  final WidgetRef ref;
  final ListeningTaskContent content;
  final VoidCallback onTimerTrigger;
  final ValueListenable<int> timeLeft;

  @override
  State<_ListeningBody> createState() => _ListeningBodyState();
}

class _ListeningBodyState extends State<_ListeningBody> {
  late final AudioPlayer _player;
  final ValueNotifier<Duration> _position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _duration = ValueNotifier<Duration>(Duration.zero);
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  final Map<int, TextEditingController> _fill = <int, TextEditingController>{};
  final Map<int, String> _letter = <int, String>{};
  final Set<String> _pair21 = <String>{};
  final Set<String> _pair23 = <String>{};
  bool _startedByAudio = false;
  final ExamMarkerController _examMarker = ExamMarkerController();
  bool _examPenActive = false;

  void _commitExamHighlight() {
    if (mounted) {
      setState(() => _examPenActive = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    for (int n = 1; n <= 10; n++) {
      _fill[n] = TextEditingController();
    }
    for (int n = 31; n <= 40; n++) {
      _fill[n] = TextEditingController();
    }
    _posSub = _player.onPositionChanged.listen((Duration d) {
      _position.value = d;
    });
    _durSub = _player.onDurationChanged.listen((Duration d) {
      _duration.value = d;
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fill.values) {
      c.dispose();
    }
    _posSub?.cancel();
    _durSub?.cancel();
    _position.dispose();
    _duration.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    try {
      await _player.stop();
      try {
        await _player.setSourceAsset(DailyTaskResourceLoader.listeningAudioAsset);
      } catch (_) {
        // Web 端兜底：部分环境下 asset MIME 识别异常，改走静态资源 URL。
        await _player.setSourceUrl('assets/resource/listening.mp3');
      }
      await _player.resume();
      if (!_startedByAudio) {
        _startedByAudio = true;
        widget.onTimerTrigger();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      showAppTopSnackBar(context, Text(AppStrings.of(context).dailyAudioPlayFailed(e)));
    }
  }

  String _cleanText(String s) {
    return s
        .replaceAll(r'\.', '.')
        .replaceAll(r'\_', '_')
        .replaceAll('\\', '')
        .replaceAllMapped(RegExp(r'_{3,}'), (_) => '__________')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _submit() {
    final AppStrings s = AppStrings.of(context);
    const int total = 40;
    final List<_ReviewItem> items = <_ReviewItem>[];
    int correct = 0;
    for (int n = 1; n <= total; n++) {
      final String? right = widget.content.answers[n];
      if (right == null) {
        continue;
      }
      String user = '-';
      bool ok = false;
      if (n <= 10 || n >= 31) {
        user = _fill[n]?.text.trim() ?? '';
        ok = _matchListeningFill(user, right);
      } else if (n >= 11 && n <= 20) {
        user = _letter[n] ?? '-';
        ok = user == right;
      } else if (n == 21 || n == 22) {
        user = _pair21.join(' ');
        ok = _matchPairLetters(user, right);
      } else if (n == 23 || n == 24) {
        user = _pair23.join(' ');
        ok = _matchPairLetters(user, right);
      } else if (n >= 25 && n <= 30) {
        user = _letter[n] ?? '-';
        ok = user == right;
      }
      if (ok) {
        correct += 1;
      }
      items.add(
        _ReviewItem(
          number: n,
          userAnswer: user.isEmpty ? '-' : user,
          rightAnswer: right,
          correct: ok,
          analysis: s.dailyListeningOfficialAnswerLine(right),
        ),
      );
    }
    final double band = _ieltsListeningReadingBand(correct, total);
    unawaited(
      _recordDailyPracticeOutcome(
        context,
        widget.ref,
        skill: 'listening',
        ieltsBand: band,
      ),
    );
    unawaited(
      _syncPracticeExamMistakesToLocalStore(
        ref: widget.ref,
        strings: s,
        skill: 'listening',
        readingTestNumber: 1,
        items: items,
      ),
    );
    _showReviewSheet(
      context: context,
      title: s.dailyListeningReviewTitle,
      band: band,
      rawSummary: '$correct / $total',
      items: items,
      extraActions: <Widget>[
        _ActionTextButton(
          label: s.dailyViewAnswers,
          onTap: () => _showPlainDialog(context, s.dailyListeningAnswersDialogTitle, _buildListeningAnswerText()),
        ),
      ],
    );
  }

  String _buildListeningAnswerText() {
    final StringBuffer buf = StringBuffer();
    for (int n = 1; n <= 40; n++) {
      buf.writeln('$n. ${widget.content.answers[n] ?? '?'}');
    }
    return buf.toString().trim();
  }

  Widget _p1Blank(int n, {double width = 72}) {
    return SizedBox(
      width: width,
      height: 30,
      child: TextField(
        controller: _fill[n],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 14),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: HtmlDesignTokens.textSub.withValues(alpha: 0.85)),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: HtmlDesignTokens.textSub.withValues(alpha: 0.85)),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: HtmlDesignTokens.accent, width: 1.4),
          ),
        ),
      ),
    );
  }

  /// 试卷样式：PART 1 页眉、说明、带边框笔记区、文内填空。
  Widget _buildListeningPart1ExamPaper() {
    const TextStyle body = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: HtmlDesignTokens.textMain,
      fontFamily: 'system-ui',
    );
    const TextStyle bold = TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w700,
      color: HtmlDesignTokens.textMain,
      fontFamily: 'system-ui',
    );
    const TextStyle instruct = TextStyle(
      fontSize: 13,
      height: 1.45,
      fontStyle: FontStyle.italic,
      color: HtmlDesignTokens.textSub,
      fontFamily: 'system-ui',
    );

    Widget line(List<Widget> parts) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 6,
          children: parts,
        ),
      );
    }

    Widget sectionHeading(String s) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(s, style: bold),
      );
    }

    Widget plain(String s) => Text(s, style: body);
    Widget boldTxt(String s) => Text(s, style: bold);
    Widget numBold(int n) => Text('$n', style: bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PART 1',
                  style: bold.copyWith(fontSize: 15, letterSpacing: 0.4),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  'Questions 1–10',
                  style: bold.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Expanded(flex: 1, child: SizedBox()),
          ],
        ),
        const SizedBox(height: 10),
        HighlightableExamText(
          text: 'Complete the notes below.\nWrite ONE WORD AND/OR A NUMBER for each answer.',
          textStyle: instruct.copyWith(fontStyle: FontStyle.normal),
          highlightKey: 'listening_p1_directions',
          marker: _examMarker,
          penActive: _examPenActive,
          onHighlightCommitted: _commitExamHighlight,
        ),
        const SizedBox(height: 10),
        HighlightableExamText(
          text: widget.content.part1Notes,
          textStyle: body,
          highlightKey: 'listening_part1_notes',
          marker: _examMarker,
          penActive: _examPenActive,
          onHighlightCommitted: _commitExamHighlight,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: HtmlDesignTokens.glassBorder, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Hinchingbrooke Country Park',
                textAlign: TextAlign.center,
                style: bold.copyWith(fontSize: 15, letterSpacing: 0.15),
              ),
              const SizedBox(height: 10),
              sectionHeading('The park'),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    line(<Widget>[boldTxt('Area: '), numBold(1), _p1Blank(1), plain(' hectares')]),
                    line(<Widget>[boldTxt('Habitats: '), plain('wetland, grassland and woodland')]),
                    line(<Widget>[boldTxt('Wetland: '), plain('lakes, ponds and a '), numBold(2), _p1Blank(2)]),
                    line(<Widget>[boldTxt('Wildlife '), plain('includes birds, insects and animals')]),
                  ],
                ),
              ),
              sectionHeading('Subjects studied in educational visits include'),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    line(<Widget>[
                      boldTxt('Science: '),
                      plain('Children look at '),
                      numBold(3),
                      _p1Blank(3),
                      plain(' about plants, etc.'),
                    ]),
                    line(<Widget>[
                      boldTxt('Geography: '),
                      plain('includes learning to use a '),
                      numBold(4),
                      _p1Blank(4),
                      plain(' and compass'),
                    ]),
                    line(<Widget>[boldTxt('History: '), plain('changes in land use')]),
                    line(<Widget>[
                      boldTxt('Leisure and tourism: '),
                      plain('mostly concentrates on the park\u2019s '),
                      numBold(5),
                      _p1Blank(5),
                    ]),
                    line(<Widget>[
                      boldTxt('Music: '),
                      plain('Children make '),
                      numBold(6),
                      _p1Blank(6),
                      plain(' with natural materials, and experiment with rhythm and speed.'),
                    ]),
                  ],
                ),
              ),
              sectionHeading('Benefits of outdoor educational visits'),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    line(<Widget>[
                      plain('They give children a feeling of '),
                      numBold(7),
                      _p1Blank(7),
                      plain(' that they may not have elsewhere.'),
                    ]),
                    line(<Widget>[
                      plain('Children learn new '),
                      numBold(8),
                      _p1Blank(8),
                      plain(' and gain self-confidence.'),
                    ]),
                  ],
                ),
              ),
              sectionHeading('Practical issues'),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    line(<Widget>[
                      boldTxt('Cost per child: '),
                      numBold(9),
                      plain(' £ '),
                      _p1Blank(9, width: 56),
                    ]),
                    line(<Widget>[
                      plain('Adults, such as '),
                      numBold(10),
                      _p1Blank(10, width: 88),
                      plain(' , free'),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _part4Fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HighlightableExamText(
          text: 'Céide Fields\n'
              '• an important Neolithic archaeological site in the northwest of Ireland',
          textStyle: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: HtmlDesignTokens.textMain,
            fontWeight: FontWeight.w600,
            fontFamily: 'system-ui',
          ),
          highlightKey: 'listening_p4_heading',
          marker: _examMarker,
          penActive: _examPenActive,
          onHighlightCommitted: _commitExamHighlight,
        ),
        const SizedBox(height: 10),
        HighlightableExamText(
          text: 'Discovery\n'
              '• In the 1930s, a local teacher realised that stones beneath the bog surface were once (31) __________.\n'
              '• His (32) __________ became an archaeologist and undertook an investigation of the site:\n'
              '  – a traditional method used by local people to dig for (33) __________ was used to identify where stones were located\n'
              '  – carbon dating later proved the site was Neolithic.\n'
              '• Items are well preserved in the bog because of a lack of (34) __________.',
          textStyle: const TextStyle(fontSize: 13, height: 1.5, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
          highlightKey: 'listening_p4_discovery',
          marker: _examMarker,
          penActive: _examPenActive,
          onHighlightCommitted: _commitExamHighlight,
        ),
        const SizedBox(height: 8),
        HighlightableExamText(
          text: 'Neolithic farmers\n'
              '• Houses were (35) __________ in shape and had a hole in the roof.\n'
              '• Neolithic innovations include:\n'
              '  – cooking indoors\n'
              '  – pots used for storage and to make (36) __________.\n'
              '• Each field at Céide was large enough to support a big (37) __________.\n'
              '• The fields were probably used to restrict the grazing of animals – no evidence of structures to house them during (38) __________.\n'
              '• Reasons for the decline in farming:\n'
              '  – a decline in (39) __________ quality\n'
              '  – an increase in (40) __________.',
          textStyle: const TextStyle(fontSize: 13, height: 1.5, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
          highlightKey: 'listening_p4_farmers',
          marker: _examMarker,
          penActive: _examPenActive,
          onHighlightCommitted: _commitExamHighlight,
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(10, (int i) {
          final int n = 31 + i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _fill[n],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 14),
              decoration: InputDecoration(
                labelText: '($n)',
                labelStyle: const TextStyle(color: HtmlDesignTokens.textSub, fontSize: 11),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final List<ListeningQuestion> mcq = widget.content.questions.where((ListeningQuestion q) => q.kind == ListeningQuestionKind.mcq).toList();
    final List<ListeningQuestion> mapQs = widget.content.questions.where((ListeningQuestion q) => q.kind == ListeningQuestionKind.mapLetter).toList();
    ListeningQuestion? p21;
    ListeningQuestion? p23;
    for (final ListeningQuestion q in widget.content.questions) {
      if (q.number == 21 && q.kind == ListeningQuestionKind.multiPair) {
        p21 = q;
      }
      if (q.number == 23 && q.kind == ListeningQuestionKind.multiPair) {
        p23 = q;
      }
    }
    final List<ListeningQuestion> m25 = widget.content.questions.where((ListeningQuestion q) => q.kind == ListeningQuestionKind.matchingLetter).toList();

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              _AudioPlaceholder(
                onPlay: _playAudio,
                position: _position,
                duration: _duration,
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _examMarker,
                builder: (BuildContext context, _) {
                  return ExamMarkerToolbar(
                    penActive: _examPenActive,
                    onPenPressed: () => setState(() => _examPenActive = !_examPenActive),
                    onUndo: _examMarker.undo,
                    canUndo: _examMarker.canUndo,
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.glassCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HtmlDesignTokens.glassBorder),
                ),
                child: _buildListeningPart1ExamPaper(),
              ),
              const SizedBox(height: 16),
              _Panel(
                label: s.dailyListeningPart2Mcq,
                child: Column(
                  children: mcq
                      .map(
                        (ListeningQuestion q) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              HighlightableExamText(
                                text: '${q.number}. ${_cleanText(q.stem)}',
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: HtmlDesignTokens.textMain,
                                  fontFamily: 'system-ui',
                                ),
                                highlightKey: 'listening_mcq_${q.number}',
                                marker: _examMarker,
                                penActive: _examPenActive,
                                onHighlightCommitted: _commitExamHighlight,
                              ),
                              const SizedBox(height: 8),
                              if (q.options != null)
                                for (final MapEntry<String, String> e in q.options!.entries)
                                  _LetterOption(
                                    letter: e.key,
                                    text: e.value,
                                    selected: _letter[q.number] == e.key,
                                    onTap: () => setState(() => _letter[q.number] = e.key),
                                  ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                label: s.dailyListeningPart2Map,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        DailyTaskResourceLoader.listeningMapImageAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                          padding: const EdgeInsets.all(24),
                          color: HtmlDesignTokens.glassCard,
                          child: Text(
                            s.dailyListeningImageMissing,
                            style: const TextStyle(color: HtmlDesignTokens.textSub),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...mapQs.map(
                      (ListeningQuestion q) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${q.number}.',
                                style: const TextStyle(color: HtmlDesignTokens.textMain, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: HighlightableExamText(
                                text: _cleanText(q.stem),
                                textStyle: const TextStyle(color: HtmlDesignTokens.textSub, fontSize: 13, fontFamily: 'system-ui'),
                                highlightKey: 'listening_map_${q.number}',
                                marker: _examMarker,
                                penActive: _examPenActive,
                                onHighlightCommitted: _commitExamHighlight,
                              ),
                            ),
                            DropdownButton<String>(
                              value: _letter[q.number],
                              hint: const Text('A–H', style: TextStyle(color: HtmlDesignTokens.textSub, fontSize: 12)),
                              dropdownColor: const Color(0xFF1A103C),
                              items: 'ABCDEFGH'
                                  .split('')
                                  .map(
                                    (String c) => DropdownMenuItem<String>(
                                      value: c,
                                      child: Text(c, style: const TextStyle(color: HtmlDesignTokens.textMain)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? v) => setState(() {
                                if (v == null) {
                                  _letter.remove(q.number);
                                } else {
                                  _letter[q.number] = v;
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (p21 != null)
                _Panel(
                  label: s.dailyListeningPair2122,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      HighlightableExamText(
                        text: _cleanText(p21.stem),
                        textStyle: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 14, fontFamily: 'system-ui'),
                        highlightKey: 'listening_pair21_stem',
                        marker: _examMarker,
                        penActive: _examPenActive,
                        onHighlightCommitted: _commitExamHighlight,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (p21.options?.entries.toList() ?? const <MapEntry<String, String>>[])
                            .map((MapEntry<String, String> e) => SizedBox(
                                  width: double.infinity,
                                  child: CheckboxListTile(
                                    value: _pair21.contains(e.key),
                                    title: Text('${e.key}. ${_cleanText(e.value)}', style: const TextStyle(color: HtmlDesignTokens.textMain)),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: (bool? v) {
                                      setState(() {
                                        if (v == true) {
                                          if (_pair21.length < 2) {
                                            _pair21.add(e.key);
                                          }
                                        } else {
                                          _pair21.remove(e.key);
                                        }
                                      });
                                    },
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (p23 != null)
                _Panel(
                  label: s.dailyListeningPair2324,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      HighlightableExamText(
                        text: _cleanText(p23.stem),
                        textStyle: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 14, fontFamily: 'system-ui'),
                        highlightKey: 'listening_pair23_stem',
                        marker: _examMarker,
                        penActive: _examPenActive,
                        onHighlightCommitted: _commitExamHighlight,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (p23.options?.entries.toList() ?? const <MapEntry<String, String>>[])
                            .map((MapEntry<String, String> e) => SizedBox(
                                  width: double.infinity,
                                  child: CheckboxListTile(
                                    value: _pair23.contains(e.key),
                                    title: Text('${e.key}. ${_cleanText(e.value)}', style: const TextStyle(color: HtmlDesignTokens.textMain)),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: (bool? v) {
                                      setState(() {
                                        if (v == true) {
                                          if (_pair23.length < 2) {
                                            _pair23.add(e.key);
                                          }
                                        } else {
                                          _pair23.remove(e.key);
                                        }
                                      });
                                    },
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _Panel(
                label: s.dailyListeningPart3_25_30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: m25
                      .take(1)
                      .expand((ListeningQuestion q) sync* {
                        if (q.options != null) {
                          for (final MapEntry<String, String> e in q.options!.entries) {
                            yield Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${e.key}. ${_cleanText(e.value)}',
                                style: const TextStyle(color: HtmlDesignTokens.textSub, fontSize: 12),
                              ),
                            );
                          }
                          yield const SizedBox(height: 8);
                        }
                      })
                      .followedBy(
                    m25
                      .map(
                        (ListeningQuestion q) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(width: 28, child: Text('${q.number}.', style: const TextStyle(color: HtmlDesignTokens.textMain))),
                              Expanded(
                                child: HighlightableExamText(
                                  text: _cleanText(q.stem),
                                  textStyle: const TextStyle(color: HtmlDesignTokens.textSub, fontSize: 13, fontFamily: 'system-ui'),
                                  highlightKey: 'listening_m25_${q.number}',
                                  marker: _examMarker,
                                  penActive: _examPenActive,
                                  onHighlightCommitted: _commitExamHighlight,
                                ),
                              ),
                              DropdownButton<String>(
                                value: _letter[q.number],
                                hint: const Text('A–H', style: TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub)),
                                dropdownColor: const Color(0xFF1A103C),
                                items: (q.options?.keys.toList() ?? <String>['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'])
                                    .map(
                                      (String c) => DropdownMenuItem<String>(
                                        value: c,
                                        child: Text(c, style: const TextStyle(color: HtmlDesignTokens.textMain)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (String? v) => setState(() {
                                  if (v == null) {
                                    _letter.remove(q.number);
                                  } else {
                                    _letter[q.number] = v;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                label: s.dailyListeningPart4_31_40,
                child: _part4Fields(),
              ),
            ],
          ),
        ),
        _BottomSubmit(
          label: s.dailySubmitGrade,
          onTap: _submit,
        ),
      ],
    );
  }
}

bool _matchListeningFill(String user, String key) {
  final String u = user.trim().toLowerCase();
  if (u.isEmpty) {
    return false;
  }
  final String k = key.replaceAll(RegExp(r'\*'), '').trim().toLowerCase();
  if (k.contains('/')) {
    return k.split('/').map((String e) => e.trim()).any((String p) => u == p || u == p.replaceAll(' ', ''));
  }
  return u == k;
}

bool _matchPairLetters(String userJoined, String key) {
  final List<String> ua = userJoined.split(RegExp(r'\s+')).where((String e) => e.isNotEmpty).toList()..sort();
  final List<String> ka = key.split(RegExp(r'\s+')).where((String e) => e.isNotEmpty).toList()..sort();
  if (ua.length != 2 || ka.length != 2) {
    return false;
  }
  return ua[0] == ka[0] && ua[1] == ka[1];
}

class _AudioPlaceholder extends StatelessWidget {
  const _AudioPlaceholder({
    required this.onPlay,
    required this.position,
    required this.duration,
  });

  final VoidCallback onPlay;
  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;

  @override
  Widget build(BuildContext context) {
    final Listenable tick = Listenable.merge(<Listenable>[position, duration]);
    const TextStyle timeStyle = TextStyle(
      fontSize: 12,
      color: HtmlDesignTokens.textSub,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: onPlay,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: HtmlDesignTokens.accent,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x662DD4BF), blurRadius: 12),
                ],
              ),
              child: const Icon(Icons.play_arrow, color: Colors.black87, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          AnimatedBuilder(
            animation: tick,
            builder: (BuildContext context, _) {
              return Text(_formatDurationMmSs(position.value), style: timeStyle);
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: tick,
              builder: (BuildContext context, _) {
                final int totalMs = duration.value.inMilliseconds;
                final int posMs = position.value.inMilliseconds;
                final double v = totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: HtmlDesignTokens.textSub.withValues(alpha: 0.25),
                    color: HtmlDesignTokens.accent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: tick,
            builder: (BuildContext context, _) {
              return Text(_formatDurationMmSs(duration.value), style: timeStyle);
            },
          ),
        ],
      ),
    );
  }
}

class _ReadingBody extends StatefulWidget {
  const _ReadingBody({
    required this.ref,
    required this.content,
    required this.timeLeft,
  });

  final WidgetRef ref;
  final ReadingTaskContent content;
  final ValueListenable<int> timeLeft;

  @override
  State<_ReadingBody> createState() => _ReadingBodyState();
}

class _ReadingBodyState extends State<_ReadingBody> with SingleTickerProviderStateMixin {
  final Map<int, String> _answers = <int, String>{};
  final Map<int, TextEditingController> _text = <int, TextEditingController>{};
  late TabController _tab;
  final ExamMarkerController _examMarker = ExamMarkerController();
  bool _examPenActive = false;

  void _commitExamHighlight() {
    if (mounted) {
      setState(() => _examPenActive = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    for (final ReadingQuestionItem q in widget.content.questions) {
      _text[q.globalNumber] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final TextEditingController c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final AppStrings s = AppStrings.of(context);
    int correct = 0;
    final List<_ReviewItem> items = <_ReviewItem>[];
    for (final ReadingQuestionItem q in widget.content.questions) {
      final String user = _userAnswer(q);
      final bool ok = _readingMatch(user, q.correctAnswer);
      if (ok) {
        correct += 1;
      }
      items.add(
        _ReviewItem(
          number: q.globalNumber,
          userAnswer: user.isEmpty ? '-' : user,
          rightAnswer: q.correctAnswer,
          correct: ok,
          analysis: q.analysis.isEmpty ? s.dailyNoAnalysis : q.analysis,
        ),
      );
    }
    final int nq = widget.content.questions.length;
    final double band = _ieltsListeningReadingBand(correct, nq);
    unawaited(
      _recordDailyPracticeOutcome(
        context,
        widget.ref,
        skill: 'reading',
        ieltsBand: band,
      ),
    );
    unawaited(
      _syncPracticeExamMistakesToLocalStore(
        ref: widget.ref,
        strings: s,
        skill: 'reading',
        readingTestNumber: widget.content.testNumber,
        items: items,
      ),
    );
    _showReviewSheet(
      context: context,
      title: s.dailyReadingReviewTitle(widget.content.testNumber),
      band: band,
      rawSummary: '$correct / $nq',
      items: items,
      extraActions: <Widget>[
        _ActionTextButton(
          label: s.dailyViewAnswers,
          onTap: () => _showPlainDialog(context, s.dailyReadingAnswersDialogTitle, _buildReadingAnswerText(s)),
        ),
      ],
    );
  }

  String _userAnswer(ReadingQuestionItem q) {
    if (q.options != null) {
      return _answers[q.globalNumber] ?? '';
    }
    return _text[q.globalNumber]?.text.trim() ?? '';
  }

  String _buildReadingAnswerText(AppStrings s) {
    final StringBuffer b = StringBuffer();
    for (final ReadingQuestionItem q in widget.content.questions) {
      b.writeln('Q${q.globalNumber}: ${q.correctAnswer}');
      if (q.analysis.isNotEmpty) {
        b.writeln(s.dailyReadingAnalysisLine(q.analysis));
      }
      b.writeln();
    }
    return b.toString().trim();
  }

  List<ReadingQuestionItem> _forPassage(String p) =>
      widget.content.questions.where((ReadingQuestionItem q) => q.passage == p).toList();

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Column(
      children: <Widget>[
        TabBar(
          controller: _tab,
          labelColor: HtmlDesignTokens.accent,
          unselectedLabelColor: HtmlDesignTokens.textSub,
          tabs: <Tab>[
            Tab(text: s.dailyReadingPassageTab('A')),
            Tab(text: s.dailyReadingPassageTab('B')),
            Tab(text: s.dailyReadingPassageTab('C')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ListenableBuilder(
            listenable: _examMarker,
            builder: (BuildContext context, _) {
              return ExamMarkerToolbar(
                penActive: _examPenActive,
                onPenPressed: () => setState(() => _examPenActive = !_examPenActive),
                onUndo: _examMarker.undo,
                canUndo: _examMarker.canUndo,
              );
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: <Widget>[
              _passagePage('A', widget.content.passageA),
              _passagePage('B', widget.content.passageB),
              _passagePage('C', widget.content.passageC),
            ],
          ),
        ),
        _BottomSubmit(label: s.dailySubmitGrade, onTap: _submit),
      ],
    );
  }

  Widget _passagePage(String letter, String passage) {
    final AppStrings s = AppStrings.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: <Widget>[
        _Panel(
          label: s.dailyReadingLetterLabel(letter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: passage.isEmpty
                  ? Text(
                      s.dailyReadingBodyMissing,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        height: 1.8,
                        color: Color(0xFF9CA3AF),
                      ),
                    )
                  : HighlightableExamText(
                      text: readingPassagePlainForHighlight(passage),
                      textStyle: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        height: 1.8,
                        color: Color(0xFFD9D9D9),
                      ),
                      highlightKey: 'reading_passage_$letter',
                      marker: _examMarker,
                      penActive: _examPenActive,
                      onHighlightCommitted: _commitExamHighlight,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._forPassage(letter).map(_questionTile),
      ],
    );
  }

  Widget _questionTile(ReadingQuestionItem q) {
    final AppStrings s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Panel(
        label: 'Q${q.globalNumber}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (q.questionType != null && q.questionType!.isNotEmpty) ...<Widget>[
              Text(
                q.questionType!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                  fontFamily: 'system-ui',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (q.groupInstruction != null && q.groupInstruction!.isNotEmpty) ...<Widget>[
              HighlightableExamText(
                text: q.groupInstruction!,
                textStyle: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: HtmlDesignTokens.textMain.withValues(alpha: 0.94),
                  fontFamily: 'system-ui',
                ),
                highlightKey: 'reading_q${q.globalNumber}_instr',
                marker: _examMarker,
                penActive: _examPenActive,
                onHighlightCommitted: _commitExamHighlight,
              ),
              const SizedBox(height: 8),
            ],
            if (_readingShowSharedContentBlock(q)) ...<Widget>[
              HighlightableExamText(
                text: q.sharedContent!,
                textStyle: const TextStyle(
                  fontSize: 13,
                  height: 1.42,
                  color: HtmlDesignTokens.textSub,
                  fontFamily: 'system-ui',
                ),
                highlightKey: 'reading_q${q.globalNumber}_shared',
                marker: _examMarker,
                penActive: _examPenActive,
                onHighlightCommitted: _commitExamHighlight,
              ),
              const SizedBox(height: 8),
            ],
            HighlightableReadingStem(
              body: q.body,
              textStyle: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: HtmlDesignTokens.textMain,
                fontFamily: 'system-ui',
              ),
              highlightKey: 'reading_q${q.globalNumber}_stem',
              marker: _examMarker,
              penActive: _examPenActive,
              onHighlightCommitted: _commitExamHighlight,
            ),
            const SizedBox(height: 10),
            if (q.options != null)
              ...q.options!.entries.map(
                (MapEntry<String, String> e) => _LetterOption(
                  letter: e.key,
                  text: e.value,
                  showLetterBadge: !_readingIsTfngOptions(q.options),
                  selected: _answers[q.globalNumber] == e.key,
                  onTap: () => setState(() => _answers[q.globalNumber] = e.key),
                ),
              )
            else
              TextField(
                controller: _text[q.globalNumber],
                onChanged: (_) => setState(() {}),
                maxLines: 3,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 14),
                decoration: InputDecoration(
                  hintText: s.dailyFillAnswerHint,
                  hintStyle: const TextStyle(color: HtmlDesignTokens.textSub),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _readingIsTfngOptions(Map<String, String>? o) {
  if (o == null || o.length != 3) {
    return false;
  }
  return o.containsKey('TRUE') && o.containsKey('FALSE') && o.containsKey('NOT GIVEN');
}

/// 题组 `shared_content`：选择题选项已解析为 chips，不再重复展示原文；人物匹配与摘要小标题仍展示。
bool _readingShowSharedContentBlock(ReadingQuestionItem q) {
  if (q.sharedContent == null || q.sharedContent!.isEmpty) {
    return false;
  }
  if (q.questionType == 'Multiple Choice') {
    return false;
  }
  return true;
}

bool _readingMatch(String user, String correct) {
  final String u = user.trim().toLowerCase();
  final String c = correct.trim().toLowerCase();
  if (u.isEmpty) {
    return false;
  }
  if (c.contains('/')) {
    return c.split('/').map((String e) => e.trim().toLowerCase()).any((String p) => u == p || u.contains(p));
  }
  return u == c;
}

class _WritingBody extends ConsumerStatefulWidget {
  const _WritingBody({
    required this.content,
    required this.timeLeft,
  });

  final WritingTaskContent content;
  final ValueListenable<int> timeLeft;

  @override
  ConsumerState<_WritingBody> createState() => _WritingBodyState();
}

class _WritingBodyState extends ConsumerState<_WritingBody> {
  late final TextEditingController _c1;
  late final TextEditingController _c2;
  final ExamMarkerController _examMarker = ExamMarkerController();
  bool _examPenActive = false;

  void _commitExamHighlight() {
    if (mounted) {
      setState(() => _examPenActive = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _c1 = TextEditingController();
    _c2 = TextEditingController();
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  int _words(String s) {
    final Iterable<String> parts = s.trim().split(RegExp(r'\s+'));
    if (s.trim().isEmpty) {
      return 0;
    }
    return parts.length;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              ListenableBuilder(
                listenable: _examMarker,
                builder: (BuildContext context, _) {
                  return ExamMarkerToolbar(
                    penActive: _examPenActive,
                    onPenPressed: () => setState(() => _examPenActive = !_examPenActive),
                    onUndo: _examMarker.undo,
                    canUndo: _examMarker.canUndo,
                  );
                },
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  widget.content.task1ImageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    color: HtmlDesignTokens.glassCard,
                    child: Text(
                      s.dailyWritingImageMissing,
                      style: const TextStyle(color: HtmlDesignTokens.textSub, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                label: 'Task 1',
                child: HighlightableExamText(
                  text: widget.content.task1Body,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'system-ui',
                  ),
                  highlightKey: 'writing_task1_prompt',
                  marker: _examMarker,
                  penActive: _examPenActive,
                  onHighlightCommitted: _commitExamHighlight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c1,
                onChanged: (_) => setState(() {}),
                maxLines: 6,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 15),
                decoration: _writeDecoration(s.dailyWritingTask1Hint),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  s.dailyWritingWordsProgress(_words(_c1.text), 150),
                  style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
                ),
              ),
              const SizedBox(height: 20),
              _Panel(
                label: 'Task 2',
                child: HighlightableExamText(
                  text: widget.content.task2Body,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'system-ui',
                  ),
                  highlightKey: 'writing_task2_prompt',
                  marker: _examMarker,
                  penActive: _examPenActive,
                  onHighlightCommitted: _commitExamHighlight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _c2,
                onChanged: (_) => setState(() {}),
                maxLines: 10,
                style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 15),
                decoration: _writeDecoration(s.dailyWritingTask2Hint),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  s.dailyWritingWordsProgress(_words(_c2.text), 250),
                  style: const TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        ),
        _BottomSubmit(
          label: s.dailyWritingSubmitForAiReview,
          color: const Color(0xFFF59E0B),
          onTap: () => unawaited(_reviewWriting()),
        ),
      ],
    );
  }

  /// Task 1 + Task 2：**两篇英文作文**由 DashScope [NewsMockAIService.gradeDailyWritingFullExam] 生成点评（需密钥与月度额度）。
  Future<void> _reviewWriting() async {
    final NewsMockAIService svc = ref.read(newsMockAiServiceProvider);
    if (!svc.hasApiKey) {
      _reviewWritingHeuristic();
      return;
    }
    final bool writingAiOk = await ref.read(appDataServiceProvider).canUseWritingAiThisMonth();
    if (!mounted) {
      return;
    }
    if (!writingAiOk) {
      showAppTopSnackBar(
        context,
        Text(AppStrings.of(context).dailyWritingAiQuotaExceeded),
      );
      _reviewWritingHeuristic();
      return;
    }
    showAiFeedbackGeneratingDialog(context);
    try {
      final bool feedbackEnglish = !AppStrings.of(context).isZh;
      final DailyWritingAiGrade g = await svc.gradeDailyWritingFullExam(
        task1Prompt: widget.content.task1Body,
        task2Prompt: widget.content.task2Body,
        task1Essay: _c1.text,
        task2Essay: _c2.text,
        feedbackEnglish: feedbackEnglish,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      unawaited(
        ref.read(appDataServiceProvider).recordWritingAiReviewCompleted(),
      );
      _showDailyWritingAiReviewSheet(
        context: context,
        taskResponse: g.taskResponse,
        coherence: g.coherence,
        lexical: g.lexical,
        grammar: g.grammar,
        overall: g.overall,
        aiPowered: true,
        summaryZh: g.feedbackZh.trim(),
        task1FeedbackZh: g.task1FeedbackZh?.trim(),
        task2FeedbackZh: g.task2FeedbackZh?.trim(),
        extraActions: <Widget>[
          _ActionTextButton(
            label: AppStrings.of(context).dailyWritingViewModels,
            onTap: () => _showPlainDialog(
              context,
              AppStrings.of(context).dailyWritingModelsTitle,
              'Task 1:\n${widget.content.modelEssayTask1}\n\nTask 2:\n${widget.content.modelEssayTask2}',
            ),
          ),
        ],
      );
      unawaited(
        _recordDailyPracticeOutcome(
          context,
          ref,
          skill: 'writing',
          ieltsBand: g.overall,
        ),
      );
    } on Object catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        showAppTopSnackBar(
          context,
          Text('${AppStrings.of(context).dailyWritingAiFailed}$e'),
        );
      }
      _reviewWritingHeuristic();
    }
  }

  void _reviewWritingHeuristic() {
    final int w1 = _words(_c1.text);
    final int w2 = _words(_c2.text);
    final double tr = _scoreTaskResponse(w1, w2);
    final double cc = _scoreCoherence(_c1.text, _c2.text);
    final double lr = _scoreLexical(_c1.text, _c2.text);
    final double gr = _scoreGrammar(_c1.text, _c2.text);
    final double overall = ((tr + cc + lr + gr) / 4 * 2).round() / 2;
    final AppStrings str = AppStrings.of(context);
    _showDailyWritingAiReviewSheet(
      context: context,
      taskResponse: tr,
      coherence: cc,
      lexical: lr,
      grammar: gr,
      overall: overall,
      aiPowered: false,
      summaryZh: str.dailyWritingHeuristicSummary(w1, w2),
      task1FeedbackZh: null,
      task2FeedbackZh: null,
      extraActions: <Widget>[
        _ActionTextButton(
          label: str.dailyWritingViewRulesLabel,
          onTap: () => _showPlainDialog(
            context,
            str.dailyWritingRulesTitle,
            str.dailyWritingRulesBody,
          ),
        ),
        _ActionTextButton(
          label: str.dailyWritingViewModelsShort,
          onTap: () => _showPlainDialog(
            context,
            str.dailyWritingModelsTitle,
            'Task 1:\n${widget.content.modelEssayTask1}\n\nTask 2:\n${widget.content.modelEssayTask2}',
          ),
        ),
      ],
    );
    unawaited(
      _recordDailyPracticeOutcome(
        context,
        ref,
        skill: 'writing',
        ieltsBand: overall,
      ),
    );
  }

  double _scoreTaskResponse(int w1, int w2) {
    double s = 5.5;
    if (w1 >= 150) s += 1;
    if (w2 >= 250) s += 1.5;
    return s.clamp(4, 8.5);
  }

  double _scoreCoherence(String a, String b) {
    final int p = '\n\n'.allMatches('$a\n$b').length + 1;
    return (5.5 + (p >= 4 ? 1.0 : 0.2)).clamp(4, 8.0);
  }

  double _scoreLexical(String a, String b) {
    final List<String> words = ('$a $b').toLowerCase().split(RegExp(r'[^a-z]+')).where((String e) => e.isNotEmpty).toList();
    if (words.isEmpty) return 4;
    final double ratio = words.toSet().length / words.length;
    return (4.5 + ratio * 5).clamp(4, 8.5);
  }

  double _scoreGrammar(String a, String b) {
    final int sentenceCount = RegExp(r'[.!?]').allMatches('$a $b').length;
    final int commaCount = ','.allMatches('$a $b').length;
    return (5 + (sentenceCount > 6 ? 1 : 0) + (commaCount > 8 ? 0.5 : 0)).clamp(4, 8.0).toDouble();
  }

  InputDecoration _writeDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: HtmlDesignTokens.textSub.withValues(alpha: 0.8)),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: HtmlDesignTokens.primaryLight),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}

class _SpeakingBody extends ConsumerStatefulWidget {
  const _SpeakingBody({
    required this.content,
    required this.pink,
  });

  final SpeakingTaskContent content;
  final Color pink;

  @override
  ConsumerState<_SpeakingBody> createState() => _SpeakingBodyState();
}

class _BottomSubmit extends StatelessWidget {
  const _BottomSubmit({
    required this.label,
    required this.onTap,
    this.color = HtmlDesignTokens.primary,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 20);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: HtmlDesignTokens.glassBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(100),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(100),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewItem {
  const _ReviewItem({
    required this.number,
    required this.userAnswer,
    required this.rightAnswer,
    required this.correct,
    required this.analysis,
  });

  final int number;
  final String userAnswer;
  final String rightAnswer;
  final bool correct;
  final String analysis;
}

/// 听力 / 阅读提交后，将错题写入本地存档（与「错题笔记档案」联动）。
Future<void> _syncPracticeExamMistakesToLocalStore({
  required WidgetRef ref,
  required AppStrings strings,
  required String skill,
  required int readingTestNumber,
  required List<_ReviewItem> items,
}) async {
  if (ref.read(devMockLoginProvider)) {
    return;
  }
  final uid = ref.read(appDataServiceProvider).currentUser?.id;
  if (uid == null) {
    return;
  }
  final svc = ref.read(appDataServiceProvider);
  if (!svc.isBackendAvailable) {
    return;
  }
  final List<_ReviewItem> wrong = items.where((_ReviewItem e) => !e.correct).toList();
  if (wrong.isEmpty) {
    return;
  }
  try {
    for (final _ReviewItem it in wrong) {
      final String questionKey = skill == 'listening'
          ? 'listening_${it.number}'
          : 'reading_${readingTestNumber}_${it.number}';
      final String title = skill == 'listening'
          ? strings.dailyWrongNoteListeningTitle(it.number)
          : strings.dailyWrongNoteReadingTitle(it.number, readingTestNumber);
      final String desc = it.analysis.trim().isEmpty
          ? strings.dailyWrongNoteAnswerSummary(it.userAnswer, it.rightAnswer)
          : (it.analysis.length > 220 ? '${it.analysis.substring(0, 220)}…' : it.analysis);
      await svc.upsertPracticeExamWrong(
        skill: skill,
        questionKey: questionKey,
        title: title,
        description: desc,
        userAnswer: it.userAnswer,
        correctAnswer: it.rightAnswer,
      );
    }
    ref.read(profileRevisionProvider.notifier).state++;
  } catch (_) {}
}

class _ActionTextButton extends StatelessWidget {
  const _ActionTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(label));
  }
}

/// 将当前试卷答对数换算为「满分 40 题」下的等效答对题数（四舍五入），再查雅思听力/阅读对照表。
int _listeningReadingEquivalentRaw40(int correct, int totalQuestions) {
  if (totalQuestions <= 0) {
    return 0;
  }
  if (totalQuestions == 40) {
    return correct.clamp(0, 40);
  }
  return ((correct * 40.0) / totalQuestions).round().clamp(0, 40);
}

Future<void> _recordDailyPracticeOutcome(
  BuildContext context,
  WidgetRef ref, {
  required String skill,
  required double ieltsBand,
}) async {
  if (!isLoggedIn(ref)) {
    return;
  }
  try {
    final DailyPracticeApplyResult r =
        await ref.read(appDataServiceProvider).applyDailyPracticeModule(
              skill: skill,
              ieltsBand: ieltsBand,
            );
    ref.read(profileRevisionProvider.notifier).state++;
    if (!context.mounted) {
      return;
    }
    if (r.ePointsGranted > 0) {
      final AppStrings str = AppStrings.of(context);
      showAppTopSnackBar(
        context,
        Text(str.dailyPracticeRewardSnackBar(r.ePointsGranted, r.balanceAfter)),
      );
    }
  } catch (_) {}
}

/// 雅思听力与阅读共用：答对题数（按 40 题制）→ Band。
/// 区间与官方换算表一致（39–40→9 … 1→1.0；0 题视为无有效成绩记 0）。
double _ieltsBandFromRawCorrectCount40(int c) {
  final int r = c.clamp(0, 40);
  if (r <= 0) {
    return 0;
  }
  const List<(int, double)> bands = <(int, double)>[
    (39, 9),
    (37, 8.5),
    (35, 8),
    (33, 7.5),
    (30, 7),
    (27, 6.5),
    (23, 6),
    (20, 5.5),
    (16, 5),
    (13, 4.5),
    (10, 4),
    (6, 3.5),
    (4, 3),
    (3, 2.5),
    (2, 2),
    (1, 1),
  ];
  for (final (int minCorrect, double band) in bands) {
    if (r >= minCorrect) {
      return band;
    }
  }
  return 0;
}

double _ieltsListeningReadingBand(int correct, int totalQuestions) {
  return _ieltsBandFromRawCorrectCount40(_listeningReadingEquivalentRaw40(correct, totalQuestions));
}

String _formatIeltsBandDisplay(double v) {
  if (v <= 0) {
    return '—';
  }
  return v.toStringAsFixed(1);
}

void _showReviewSheet({
  required BuildContext context,
  required String title,
  required double band,
  required String rawSummary,
  required List<_ReviewItem> items,
  List<Widget> extraActions = const <Widget>[],
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A103C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      final AppStrings str = AppStrings.of(context);
      final String bandStr = _formatIeltsBandDisplay(band);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      HtmlDesignTokens.accent.withValues(alpha: 0.22),
                      const Color(0xFF7C3AED).withValues(alpha: 0.28),
                    ],
                  ),
                  border: Border.all(
                    color: HtmlDesignTokens.accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: HtmlDesignTokens.accent.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      str.dailyReviewIeltsEstimate,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.4,
                        color: HtmlDesignTokens.accent.withValues(alpha: 0.95),
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bandStr,
                      style: TextStyle(
                        fontSize: 56,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        color: HtmlDesignTokens.accent,
                        fontFamily: 'system-ui',
                        shadows: <Shadow>[
                          Shadow(
                            color: HtmlDesignTokens.accent.withValues(alpha: 0.45),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: HtmlDesignTokens.glassBorder),
                      ),
                      child: Text(
                        str.dailyReviewCorrectSummary(rawSummary),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: HtmlDesignTokens.textMain,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  str.dailyReviewPerQuestion,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  children: items
                      .map(
                        (_ReviewItem e) => ListTile(
                          dense: true,
                          title: Text(
                            str.dailyReviewYourVsCorrect(e.number, e.userAnswer, e.rightAnswer),
                            style: TextStyle(color: e.correct ? Colors.greenAccent : Colors.redAccent),
                          ),
                          subtitle: Text(e.analysis, style: const TextStyle(color: HtmlDesignTokens.textSub)),
                        ),
                      )
                      .toList(),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: extraActions,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 听说读写 · 写作模块专用：Task1+Task2 全方位 AI 评价面板（与环球快讯「全科批改」布局区分）。
void _showDailyWritingAiReviewSheet({
  required BuildContext context,
  required double taskResponse,
  required double coherence,
  required double lexical,
  required double grammar,
  required double overall,
  required bool aiPowered,
  required String summaryZh,
  String? task1FeedbackZh,
  String? task2FeedbackZh,
  required List<Widget> extraActions,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.42,
        maxChildSize: 0.96,
        builder: (BuildContext context, ScrollController scrollController) {
          return _DailyWritingFullReviewSheet(
            scrollController: scrollController,
            taskResponse: taskResponse,
            coherence: coherence,
            lexical: lexical,
            grammar: grammar,
            overall: overall,
            aiPowered: aiPowered,
            summaryZh: summaryZh,
            task1FeedbackZh: task1FeedbackZh,
            task2FeedbackZh: task2FeedbackZh,
            extraActions: extraActions,
          );
        },
      );
    },
  );
}

class _DailyWritingFullReviewSheet extends StatelessWidget {
  const _DailyWritingFullReviewSheet({
    required this.scrollController,
    required this.taskResponse,
    required this.coherence,
    required this.lexical,
    required this.grammar,
    required this.overall,
    required this.aiPowered,
    required this.summaryZh,
    this.task1FeedbackZh,
    this.task2FeedbackZh,
    required this.extraActions,
  });

  final ScrollController scrollController;
  final double taskResponse;
  final double coherence;
  final double lexical;
  final double grammar;
  final double overall;
  final bool aiPowered;
  final String summaryZh;
  final String? task1FeedbackZh;
  final String? task2FeedbackZh;
  final List<Widget> extraActions;

  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberLight = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final String overallStr = _formatIeltsBandDisplay(overall);
    final EdgeInsets pad = EdgeInsets.fromLTRB(
      20,
      0,
      12,
      24 + MediaQuery.paddingOf(context).bottom,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: HtmlDesignTokens.chromeBackdrop,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: HtmlDesignTokens.glassBorder),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HtmlDesignTokens.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: pad,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _amber.withValues(alpha: 0.45)),
                        ),
                        child: const Icon(Icons.article_rounded, color: _amberLight, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              s.dailyWritingPanelLine1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                                fontFamily: 'system-ui',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.dailyWritingPanelLine2,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: HtmlDesignTokens.textMain,
                                fontFamily: 'system-ui',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _amber.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                s.dailyWritingPanelBadge,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: HtmlDesignTokens.textSub.withValues(alpha: 0.96),
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: HtmlDesignTokens.textSub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          _amber.withValues(alpha: 0.22),
                          const Color(0xFF7C3AED).withValues(alpha: 0.12),
                        ],
                      ),
                      border: Border.all(color: _amberLight.withValues(alpha: 0.55), width: 1.5),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _amber.withValues(alpha: 0.22),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          s.dailyWritingPanelOverallTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: _amberLight.withValues(alpha: 0.95),
                            fontFamily: 'system-ui',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          overallStr,
                          style: TextStyle(
                            fontSize: 54,
                            height: 1.02,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2,
                            color: _amberLight,
                            fontFamily: 'system-ui',
                            shadows: <Shadow>[
                              Shadow(
                                color: _amber.withValues(alpha: 0.45),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          aiPowered ? s.dailyWritingPanelSubtitleAi : s.dailyWritingPanelSubtitleLocal,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: HtmlDesignTokens.textSub.withValues(alpha: 0.92),
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.dailyWritingPanelFourDims,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _WritingDimTile(
                          shortLabel: 'TR',
                          title: s.dailyWritingDimTaskResponse,
                          value: taskResponse,
                          accent: _amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WritingDimTile(
                          shortLabel: 'CC',
                          title: s.dailyWritingDimCc,
                          value: coherence,
                          accent: _amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _WritingDimTile(
                          shortLabel: 'LR',
                          title: s.dailyWritingDimLr,
                          value: lexical,
                          accent: _amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WritingDimTile(
                          shortLabel: 'GRA',
                          title: s.dailyWritingDimGra,
                          value: grammar,
                          accent: _amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _WritingFeedbackSection(
                    icon: Icons.auto_awesome_rounded,
                    title: s.dailyWritingSectionSummaryTitle,
                    subtitle: s.dailyWritingSectionSummarySub,
                    body: summaryZh.trim().isEmpty ? s.dailyWritingNoneYet : summaryZh.trim(),
                    accent: _amber,
                  ),
                  if (task1FeedbackZh != null && task1FeedbackZh!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _WritingFeedbackSection(
                      icon: Icons.bar_chart_rounded,
                      title: s.dailyWritingSectionT1Title,
                      subtitle: s.dailyWritingSectionT1Sub,
                      body: task1FeedbackZh!.trim(),
                      accent: const Color(0xFF38BDF8),
                    ),
                  ],
                  if (task2FeedbackZh != null && task2FeedbackZh!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _WritingFeedbackSection(
                      icon: Icons.record_voice_over_rounded,
                      title: s.dailyWritingSectionT2Title,
                      subtitle: s.dailyWritingSectionT2Sub,
                      body: task2FeedbackZh!.trim(),
                      accent: HtmlDesignTokens.primaryLight,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    aiPowered ? s.dailyWritingPanelFootnoteAi : s.dailyWritingPanelFootnoteLocal,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: HtmlDesignTokens.textSub.withValues(alpha: 0.88),
                      fontFamily: 'system-ui',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: extraActions,
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.newsMockGradeClose),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WritingDimTile extends StatelessWidget {
  const _WritingDimTile({
    required this.shortLabel,
    required this.title,
    required this.value,
    required this.accent,
  });

  final String shortLabel;
  final String title;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String v = _formatIeltsBandDisplay(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent.withValues(alpha: 0.95),
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                v,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.95),
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

class _WritingFeedbackSection extends StatelessWidget {
  const _WritingFeedbackSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 22, color: accent.withValues(alpha: 0.95)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: HtmlDesignTokens.textSub.withValues(alpha: 0.9),
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

void _showSpeakingAiScoreSheet({
  required BuildContext context,
  required double fluency,
  required double lexical,
  required double grammar,
  required double pronunciation,
  required double overall,
  required String feedbackZh,
  bool aiPowered = false,
  String? subtitleOverride,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A103C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      final AppStrings str = AppStrings.of(context);
      final String overallStr = _formatIeltsBandDisplay(overall);
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Text(
                str.dailySpeakingAiTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                overallStr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF61D2),
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitleOverride ??
                    (aiPowered ? str.dailySpeakingAiSubtitleAi : str.dailySpeakingAiSubtitleLocal),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 18),
              _WritingCriterionRow(label: 'Fluency & Coherence', value: fluency),
              _WritingCriterionRow(label: 'Lexical Resource', value: lexical),
              _WritingCriterionRow(label: 'Grammar', value: grammar),
              _WritingCriterionRow(label: 'Pronunciation', value: pronunciation),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  str.dailySpeakingFeedbackLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HtmlDesignTokens.accent.withValues(alpha: 0.95),
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                feedbackZh.isEmpty ? str.dailySpeakingFeedbackEmpty : feedbackZh,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: HtmlDesignTokens.textMain.withValues(alpha: 0.92),
                  fontFamily: 'system-ui',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(str.newsMockGradeClose),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WritingCriterionRow extends StatelessWidget {
  const _WritingCriterionRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final String v = _formatIeltsBandDisplay(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HtmlDesignTokens.textMain,
                fontFamily: 'system-ui',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: HtmlDesignTokens.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HtmlDesignTokens.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: HtmlDesignTokens.accent,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                fontFamily: 'system-ui',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showPlainDialog(
  BuildContext context,
  String title,
  String content, {
  List<Widget> actions = const <Widget>[],
}) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AppStrings str = AppStrings.of(dialogContext);
      return AlertDialog(
        backgroundColor: const Color(0xFF1A103C),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(color: HtmlDesignTokens.textSub, height: 1.5)),
        ),
        actions: <Widget>[
          ...actions,
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(str.newsMockGradeClose),
          ),
        ],
      );
    },
  );
}

class _SpeakingBodyState extends ConsumerState<_SpeakingBody> {
  static final math.Random _rng = math.Random();
  late int _examIndex;

  late final AudioPlayer _playbackPlayer;
  StreamSubscription<void>? _playerCompleteSub;
  final ValueNotifier<double> _inputLevel = ValueNotifier<double>(0);

  bool _isRecording = false;
  bool _playingBack = false;
  bool _audioBusy = false;
  bool _grading = false;
  String? _recordPath;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTick;
  Timer? _fakeLevelTimer;

  late final TextEditingController _transcriptController;

  static const Duration _maxRecordDuration = Duration(minutes: 2);
  static const int _kMinTranscriptChars = 20;

  List<String> get _examPool {
    return <String>[...widget.content.part1Questions, ...widget.content.part2CueCards];
  }

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    final List<String> pool = _examPool;
    _examIndex = pool.isEmpty ? 0 : _rng.nextInt(pool.length);
    _playbackPlayer = AudioPlayer();
    _playerCompleteSub = _playbackPlayer.onPlayerComplete.listen((void _) {
      if (mounted) {
        setState(() => _playingBack = false);
      }
    });
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _recordTick?.cancel();
    _fakeLevelTimer?.cancel();
    _inputLevel.dispose();
    _playerCompleteSub?.cancel();
    unawaited(_playbackPlayer.dispose());
    super.dispose();
  }

  Future<void> _submitSpeakingAiReview() async {
    final AppStrings str = AppStrings.of(context);
    if (_grading) return;
    if (_recordPath == null) {
      showAppTopSnackBar(context, Text(str.dailySpeakingRecordFirst));
      return;
    }
    final String raw = _transcriptController.text.trim();
    final String transcript = raw.length >= _kMinTranscriptChars
        ? raw
        : (isSimulatedRecordingPath(_recordPath)
            ? buildDailySpeakingSimulatedTranscript(
                cue: _examCue(str),
                duration: _recordElapsed,
                userNotes: raw,
              )
            : raw);
    if (transcript.length < _kMinTranscriptChars) {
      showAppTopSnackBar(
        context,
        Text(str.dailySpeakingTranscriptTooShort(_kMinTranscriptChars)),
      );
      return;
    }
    setState(() => _grading = true);
    showAiFeedbackGeneratingDialog(context);
    try {
      // 伪 AI：模拟云端生成延迟后展示预设点评（不接 DashScope）
      await Future<void>.delayed(Duration(milliseconds: 1600 + _rng.nextInt(1200)));
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
    if (!mounted) return;
    const double fluency = 6.5;
    const double lexical = 6.0;
    const double grammar = 6.5;
    const double pronunciation = 6.0;
    const double overall = 6.5;
    _showSpeakingAiScoreSheet(
      context: context,
      fluency: fluency,
      lexical: lexical,
      grammar: grammar,
      pronunciation: pronunciation,
      overall: overall,
      feedbackZh: str.dailySpeakingPseudoFeedbackBody,
      aiPowered: false,
      subtitleOverride: str.dailySpeakingPseudoSubtitle,
    );
    if (mounted) setState(() => _grading = false);
  }

  void _stopFakeInputLevel() {
    _fakeLevelTimer?.cancel();
    _fakeLevelTimer = null;
    _inputLevel.value = 0;
  }

  void _startFakeInputLevel() {
    _stopFakeInputLevel();
    _fakeLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final double t = DateTime.now().millisecondsSinceEpoch / 420;
      final double wave = (math.sin(t) * 0.42 + 0.48 + _rng.nextDouble() * 0.08).clamp(0.0, 1.0);
      _inputLevel.value = wave;
    });
  }

  String _examCue(AppStrings s) {
    final List<String> pool = _examPool;
    if (pool.isEmpty) {
      return s.dailySpeakingCueMissing;
    }
    return pool[_examIndex.clamp(0, pool.length - 1)];
  }

  Future<void> _discardRecordingSession() async {
    _recordTick?.cancel();
    _stopFakeInputLevel();
    await _playbackPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() => _playingBack = false);
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = false;
      _recordPath = null;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _shuffleExam() async {
    final List<String> pool = _examPool;
    if (pool.length <= 1) {
      return;
    }
    await _discardRecordingSession();
    if (!mounted) {
      return;
    }
    setState(() {
      int n;
      do {
        n = _rng.nextInt(pool.length);
      } while (n == _examIndex);
      _examIndex = n;
    });
  }

  Future<void> _toggleMic() async {
    if (_audioBusy) {
      return;
    }
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    if (!mounted) {
      return;
    }
    await _playbackPlayer.stop();
    if (_playingBack && mounted) {
      setState(() => _playingBack = false);
    }
    if (_recordPath != null) {
      if (mounted) {
        setState(() => _recordPath = null);
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = true;
      _recordElapsed = Duration.zero;
      _recordPath = null;
      _audioBusy = false;
    });
    _startFakeInputLevel();
    _recordTick?.cancel();
    _recordTick = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _recordElapsed += const Duration(seconds: 1);
      });
      if (_recordElapsed >= _maxRecordDuration) {
        t.cancel();
        unawaited(_stopRecording());
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) {
      return;
    }
    _recordTick?.cancel();
    _stopFakeInputLevel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = false;
      _recordPath = kSimulatedRecordingPathSentinel;
      _audioBusy = false;
    });
  }

  Future<void> _deleteRecording() async {
    if (_isRecording || _recordPath == null || _audioBusy) {
      return;
    }
    await _playbackPlayer.stop();
    if (mounted) {
      setState(() {
        _playingBack = false;
        _recordPath = null;
        _recordElapsed = Duration.zero;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordPath == null || _isRecording || _audioBusy) {
      return;
    }
    if (isSimulatedRecordingPath(_recordPath)) {
      showAppTopSnackBar(context, Text(AppStrings.of(context).dailySpeakingPlaybackDemo));
      return;
    }
    final String path = _recordPath!;
    if (_playingBack) {
      await _playbackPlayer.stop();
      if (mounted) {
        setState(() => _playingBack = false);
      }
      return;
    }
    setState(() => _audioBusy = true);
    try {
      await _playbackPlayer.stop();
      final Source src =
          path.startsWith('blob:') || path.startsWith('http') ? UrlSource(path) : DeviceFileSource(path);
      await _playbackPlayer.play(src);
      if (mounted) {
        setState(() {
          _playingBack = true;
          _audioBusy = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _audioBusy = false);
        showAppTopSnackBar(context, Text(AppStrings.of(context).dailyPlaybackFailed(e)));
      }
    }
  }

  String _recordingHint(AppStrings s) {
    if (_isRecording) {
      return s.dailySpeakingRecordingHint(
        _formatSpeakMmss(_recordElapsed),
        _formatSpeakMmss(_maxRecordDuration),
      );
    }
    if (_recordPath != null) {
      return s.dailySpeakingRecordedHint;
    }
    return s.dailySpeakingIdleHint;
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final bool canDelete = !_isRecording && _recordPath != null && !_audioBusy;
    final bool canPlay = !_isRecording &&
        _recordPath != null &&
        !_audioBusy &&
        !isSimulatedRecordingPath(_recordPath);
    final Color ringColor = _isRecording ? const Color(0xFFF43F5E) : widget.pink;
    final Color fillColor = _isRecording ? const Color(0xFFDC2626) : widget.pink;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        _Panel(
          label: s.dailySpeakingPanelLabel,
          labelColor: widget.pink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _examCue(s),
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: HtmlDesignTokens.textMain,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _examPool.length <= 1 ? null : () => unawaited(_shuffleExam()),
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: Text(s.dailySpeakingShuffle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: s.dailySpeakingDeleteRecording,
                onPressed: canDelete ? () => unawaited(_deleteRecording()) : null,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: canDelete ? HtmlDesignTokens.textSub : HtmlDesignTokens.textSub.withValues(alpha: 0.35),
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _audioBusy ? null : () => unawaited(_toggleMic()),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: ringColor.withValues(alpha: 0.55), width: 2.5),
                            boxShadow: _isRecording
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : <BoxShadow>[
                                    BoxShadow(color: widget.pink.withValues(alpha: 0.35), blurRadius: 20),
                                  ],
                          ),
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fillColor,
                            boxShadow: <BoxShadow>[
                              BoxShadow(color: fillColor.withValues(alpha: 0.45), blurRadius: 18),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _playingBack ? s.newsMockStopPlayback : s.newsMockPlayback,
                onPressed: canPlay ? () => unawaited(_togglePlayback()) : null,
                icon: Icon(
                  _playingBack ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
                  color: canPlay ? HtmlDesignTokens.accent : HtmlDesignTokens.accent.withValues(alpha: 0.35),
                  size: 32,
                ),
              ),
            ],
          ),
        ValueListenableBuilder<double>(
            valueListenable: _inputLevel,
            builder: (BuildContext context, double level, _) {
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: <Widget>[
                    Text(
                      _isRecording ? s.dailySpeakingMicLevelRecording : s.dailySpeakingMicLevelIdle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HtmlDesignTokens.textSub.withValues(alpha: _isRecording ? 0.95 : 0.52),
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    MicInputLevelMeter(level: _isRecording ? level : 0, active: _isRecording),
                  ],
                ),
              );
            },
          ),
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Text(
              _recordingHint(s),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: HtmlDesignTokens.textSub.withValues(alpha: _isRecording ? 1 : 0.9),
                fontFamily: 'system-ui',
                fontWeight: _isRecording ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
            controller: _transcriptController,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            style: const TextStyle(color: HtmlDesignTokens.textMain, fontSize: 14, fontFamily: 'system-ui'),
            decoration: InputDecoration(
              hintText: s.dailySpeakingTranscriptHint(_kMinTranscriptChars),
              hintStyle: TextStyle(color: HtmlDesignTokens.textSub.withValues(alpha: 0.75), fontSize: 13),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF7C3AED),
          borderRadius: BorderRadius.circular(100),
          child: InkWell(
            onTap: _grading ? null : () => unawaited(_submitSpeakingAiReview()),
            borderRadius: BorderRadius.circular(100),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  _grading ? s.dailySpeakingSubmitAi : s.dailySpeakingSubmitLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.label,
    required this.child,
    this.labelColor = HtmlDesignTokens.primaryLight,
  });

  final String label;
  final Widget child;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: labelColor,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LetterOption extends StatelessWidget {
  const _LetterOption({
    required this.letter,
    required this.text,
    this.showLetterBadge = true,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool showLetterBadge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: 15,
      height: 1.35,
      color: selected ? HtmlDesignTokens.accent : HtmlDesignTokens.textMain,
      fontFamily: 'system-ui',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? HtmlDesignTokens.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: selected ? HtmlDesignTokens.accent : Colors.white.withValues(alpha: 0.1),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? <BoxShadow>[BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.18), blurRadius: 12)]
                  : null,
            ),
            child: showLetterBadge
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? HtmlDesignTokens.accent : Colors.white.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.black87 : HtmlDesignTokens.textMain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text, style: labelStyle)),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(text, style: labelStyle),
                  ),
          ),
        ),
      ),
    );
  }
}
