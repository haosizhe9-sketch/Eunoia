import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_session.dart';
import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/app_data_service.dart'
    show PracticeExamWrongRow, WordTowerWrongRow;
import '../../core/i18n/app_strings.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';

/// 错题笔记档案：爬词塔错词 + 听说读写错题（布局参考根目录 note.html，不修改该 HTML）。
class WrongNotesArchivePage extends ConsumerStatefulWidget {
  const WrongNotesArchivePage({super.key});

  @override
  ConsumerState<WrongNotesArchivePage> createState() =>
      _WrongNotesArchivePageState();
}

class _WrongNotesArchivePageState extends ConsumerState<WrongNotesArchivePage> {
  static const Color _writingOrange = Color(0xFFF5A623);

  bool _vocabTab = true;
  _ExamSkillFilter _examFilter = _ExamSkillFilter.all;
  bool _isMutating = false;

  late Future<List<WordTowerWrongRow>> _vocabFuture =
      Future<List<WordTowerWrongRow>>.value(<WordTowerWrongRow>[]);
  late Future<List<PracticeExamWrongRow>> _examFuture =
      Future<List<PracticeExamWrongRow>>.value(<PracticeExamWrongRow>[]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(appDataServiceProvider).canAccessWrongNotesArchive) {
        if (mounted) {
          showAppTopSnackBar(
            context,
            Text(AppStrings.of(context).wrongNotesProSnack),
          );
          context.pop();
        }
        return;
      }
      _reloadAllFromServer();
    });
  }

  void _reloadVocabFromServer() {
    if (!isLoggedIn(ref)) {
      setState(() {
        _vocabFuture = Future<List<WordTowerWrongRow>>.value(
          <WordTowerWrongRow>[],
        );
      });
      return;
    }
    setState(() {
      _vocabFuture = ref
          .read(appDataServiceProvider)
          .fetchWordTowerWrongWords();
    });
  }

  void _reloadExamFromServer() {
    if (!isLoggedIn(ref)) {
      setState(() {
        _examFuture = Future<List<PracticeExamWrongRow>>.value(
          <PracticeExamWrongRow>[],
        );
      });
      return;
    }
    setState(() {
      _examFuture = ref.read(appDataServiceProvider).fetchPracticeExamWrongs();
    });
  }

  void _reloadAllFromServer() {
    _reloadVocabFromServer();
    _reloadExamFromServer();
  }

  Future<bool> _confirmDangerAction({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteVocabWrong(_VocabWrongItem item) async {
    final AppStrings s = AppStrings.of(context);
    final bool confirmed = await _confirmDangerAction(
      title: s.wrongNotesDeleteWordTitle(item.word),
      content: s.wrongNotesDeleteWordBody(item.word),
      confirmText: s.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isMutating = true);
    try {
      await ref
          .read(appDataServiceProvider)
          .deleteWordTowerWrongByEnglish(item.englishKey);
      _reloadVocabFromServer();
      _showMessage(s.wrongNotesDeletedWord);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _deleteExamWrong(_ExamWrongItem item) async {
    final AppStrings s = AppStrings.of(context);
    final bool confirmed = await _confirmDangerAction(
      title: s.wrongNotesDeleteExamTitle,
      content: s.wrongNotesDeleteExamBody,
      confirmText: s.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isMutating = true);
    try {
      await ref
          .read(appDataServiceProvider)
          .deletePracticeExamWrong(
            skill: item.skillKey,
            questionKey: item.questionKey,
          );
      _reloadExamFromServer();
      _showMessage(s.wrongNotesDeletedExam);
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _clearCurrentTab() async {
    final AppStrings s = AppStrings.of(context);
    final String targetName =
        _vocabTab ? s.wrongNotesTabVocabName : s.wrongNotesTabExamName;
    final bool confirmed = await _confirmDangerAction(
      title: s.wrongNotesClearTitle,
      content: s.wrongNotesClearBody(targetName),
      confirmText: s.wrongNotesClearConfirm,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isMutating = true);
    try {
      final service = ref.read(appDataServiceProvider);
      if (_vocabTab) {
        await service.clearWordTowerWrongs();
        _reloadVocabFromServer();
      } else {
        await service.clearPracticeExamWrongs();
        _reloadExamFromServer();
      }
      _showMessage(s.wrongNotesCleared(targetName));
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  List<_VocabWrongItem> _mapWordTowerRows(
    List<WordTowerWrongRow> rows,
    AppStrings s,
  ) {
    return rows
        .map(
          (WordTowerWrongRow r) => _VocabWrongItem(
            englishKey: r.english,
            word: r.english,
            phonetic: '—',
            wrongMeaning: r.wrongChinese.trim().isEmpty
                ? s.wrongNotesWrongPick
                : r.wrongChinese.trim(),
            correctMeaning: r.chinese,
          ),
        )
        .toList();
  }

  static _ExamSkillFilter _skillFromDb(String s) {
    switch (s) {
      case 'listening':
        return _ExamSkillFilter.listening;
      case 'reading':
        return _ExamSkillFilter.reading;
      default:
        return _ExamSkillFilter.listening;
    }
  }

  static String _examDateLabel(DateTime? d) {
    if (d == null) {
      return '';
    }
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  List<_ExamWrongItem> _mapPracticeExamRows(
    List<PracticeExamWrongRow> rows,
    AppStrings s,
  ) {
    return rows
        .map(
          (PracticeExamWrongRow r) => _ExamWrongItem(
            skillKey: r.skill,
            questionKey: r.questionKey,
            skill: _skillFromDb(r.skill),
            dateLabel: _examDateLabel(r.updatedAt),
            title: r.title.isNotEmpty ? r.title : r.questionKey,
            description: r.description.trim().isNotEmpty
                ? r.description
                : s.dailyWrongNoteAnswerSummary(r.userAnswer, r.correctAnswer),
            statusLabel: s.wrongNotesReviewPending,
            statusUsePrimary: false,
            actionLabel: s.wrongNotesActionView,
            actionHighlight: false,
          ),
        )
        .toList();
  }

  List<_ExamWrongItem> _applyExamFilter(List<_ExamWrongItem> all) {
    if (_examFilter == _ExamSkillFilter.all) {
      return all;
    }
    return all.where((_ExamWrongItem e) => e.skill == _examFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(profileRevisionProvider, (int? previous, int next) {
      if (isLoggedIn(ref)) {
        _reloadAllFromServer();
      }
    });

    if (!isLoggedIn(ref)) {
      final AppStrings gs = AppStrings.of(context);
      return Scaffold(
        backgroundColor: HtmlDesignTokens.gachaSubBg,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF160D27), HtmlDesignTokens.gachaSubBg],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: HtmlDesignTokens.subpageAppBarPadding,
                  child: Row(
                    children: <Widget>[
                      _CircleIconButton(
                        icon: Icons.chevron_left,
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          gs.wrongNotesAppBar,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.textMain,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.lock_outline,
                            size: 48,
                            color: HtmlDesignTokens.textSub.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            gs.wrongNotesLoginHintTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            gs.wrongNotesLoginHintBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: () => pushLoginPage(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: HtmlDesignTokens.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  HtmlDesignTokens.radiusLg,
                                ),
                              ),
                            ),
                            child: Text(
                              gs.wrongNotesLoginCta,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'system-ui',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final AppStrings s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: HtmlDesignTokens.gachaSubBg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF160D27), HtmlDesignTokens.gachaSubBg],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: MediaQuery.paddingOf(context).top + 40,
              left: 0,
              child: IgnorePointer(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        HtmlDesignTokens.primary.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: HtmlDesignTokens.subpageAppBarPadding,
                    child: Row(
                      children: <Widget>[
                        _CircleIconButton(
                          icon: Icons.chevron_left,
                          onPressed: () => context.pop(),
                        ),
                        Expanded(
                          child: Text(
                            s.wrongNotesAppBar,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: HtmlDesignTokens.textMain,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isMutating ? null : _clearCurrentTab,
                          child: Text(
                            _isMutating ? s.wrongNotesProcessing : s.wrongNotesToolbarClear,
                            style: TextStyle(
                              color: _isMutating
                                  ? HtmlDesignTokens.textSub
                                  : const Color(0xFFF87171),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 15),
                  child: _GlassTabs(
                    vocabLabel: s.wrongNotesTabVocabName,
                    examLabel: s.wrongNotesTabExamName,
                    vocabSelected: _vocabTab,
                    onVocab: () => setState(() => _vocabTab = true),
                    onExam: () => setState(() => _vocabTab = false),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _vocabTab
                        ? FutureBuilder<List<WordTowerWrongRow>>(
                            future: _vocabFuture,
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<List<WordTowerWrongRow>> snap,
                                ) {
                                  if (snap.connectionState ==
                                          ConnectionState.waiting &&
                                      !snap.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: HtmlDesignTokens.accent,
                                      ),
                                    );
                                  }
                                  final AppStrings loc = AppStrings.of(context);
                                  final List<_VocabWrongItem> items =
                                      _mapWordTowerRows(
                                        snap.data ?? <WordTowerWrongRow>[],
                                        loc,
                                      );
                                  if (items.isEmpty) {
                                    return ListView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        48,
                                        24,
                                        120,
                                      ),
                                      children: <Widget>[
                                        Text(
                                          loc.wrongNotesEmptyVocab,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: HtmlDesignTokens.textSub,
                                            fontSize: 14,
                                            fontFamily: 'system-ui',
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return _VocabListView(
                                    key: const ValueKey<String>('vocab'),
                                    items: items,
                                    onDelete: _isMutating
                                        ? null
                                        : _deleteVocabWrong,
                                  );
                                },
                          )
                        : FutureBuilder<List<PracticeExamWrongRow>>(
                            future: _examFuture,
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<List<PracticeExamWrongRow>>
                                  snap,
                                ) {
                                  if (snap.connectionState ==
                                          ConnectionState.waiting &&
                                      !snap.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: HtmlDesignTokens.accent,
                                      ),
                                    );
                                  }
                                  final AppStrings loc = AppStrings.of(context);
                                  final List<_ExamWrongItem> examItems =
                                      _applyExamFilter(
                                        _mapPracticeExamRows(
                                          snap.data ?? <PracticeExamWrongRow>[],
                                          loc,
                                        ),
                                      );
                                  return _ExamListView(
                                    key: ValueKey<String>(
                                      'exam_${_examFilter.name}_${examItems.length}',
                                    ),
                                    filter: _examFilter,
                                    onFilterChanged: (_ExamSkillFilter f) =>
                                        setState(() => _examFilter = f),
                                    items: examItems,
                                    writingOrange: _writingOrange,
                                    onDelete: _isMutating
                                        ? null
                                        : _deleteExamWrong,
                                  );
                                },
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExamSkillFilter { all, listening, reading, writing, speaking }

class _VocabWrongItem {
  const _VocabWrongItem({
    required this.englishKey,
    required this.word,
    required this.phonetic,
    required this.wrongMeaning,
    required this.correctMeaning,
  });

  final String englishKey;
  final String word;
  final String phonetic;
  final String wrongMeaning;
  final String correctMeaning;
}

class _ExamWrongItem {
  const _ExamWrongItem({
    required this.skillKey,
    required this.questionKey,
    required this.skill,
    required this.dateLabel,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusUsePrimary,
    required this.actionLabel,
    required this.actionHighlight,
  });

  final String skillKey;
  final String questionKey;
  final _ExamSkillFilter skill;
  final String dateLabel;
  final String title;
  final String description;
  final String statusLabel;
  final bool statusUsePrimary;
  final String actionLabel;
  final bool actionHighlight;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HtmlDesignTokens.textSub, size: 28),
        ),
      ),
    );
  }
}

class _GlassTabs extends StatelessWidget {
  const _GlassTabs({
    required this.vocabLabel,
    required this.examLabel,
    required this.vocabSelected,
    required this.onVocab,
    required this.onExam,
  });

  final String vocabLabel;
  final String examLabel;
  final bool vocabSelected;
  final VoidCallback onVocab;
  final VoidCallback onExam;

  static final Color _border = Colors.white.withValues(alpha: 0.04);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = (c.maxWidth - 8) / 2;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: vocabSelected ? 4 : 4 + w,
                top: 4,
                width: w,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C172D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onVocab,
                        borderRadius: BorderRadius.circular(999),
                        child: Center(
                          child: Text(
                            vocabLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: vocabSelected
                                  ? Colors.white
                                  : HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onExam,
                        borderRadius: BorderRadius.circular(999),
                        child: Center(
                          child: Text(
                            examLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: !vocabSelected
                                  ? Colors.white
                                  : HtmlDesignTokens.textSub,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VocabListView extends StatelessWidget {
  const _VocabListView({
    super.key,
    required this.items,
    required this.onDelete,
  });

  final List<_VocabWrongItem> items;
  final ValueChanged<_VocabWrongItem>? onDelete;

  static final Color _cardBorder = Colors.white.withValues(alpha: 0.04);

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (BuildContext context, int i) {
        final _VocabWrongItem e = items[i];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C172D),
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              e.word,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: HtmlDesignTokens.textMain,
                                letterSpacing: 0.5,
                                fontFamily: 'system-ui',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              e.phonetic,
                              style: const TextStyle(
                                fontSize: 14,
                                color: HtmlDesignTokens.textSub,
                                fontFamily: 'system-ui',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🔊', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete == null ? null : () => onDelete!(e),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFF87171),
                    tooltip: s.wrongNotesTooltipDelete,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _DiffRow(wrong: true, text: e.wrongMeaning),
                    const SizedBox(height: 10),
                    _DiffRow(wrong: false, text: e.correctMeaning),
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

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.wrong, required this.text});

  final bool wrong;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 16,
          child: Text(
            wrong ? '✕' : '✓',
            style: TextStyle(
              fontSize: 14,
              color: wrong ? const Color(0xFFF43F5E) : HtmlDesignTokens.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: wrong ? FontWeight.w500 : FontWeight.w600,
              color: wrong ? const Color(0xFFF43F5E) : HtmlDesignTokens.accent,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamListView extends StatelessWidget {
  const _ExamListView({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.items,
    required this.writingOrange,
    required this.onDelete,
  });

  final _ExamSkillFilter filter;
  final ValueChanged<_ExamSkillFilter> onFilterChanged;
  final List<_ExamWrongItem> items;
  final Color writingOrange;
  final ValueChanged<_ExamWrongItem>? onDelete;

  static final Color _cardBorder = Colors.white.withValues(alpha: 0.04);

  @override
  Widget build(BuildContext context) {
    final AppStrings str = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
      physics: const BouncingScrollPhysics(),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: <Widget>[
              _FilterPill(
                label: str.wrongNotesFilterAll,
                selected: filter == _ExamSkillFilter.all,
                onTap: () => onFilterChanged(_ExamSkillFilter.all),
              ),
              const SizedBox(width: 10),
              _FilterPill(
                label: str.wrongNotesFilterListening,
                selected: filter == _ExamSkillFilter.listening,
                onTap: () => onFilterChanged(_ExamSkillFilter.listening),
              ),
              const SizedBox(width: 10),
              _FilterPill(
                label: str.wrongNotesFilterReading,
                selected: filter == _ExamSkillFilter.reading,
                onTap: () => onFilterChanged(_ExamSkillFilter.reading),
              ),
              const SizedBox(width: 10),
              _FilterPill(
                label: str.wrongNotesFilterWriting,
                selected: filter == _ExamSkillFilter.writing,
                onTap: () => onFilterChanged(_ExamSkillFilter.writing),
              ),
              const SizedBox(width: 10),
              _FilterPill(
                label: str.wrongNotesFilterSpeaking,
                selected: filter == _ExamSkillFilter.speaking,
                onTap: () => onFilterChanged(_ExamSkillFilter.speaking),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              str.wrongNotesEmptyFiltered,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HtmlDesignTokens.textSub.withValues(alpha: 0.9),
                fontSize: 14,
                fontFamily: 'system-ui',
              ),
            ),
          )
        else
          ...items.map(
            (_ExamWrongItem e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ExamCard(
                item: e,
                cardBorder: _cardBorder,
                writingOrange: writingOrange,
                onDelete: onDelete,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static final Color _cardBorder = Colors.white.withValues(alpha: 0.04);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.1)
          : const Color(0xFF1C172D),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : _cardBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.item,
    required this.cardBorder,
    required this.writingOrange,
    required this.onDelete,
  });

  final _ExamWrongItem item;
  final Color cardBorder;
  final Color writingOrange;
  final ValueChanged<_ExamWrongItem>? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppStrings str = AppStrings.of(context);
    final String tagText;
    final Color tagFg;
    final Color tagBg;
    final Color tagBorder;
    switch (item.skill) {
      case _ExamSkillFilter.listening:
        tagText = str.wrongNotesFilterListening;
        tagFg = HtmlDesignTokens.accent;
        tagBg = HtmlDesignTokens.accent.withValues(alpha: 0.1);
        tagBorder = HtmlDesignTokens.accent.withValues(alpha: 0.2);
      case _ExamSkillFilter.reading:
        tagText = str.wrongNotesFilterReading;
        tagFg = HtmlDesignTokens.primaryLight;
        tagBg = HtmlDesignTokens.primaryLight.withValues(alpha: 0.1);
        tagBorder = HtmlDesignTokens.primaryLight.withValues(alpha: 0.2);
      case _ExamSkillFilter.writing:
        tagText = str.wrongNotesFilterWriting;
        tagFg = writingOrange;
        tagBg = writingOrange.withValues(alpha: 0.1);
        tagBorder = writingOrange.withValues(alpha: 0.2);
      case _ExamSkillFilter.speaking:
        tagText = str.wrongNotesFilterSpeaking;
        tagFg = const Color(0xFFFF61D2);
        tagBg = const Color(0xFFFF61D2).withValues(alpha: 0.1);
        tagBorder = const Color(0xFFFF61D2).withValues(alpha: 0.2);
      case _ExamSkillFilter.all:
        tagText = str.wrongNotesPracticeTag;
        tagFg = HtmlDesignTokens.textSub;
        tagBg = HtmlDesignTokens.textSub.withValues(alpha: 0.1);
        tagBorder = HtmlDesignTokens.textSub.withValues(alpha: 0.2);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C172D),
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tagBorder),
                ),
                child: Text(
                  tagText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tagFg,
                    letterSpacing: 0.5,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              Text(
                item.dateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: HtmlDesignTokens.textSub,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HtmlDesignTokens.textMain,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                item.statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: item.statusUsePrimary
                      ? HtmlDesignTokens.primaryLight
                      : HtmlDesignTokens.textSub,
                  fontFamily: 'system-ui',
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: item.actionHighlight
                      ? HtmlDesignTokens.accent
                      : HtmlDesignTokens.textMain,
                  backgroundColor: item.actionHighlight
                      ? HtmlDesignTokens.accent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  side: BorderSide(
                    color: item.actionHighlight
                        ? HtmlDesignTokens.accent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  item.actionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete == null ? null : () => onDelete!(item),
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFF87171),
                tooltip: str.wrongNotesTooltipDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
