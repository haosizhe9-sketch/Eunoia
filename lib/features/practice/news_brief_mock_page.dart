import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/practice/simulated_speaking.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/news_mock_ai_service.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/ai_feedback_loading_dialog.dart';
import '../../core/ui/app_snackbar.dart';
import 'widgets/mic_input_level_meter.dart';

String _formatMmss(Duration d) {
  final int m = d.inMinutes.remainder(60);
  final int s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 今日环球快讯模考：外刊语料 + 阅读/写作/口语；生成与批改对接阿里云百炼（OpenAI 兼容）。
class NewsBriefMockPage extends ConsumerStatefulWidget {
  const NewsBriefMockPage({super.key});

  @override
  ConsumerState<NewsBriefMockPage> createState() => _NewsBriefMockPageState();
}

class _NewsBriefMockPageState extends ConsumerState<NewsBriefMockPage> {
  static const Duration _examLimit = Duration(minutes: 45);
  static const Duration _maxNewsSpeakingRecord = Duration(minutes: 2);
  static const Color _newsSpeakingMicPink = Color(0xFFFF61D2);

  Timer? _examTimer;

  Duration _remaining = _examLimit;
  bool _articleExpanded = false;

  bool _paperLoading = true;
  NewsMockPaper? _paper;
  List<int?> _readingChoices = <int?>[];

  final TextEditingController _essayController = TextEditingController();
  final TextEditingController _speakingController = TextEditingController();

  late final AudioPlayer _playbackPlayer;
  StreamSubscription<void>? _playerCompleteSub;
  final ValueNotifier<double> _inputLevel = ValueNotifier<double>(0);
  final math.Random _levelRng = math.Random();

  bool _isRecording = false;
  bool _playingBack = false;
  bool _audioBusy = false;
  String? _recordPath;
  Duration _recordElapsed = Duration.zero;
  Duration _completedSpeakingDuration = Duration.zero;
  Timer? _recordTick;
  Timer? _fakeLevelTimer;
  bool _speakingAttempted = false;

  bool _grading = false;

  bool _accessChecking = true;
  bool _accessAllowed = false;
  bool _isProUser = false;
  String _selectedDateKey = '';

  @override
  void initState() {
    super.initState();
    _essayController.addListener(() => setState(() {}));
    _speakingController.addListener(() => setState(() {}));
    _playbackPlayer = AudioPlayer();
    _playerCompleteSub = _playbackPlayer.onPlayerComplete.listen((void _) {
      if (mounted) {
        setState(() => _playingBack = false);
      }
    });
    _examTimer = Timer.periodic(const Duration(seconds: 1), _tickExam);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrapAccessAndPaper()));
  }

  Future<void> _bootstrapAccessAndPaper() async {
    final supa = ref.read(appDataServiceProvider);
    _selectedDateKey = NewsMockAIService.chinaCalendarDateKey();
    try {
      if (supa.currentUser == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _accessChecking = false;
          _accessAllowed = false;
        });
        return;
      }
      final bool ok = await supa.canAccessNewsBriefMock();
      if (!mounted) {
        return;
      }
      setState(() {
        _accessChecking = false;
        _accessAllowed = ok;
        _isProUser = supa.currentUserIsPro;
      });
      if (ok) {
        await _loadPaperForSelectedDate();
      }
    } on StateError {
      if (!mounted) {
        return;
      }
      setState(() {
        _accessChecking = false;
        _accessAllowed = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _accessChecking = false;
        _accessAllowed = false;
      });
    }
  }

  Future<void> _loadPaperForSelectedDate() async {
    final NewsMockAIService svc = ref.read(newsMockAiServiceProvider);
    setState(() => _paperLoading = true);
    try {
      final NewsMockPaper p = _isProUser
          ? await svc.loadPaperForChinaCalendarDate(_selectedDateKey)
          : await svc.loadDailyPaperSharedByAllUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _paper = p;
        _readingChoices = List<int?>.filled(p.reading.length, null);
        _essayController.clear();
        _speakingController.clear();
        _articleExpanded = false;
        _paperLoading = false;
      });
      unawaited(_clearSpeakingAll());
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      final NewsMockPaper fb = ref.read(newsMockAiServiceProvider).fallbackPaper();
      setState(() {
        _paper = fb;
        _readingChoices = List<int?>.filled(fb.reading.length, null);
        _paperLoading = false;
      });
      showAppTopSnackBar(context, Text('${AppStrings.of(context).newsMockPaperLoadFailed}$e'));
    }
  }

  List<String> _chinaPastDateKeys({int days = 90}) {
    final List<String> out = <String>[];
    final DateTime chinaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    for (int i = 0; i < days; i++) {
      final DateTime d = chinaNow.subtract(Duration(days: i));
      out.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    return out;
  }

  /// 口语批改用的文本：演示录音且正文较短时合成充实上下文，便于模型给出详评。
  String _resolvedSpeakingTextForGrade(NewsMockPaper paper) {
    final String raw = _speakingController.text.trim();
    if (isSimulatedRecordingPath(_recordPath) && raw.length < 80) {
      return buildNewsMockSimulatedSpeakingBody(
        cue: paper.speakingCue,
        hints: paper.speakingHints,
        duration: _completedSpeakingDuration,
        userNotes: raw,
      );
    }
    return raw;
  }

  /// 仅替换 **口语** 长评为预设文案；**写作**（英文作文 AI 评价）与阅读结果保持 [NewsMockAIService.gradeSubmission] 返回值不变。
  NewsMockGradeResult _applyPseudoSpeakingFeedbackOnly(
    NewsMockGradeResult r,
    AppStrings str,
  ) {
    final NewsMockSpeakingGrade spk = r.speaking;
    return NewsMockGradeResult(
      readingItems: r.readingItems,
      readingCorrectCount: r.readingCorrectCount,
      writing: r.writing,
      speaking: NewsMockSpeakingGrade(
        fluency: spk.fluency,
        lexical: spk.lexical,
        grammar: spk.grammar,
        pronunciation: spk.pronunciation,
        overall: spk.overall,
        feedbackZh: str.newsMockSpeakingPseudoFeedbackBody,
      ),
      summaryZh: r.summaryZh,
    );
  }

  /// 答卷提交：默认 **客户端直连** DashScope（构建注入 `DASHSCOPE_API_KEY`）。
  /// 成功时写作区块展示模型对用户 **英文作文** 的 `writing.feedback`；失败时降级 [NewsMockAIService.gradeSubmissionLocal]。
  Future<void> _submit() async {
    final NewsMockPaper? paper = _paper;
    if (paper == null || _grading) return;
    final NewsMockAIService svc = ref.read(newsMockAiServiceProvider);
    final bool feedbackEnglish = !AppStrings.of(context).isZh;
    setState(() => _grading = true);
    showAiFeedbackGeneratingDialog(context);
    NewsMockGradeResult result;
    final String speakingForGrade = _resolvedSpeakingTextForGrade(paper);
    try {
      result = await svc.gradeSubmission(
        paper: paper,
        readingChoiceIndices: _readingChoices,
        essayText: _essayController.text,
        speakingText: speakingForGrade,
        feedbackEnglish: feedbackEnglish,
      );
    } on Object catch (e) {
      if (mounted) {
        showAppTopSnackBar(context, Text('${AppStrings.of(context).newsMockGradeRequestFailed}$e'));
      }
      result = svc.gradeSubmissionLocal(
        paper: paper,
        readingChoiceIndices: _readingChoices,
        essayText: _essayController.text,
        speakingText: speakingForGrade,
        feedbackEnglish: feedbackEnglish,
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _grading = false);
      }
    }
    if (!mounted) return;
    final NewsMockGradeResult displayResult =
        _applyPseudoSpeakingFeedbackOnly(result, AppStrings.of(context));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HtmlDesignTokens.chromeBackdrop,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _GradeResultSheet(result: displayResult),
    );
    unawaited(_afterNewsBriefGraded());
  }

  Future<void> _afterNewsBriefGraded() async {
    try {
      await ref.read(appDataServiceProvider).recordNewsBriefMockCompleted();
      ref.read(profileRevisionProvider.notifier).state++;
    } catch (_) {}
  }

  void _tickExam(Timer _) {
    if (_remaining.inSeconds <= 0) return;
    setState(() {
      _remaining -= const Duration(seconds: 1);
      if (_remaining.inSeconds <= 0) {
        _remaining = Duration.zero;
        _examTimer?.cancel();
        if (mounted) {
          showAppTopSnackBar(context, Text(AppStrings.of(context).newsMockExamTimeEnded));
        }
      }
    });
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
      final double wave =
          (math.sin(t) * 0.42 + 0.48 + _levelRng.nextDouble() * 0.08).clamp(0.0, 1.0);
      _inputLevel.value = wave;
    });
  }

  String _newsSpeakingRecordingHint(AppStrings str) {
    if (_isRecording) {
      return str.newsMockSpeakingRecording(
        _formatMmss(_recordElapsed),
        _formatMmss(_maxNewsSpeakingRecord),
      );
    }
    if (_recordPath != null) {
      return str.newsMockSpeakingDoneHint;
    }
    return str.newsMockSpeakingIdleHint;
  }

  Future<void> _toggleMic() async {
    if (_audioBusy) {
      return;
    }
    if (_isRecording) {
      await _stopSpeakingRecording();
      return;
    }
    await _startSpeakingRecording();
  }

  Future<void> _startSpeakingRecording() async {
    if (!mounted) {
      return;
    }
    await _playbackPlayer.stop();
    if (_playingBack && mounted) {
      setState(() => _playingBack = false);
    }
    if (_recordPath != null && mounted) {
      setState(() => _recordPath = null);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = true;
      _recordElapsed = Duration.zero;
      _recordPath = null;
      _audioBusy = false;
      _speakingAttempted = true;
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
      if (_recordElapsed >= _maxNewsSpeakingRecord) {
        t.cancel();
        unawaited(_stopSpeakingRecording());
      }
    });
  }

  Future<void> _stopSpeakingRecording() async {
    if (!_isRecording) {
      return;
    }
    _recordTick?.cancel();
    _stopFakeInputLevel();
    final Duration elapsed = _recordElapsed;
    if (!mounted) {
      return;
    }
    setState(() {
      _isRecording = false;
      _recordPath = kSimulatedRecordingPathSentinel;
      _completedSpeakingDuration = elapsed;
      _recordElapsed = Duration.zero;
      _audioBusy = false;
      _speakingAttempted = true;
    });
  }

  Future<void> _deleteSpeakingClip() async {
    if (_isRecording || _recordPath == null || _audioBusy) {
      return;
    }
    await _playbackPlayer.stop();
    if (mounted) {
      setState(() {
        _playingBack = false;
        _recordPath = null;
      });
    }
  }

  Future<void> _toggleSpeakingPlayback() async {
    if (_recordPath == null || _isRecording || _audioBusy) {
      return;
    }
    if (isSimulatedRecordingPath(_recordPath)) {
      showAppTopSnackBar(context, Text(AppStrings.of(context).newsMockPlaybackDemoOnly));
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

  Future<void> _clearSpeakingAll() async {
    _recordTick?.cancel();
    _stopFakeInputLevel();
    await _playbackPlayer.stop();
    _speakingController.clear();
    if (mounted) {
      setState(() {
        _playingBack = false;
        _isRecording = false;
        _recordPath = null;
        _recordElapsed = Duration.zero;
        _completedSpeakingDuration = Duration.zero;
        _speakingAttempted = false;
        _audioBusy = false;
      });
    }
  }

  double get _progress {
    if (_readingChoices.isEmpty) return 0;
    double v = 0;
    final int answeredReading = _readingChoices.whereType<int>().length;
    v += (answeredReading / _readingChoices.length) * 0.44;
    final int words = _wordCount;
    if (words >= 40) v += 0.28;
    if (_speakingAttempted ||
        _speakingController.text.trim().isNotEmpty ||
        (_recordPath != null && _recordPath!.isNotEmpty)) {
      v += 0.28;
    }
    return v.clamp(0.0, 1.0);
  }

  int get _wordCount {
    final String t = _essayController.text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _recordTick?.cancel();
    _fakeLevelTimer?.cancel();
    _inputLevel.dispose();
    _playerCompleteSub?.cancel();
    unawaited(_playbackPlayer.dispose());
    _essayController.dispose();
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings str = AppStrings.of(context);
    if (_accessChecking) {
      return Scaffold(
        backgroundColor: HtmlDesignTokens.gachaSubBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: HtmlDesignTokens.textMain),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: HtmlDesignTokens.accent),
        ),
      );
    }
    if (!_accessAllowed) {
      return Scaffold(
        backgroundColor: HtmlDesignTokens.gachaSubBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: HtmlDesignTokens.textMain),
            onPressed: () => context.pop(),
          ),
          title: Text(
            str.newsMockTitleAccessDenied,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HtmlDesignTokens.textMain,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('🔒', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 16),
                Text(
                  str.newsMockMonthlyLimitTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HtmlDesignTokens.textMain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  str.newsMockMonthlyLimitBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    context.pop();
                    context.go('/profile');
                  },
                  child: Text(str.newsMockGoSubscribe),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -48,
            right: -72,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      HtmlDesignTokens.primary.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _MockAppBar(
                  brandSubtitle: str.newsMockAppBarBrand,
                  remaining: _remaining,
                  progress: _progress,
                  onBack: () => context.pop(),
                  onMore: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: HtmlDesignTokens.chromeBackdrop,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (BuildContext ctx) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppStrings.of(ctx).newsMockHelpTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: HtmlDesignTokens.textMain,
                                fontFamily: 'system-ui',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.of(ctx).newsMockHelpBody,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: HtmlDesignTokens.textSub,
                                fontFamily: 'system-ui',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_isProUser)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: <Widget>[
                        Text(
                          str.newsMockPastPaperLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedDateKey,
                            dropdownColor: const Color(0xFF1A162B),
                            style: const TextStyle(
                              fontSize: 14,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                            items: _chinaPastDateKeys()
                                .map(
                                  (String k) => DropdownMenuItem<String>(
                                    value: k,
                                    child: Text(k),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? v) {
                              if (v == null || v == _selectedDateKey) {
                                return;
                              }
                              setState(() => _selectedDateKey = v);
                              unawaited(_loadPaperForSelectedDate());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _paperLoading || _paper == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const CircularProgressIndicator(
                                color: HtmlDesignTokens.accent,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                str.newsMockLoadingPaper,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: HtmlDesignTokens.textSub,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                          children: <Widget>[
                            _SourceSection(
                              title: _paper!.title,
                              articlePreview: _paper!.articlePreview,
                              articleFull: _paper!.articleFull,
                              articleExpanded: _articleExpanded,
                              onExpand: () =>
                                  setState(() => _articleExpanded = true),
                            ),
                            const SizedBox(height: 8),
                            const _SectionDivider(),
                            _SectionHeader(
                              emoji: '📖',
                              title: str.newsMockSectionReadingShort,
                              accent: HtmlDesignTokens.primaryLight,
                            ),
                            ...List<Widget>.generate(_paper!.reading.length, (
                              int idx,
                            ) {
                              final NewsMockReadingQuestion q =
                                  _paper!.reading[idx];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      idx == _paper!.reading.length - 1 ? 0 : 16,
                                ),
                                child: _McqBlock(
                                  label:
                                      'Question ${idx + 1} / ${_paper!.reading.length}',
                                  question: q.question,
                                  options: q.options,
                                  optionTags: q.optionTags,
                                  selected: _readingChoices[idx],
                                  onSelect: (int i) => setState(
                                    () => _readingChoices[idx] = i,
                                  ),
                                ),
                              );
                            }),
                            const _SectionDivider(),
                            _SectionHeader(
                              emoji: '✍️',
                              title: str.newsMockSectionWritingTask2,
                              accent: const Color(0xFFFBBF24),
                            ),
                            _WritingBlock(
                              prompt: _paper!.writingPrompt,
                              controller: _essayController,
                              wordCount: _wordCount,
                            ),
                            const _SectionDivider(),
                            _SectionHeader(
                              emoji: '🗣️',
                              title: str.newsMockSectionSpeakingPart2,
                              accent: const Color(0xFFFF61D2),
                            ),
                            _SpeakingBlock(
                              cue: _paper!.speakingCue,
                              hints: _paper!.speakingHints,
                              speakingController: _speakingController,
                              isRecording: _isRecording,
                              playingBack: _playingBack,
                              audioBusy: _audioBusy,
                              recordPath: _recordPath,
                              inputLevel: _inputLevel,
                              recordingHint: _newsSpeakingRecordingHint(str),
                              micIdleColor: _newsSpeakingMicPink,
                              onMicTap: () => unawaited(_toggleMic()),
                              onDeleteClip: () => unawaited(_deleteSpeakingClip()),
                              onTogglePlayback: () => unawaited(_toggleSpeakingPlayback()),
                              onClearAll: () => unawaited(_clearSpeakingAll()),
                              onClearTextOnly: () => setState(() => _speakingController.clear()),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SubmitBar(
              enabled: !_paperLoading &&
                  _paper != null &&
                  !_grading,
              loading: _grading,
              onSubmit: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockAppBar extends StatelessWidget {
  const _MockAppBar({
    required this.brandSubtitle,
    required this.remaining,
    required this.progress,
    required this.onBack,
    required this.onMore,
  });

  final String brandSubtitle;
  final Duration remaining;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: HtmlDesignTokens.compactSubpageAppBarPadding,
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_left,
                  color: HtmlDesignTokens.textMain,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: HtmlDesignTokens.glassCard,
                  side: BorderSide(color: HtmlDesignTokens.glassBorder),
                ),
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    const Text(
                      'GLOBAL NEWS MOCK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: HtmlDesignTokens.accent,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      brandSubtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _formatMmss(remaining),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      color: HtmlDesignTokens.textMain,
                      fontFamily: 'system-ui',
                    ),
                  ),
                  IconButton(
                    onPressed: onMore,
                    icon: const Icon(
                      Icons.more_horiz,
                      color: HtmlDesignTokens.textSub,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: HtmlDesignTokens.glassBorder,
              color: HtmlDesignTokens.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({
    required this.title,
    required this.articlePreview,
    required this.articleFull,
    required this.articleExpanded,
    required this.onExpand,
  });

  final String title;
  final String articlePreview;
  final String articleFull;
  final bool articleExpanded;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: HtmlDesignTokens.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            AppStrings.of(context).newsMockSourceLabel,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: HtmlDesignTokens.primaryLight,
              fontFamily: 'system-ui',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title.isEmpty ? 'Reading passage' : title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: HtmlDesignTokens.textMain,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.glassCard,
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AnimatedCrossFade(
                firstChild: Text(
                  articlePreview.isEmpty ? articleFull : articlePreview,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'Georgia',
                  ),
                ),
                secondChild: Text(
                  articleFull.isEmpty ? articlePreview : articleFull,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: HtmlDesignTokens.textMain,
                    fontFamily: 'Georgia',
                  ),
                ),
                crossFadeState: articleExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
                sizeCurve: Curves.easeOutCubic,
              ),
              if (!articleExpanded) ...<Widget>[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: onExpand,
                    child: Text(
                      AppStrings.of(context).newsMockExpandFull,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HtmlDesignTokens.accent,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Container(height: 1, color: HtmlDesignTokens.glassBorder),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.accent,
  });

  final String emoji;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: accent,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

class _McqBlock extends StatelessWidget {
  const _McqBlock({
    required this.label,
    required this.question,
    required this.options,
    this.optionTags,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final String question;
  final List<String> options;

  /// 选项左侧圆标，默认 A/B/C…
  final List<String>? optionTags;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: HtmlDesignTokens.textMain,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 14),
        ...List<Widget>.generate(options.length, (int i) {
          final bool on = selected == i;
          final String tag = optionTags != null && i < optionTags!.length
              ? optionTags![i]
              : String.fromCharCode(65 + i);
          final double tagFontSize = tag.length > 1 ? 10 : 12;
          return Padding(
            padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 10),
            child: Material(
              color: HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: on
                          ? HtmlDesignTokens.accent
                          : HtmlDesignTokens.glassBorder,
                      width: on ? 1.5 : 1,
                    ),
                    color: on
                        ? HtmlDesignTokens.accent.withValues(alpha: 0.08)
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: tag.length > 1 ? 30 : 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? HtmlDesignTokens.accent
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: tagFontSize,
                            fontWeight: FontWeight.w800,
                            color: on
                                ? HtmlDesignTokens.gachaSubBg
                                : HtmlDesignTokens.textSub,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          options[i],
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                            color: on
                                ? HtmlDesignTokens.accent
                                : HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _WritingBlock extends StatelessWidget {
  const _WritingBlock({
    required this.prompt,
    required this.controller,
    required this.wordCount,
  });

  final String prompt;
  final TextEditingController controller;
  final int wordCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            prompt.isEmpty
                ? 'Discuss both views and give your own opinion.'
                : prompt,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          maxLines: 10,
          style: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: HtmlDesignTokens.textMain,
            fontFamily: 'system-ui',
          ),
          cursorColor: HtmlDesignTokens.primaryLight,
          decoration: InputDecoration(
            hintText: AppStrings.of(context).newsMockEssayHint,
            hintStyle: TextStyle(
              color: HtmlDesignTokens.textSub.withValues(alpha: 0.85),
            ),
            filled: true,
            fillColor: HtmlDesignTokens.glassCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: HtmlDesignTokens.primary.withValues(alpha: 0.65),
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Words: $wordCount',
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 11,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            color: HtmlDesignTokens.textSub,
            fontFamily: 'system-ui',
          ),
        ),
      ],
    );
  }
}

class _SpeakingBlock extends StatelessWidget {
  const _SpeakingBlock({
    required this.cue,
    required this.hints,
    required this.speakingController,
    required this.isRecording,
    required this.playingBack,
    required this.audioBusy,
    required this.recordPath,
    required this.inputLevel,
    required this.recordingHint,
    required this.micIdleColor,
    required this.onMicTap,
    required this.onDeleteClip,
    required this.onTogglePlayback,
    required this.onClearAll,
    required this.onClearTextOnly,
  });

  final String cue;
  final String hints;
  final TextEditingController speakingController;
  final bool isRecording;
  final bool playingBack;
  final bool audioBusy;
  final String? recordPath;
  final ValueNotifier<double> inputLevel;
  final String recordingHint;
  final Color micIdleColor;
  final VoidCallback onMicTap;
  final VoidCallback onDeleteClip;
  final VoidCallback onTogglePlayback;
  final VoidCallback onClearAll;
  final VoidCallback onClearTextOnly;

  @override
  Widget build(BuildContext context) {
    final AppStrings str = AppStrings.of(context);
    final bool canDelete = !isRecording && recordPath != null && !audioBusy;
    final bool canPlay = !isRecording &&
        recordPath != null &&
        !audioBusy &&
        !isSimulatedRecordingPath(recordPath);
    final Color ringColor = isRecording ? const Color(0xFFF43F5E) : micIdleColor;
    final Color fillColor = isRecording ? const Color(0xFFDC2626) : micIdleColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Column(
        children: <Widget>[
          Text(
            cue.isEmpty
                ? 'Describe a topic related to the reading passage.'
                : cue,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hints.isEmpty
                ? 'You should say what it is, how it works, and explain how you feel.'
                : hints,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: speakingController,
            maxLines: 5,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
            cursorColor: HtmlDesignTokens.primaryLight,
            decoration: InputDecoration(
              hintText: str.newsMockSpeakingNotesHint,
              hintStyle: TextStyle(
                color: HtmlDesignTokens.textSub.withValues(alpha: 0.85),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: HtmlDesignTokens.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: HtmlDesignTokens.primary.withValues(alpha: 0.65),
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClearTextOnly,
              child: Text(
                str.newsMockClearText,
                style: const TextStyle(fontSize: 12, fontFamily: 'system-ui'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: str.newsMockDeleteRecording,
                onPressed: canDelete ? onDeleteClip : null,
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
                  onTap: audioBusy ? null : onMicTap,
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
                            boxShadow: isRecording
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : <BoxShadow>[
                                    BoxShadow(color: micIdleColor.withValues(alpha: 0.35), blurRadius: 20),
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
                            isRecording ? Icons.stop_rounded : Icons.mic_rounded,
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
                tooltip: playingBack ? str.newsMockStopPlayback : str.newsMockPlayback,
                onPressed: canPlay ? onTogglePlayback : null,
                icon: Icon(
                  playingBack ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
                  color: canPlay ? HtmlDesignTokens.accent : HtmlDesignTokens.accent.withValues(alpha: 0.35),
                  size: 32,
                ),
              ),
            ],
          ),
          ValueListenableBuilder<double>(
            valueListenable: inputLevel,
            builder: (BuildContext context, double level, _) {
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: <Widget>[
                    Text(
                      isRecording ? str.newsMockMicLevelRecording : str.newsMockMicLevelIdle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HtmlDesignTokens.textSub.withValues(alpha: isRecording ? 0.95 : 0.52),
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    MicInputLevelMeter(level: isRecording ? level : 0, active: isRecording),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: Text(
              recordingHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: HtmlDesignTokens.textSub.withValues(alpha: isRecording ? 1 : 0.9),
                fontFamily: 'system-ui',
                fontWeight: isRecording ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(str.newsMockClearSpeaking),
            style: TextButton.styleFrom(
              foregroundColor: HtmlDesignTokens.textSub,
              textStyle: const TextStyle(fontSize: 12, fontFamily: 'system-ui'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.onSubmit,
    this.enabled = true,
    this.loading = false,
  });

  final VoidCallback onSubmit;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final AppStrings str = AppStrings.of(context);
    final bool canTap = enabled && !loading;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            HtmlDesignTokens.gachaSubBg.withValues(alpha: 0),
            HtmlDesignTokens.gachaSubBg.withValues(alpha: 0.92),
            HtmlDesignTokens.gachaSubBg,
          ],
          stops: const <double>[0, 0.35, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Material(
            color: canTap
                ? HtmlDesignTokens.primary
                : HtmlDesignTokens.primary.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
            elevation: 0,
            child: InkWell(
              onTap: canTap ? onSubmit : null,
              borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (loading) ...<Widget>[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...<Widget>[
                        const Text('✨', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        loading ? str.newsMockSubmitGrading : str.newsMockSubmit,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ],
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

class _GradeResultSheet extends StatelessWidget {
  const _GradeResultSheet({required this.result});

  final NewsMockGradeResult result;

  @override
  Widget build(BuildContext context) {
    final NewsMockWritingGrade w = result.writing;
    final NewsMockSpeakingGrade spk = result.speaking;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (
        BuildContext context,
        ScrollController scrollCtrl,
      ) {
        final AppStrings str = AppStrings.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                str.newsMockGradeTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: HtmlDesignTokens.textMain,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: HtmlDesignTokens.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: HtmlDesignTokens.primaryLight.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  str.newsMockGradeFullExamBadge,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    color: HtmlDesignTokens.textSub.withValues(alpha: 0.95),
                                    fontFamily: 'system-ui',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: HtmlDesignTokens.textSub),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: <Widget>[
                    if (result.summaryZh.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          result.summaryZh,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    Text(
                      str.newsMockSectionReadingShort,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: HtmlDesignTokens.primaryLight,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      str.newsMockReadingCorrectCount(
                        result.readingCorrectCount,
                        result.readingItems.length,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...result.readingItems.map((NewsMockReadingGradeItem e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: HtmlDesignTokens.glassCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: HtmlDesignTokens.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                str.newsMockGradeYourChoice(
                                  'Q${e.indexOneBased}',
                                  e.correct,
                                  e.userChoiceLabel,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: e.correct
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFF43F5E),
                                  fontFamily: 'system-ui',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                str.newsMockGradeCorrectAnswer(e.correctChoiceLabel),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HtmlDesignTokens.textSub,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                e.explanationZh,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: HtmlDesignTokens.textMain,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      str.newsMockSectionWritingShort,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFBBF24),
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      str.newsMockWritingBandsLine(
                        w.taskResponse,
                        w.coherence,
                        w.lexical,
                        w.grammar,
                        w.overall,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      w.feedbackZh.isEmpty ? str.newsMockNoWritingFeedback : w.feedbackZh,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      str.newsMockSectionSpeakingShort,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF61D2),
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      str.newsMockSpeakingBandsLine(
                        spk.fluency,
                        spk.lexical,
                        spk.grammar,
                        spk.pronunciation,
                        spk.overall,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: HtmlDesignTokens.textSub,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spk.feedbackZh.isEmpty ? str.newsMockNoSpeakingFeedback : spk.feedbackZh,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: HtmlDesignTokens.textMain,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
