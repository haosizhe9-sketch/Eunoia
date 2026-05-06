import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/html_design_tokens.dart';
import 'word_tower_vocabulary.dart';

/// 每层作答时限（秒）：与 `index2.html` 参考规则一致。
int wordTowerSecondsForFloor(int floor) {
  if (floor >= 500) return 5;
  if (floor >= 250) return 10;
  if (floor >= 100) return 15;
  return 20;
}

class WordTowerPage extends ConsumerStatefulWidget {
  const WordTowerPage({super.key});

  @override
  ConsumerState<WordTowerPage> createState() => _WordTowerPageState();
}

class _WordTowerPageState extends ConsumerState<WordTowerPage> with TickerProviderStateMixin {
  static const Color _cyan = HtmlDesignTokens.accent;

  List<WordTowerEntry>? _bank;
  String? _loadError;

  /// 升层动画期间展示的层号（避免与 `_floor` 更新时机不一致）。
  int? _promoteBannerFloor;

  final Random _random = Random();

  int _floor = 1;
  final Set<int> _usedWordIndices = <int>{};

  WordTowerEntry? _current;
  int? _currentIndex;
  List<String>? _options;
  int? _correctOptionIndex;

  AnimationController? _countdown;
  late AnimationController _successAnim;
  late AnimationController _failAnim;

  late Animation<double> _successScale;
  late Animation<double> _successOpacity;
  late Animation<double> _failOpacity;
  late Animation<double> _failShake;

  bool _interactionLocked = false;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 720));
    _failAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _successScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.15).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 55),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 45),
    ]).animate(_successAnim);

    _successOpacity = CurvedAnimation(parent: _successAnim, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));

    _failOpacity = CurvedAnimation(parent: _failAnim, curve: const Interval(0.0, 0.25, curve: Curves.easeIn));
    _failShake = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _failAnim, curve: Curves.easeInOut),
    );

    _loadVocabulary();
  }

  Future<void> _loadVocabulary() async {
    try {
      final list = await WordTowerEntry.load();
      if (!mounted) return;
      if (list.length < 4) {
        setState(() => _loadError = '词库条目不足，无法出题');
        return;
      }
      setState(() => _bank = list);
      _beginQuestion();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  void _disposeCountdown() {
    _countdown?.dispose();
    _countdown = null;
  }

  void _beginQuestion() {
    final bank = _bank;
    if (bank == null || !mounted || _interactionLocked) return;

    if (_usedWordIndices.length >= bank.length) {
      _usedWordIndices.clear();
    }

    int idx;
    do {
      idx = _random.nextInt(bank.length);
    } while (_usedWordIndices.contains(idx));

    final entry = bank[idx];
    final distractors = _pickDistractors(entry, bank);

    final opts = <String>[entry.chinese, ...distractors]..shuffle(_random);
    final correctAt = opts.indexOf(entry.chinese);

    _disposeCountdown();
    final seconds = wordTowerSecondsForFloor(_floor);
    final countdown = AnimationController(
      vsync: this,
      duration: Duration(seconds: seconds),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _onTimeout();
        }
      });

    setState(() {
      _currentIndex = idx;
      _current = entry;
      _options = opts;
      _correctOptionIndex = correctAt;
      _countdown = countdown;
    });

    countdown.forward();
  }

  /// 从词库中抽取 3 个与正确答案中文不同、且彼此互不相同的干扰释义。
  List<String> _pickDistractors(WordTowerEntry correct, List<WordTowerEntry> bank) {
    final pool = bank.map((WordTowerEntry e) => e.chinese).where((String c) => c != correct.chinese).toSet().toList();
    if (pool.length < 3) {
      throw StateError('词库中可用的不同中文释义不足 3 个');
    }
    pool.shuffle(_random);
    return pool.take(3).toList();
  }

  void _onTimeout() {
    if (!mounted || _interactionLocked) return;
    _interactionLocked = true;
    _countdown?.stop();
    _playFailureAndPop();
  }

  void _onOptionTap(int index) {
    if (!mounted || _interactionLocked || _correctOptionIndex == null || _options == null) return;
    _interactionLocked = true;
    _countdown?.stop();

    if (index == _correctOptionIndex) {
      _playLevelUp();
    } else {
      final WordTowerEntry? mistaken = _current;
      final String wrongLabel = _options![index];
      _playFailureAndPop(mistakenWord: mistaken, wrongChinese: wrongLabel);
    }
  }

  Future<void> _syncRunEnd({
    required int floorReached,
    WordTowerEntry? mistakenWord,
    String? wrongChinese,
  }) async {
    if (!ref.read(devMockLoginProvider)) {
      final uid = ref.read(appDataServiceProvider).currentUser?.id;
      if (uid == null) return;
    } else {
      return;
    }
    final svc = ref.read(appDataServiceProvider);
    if (!svc.isBackendAvailable) return;
    try {
      await svc.mergeWordTowerMaxFloor(floorReached);
      await svc.applyDailyWordTowerRunCompleted(floorReached: floorReached);
      if (mistakenWord != null && wrongChinese != null) {
        await svc.upsertWordTowerWrong(
          english: mistakenWord.english,
          chinese: mistakenWord.chinese,
          wrongChinese: wrongChinese,
        );
      }
      ref.read(profileRevisionProvider.notifier).state++;
    } catch (_) {}
  }

  Future<void> _playLevelUp() async {
    if (!mounted) return;
    final int nextFloor = _floor + 1;
    setState(() => _promoteBannerFloor = nextFloor);
    await _successAnim.forward(from: 0);
    if (!mounted) return;
    final int? idx = _currentIndex;
    setState(() {
      _floor = nextFloor;
      if (idx != null) {
        _usedWordIndices.add(idx);
      }
    });
    await _successAnim.reverse();
    if (!mounted) return;
    setState(() {
      _promoteBannerFloor = null;
      _interactionLocked = false;
    });
    _beginQuestion();
  }

  Future<void> _playFailureAndPop({WordTowerEntry? mistakenWord, String? wrongChinese}) async {
    if (!mounted) return;
    final int floorReached = _floor;
    await _failAnim.forward(from: 0);
    if (!mounted) return;
    await _syncRunEnd(
      floorReached: floorReached,
      mistakenWord: mistakenWord,
      wrongChinese: wrongChinese,
    );
    if (!mounted) return;
    context.pop();
  }

  @override
  void dispose() {
    _disposeCountdown();
    _successAnim.dispose();
    _failAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bank = _bank;
    final error = _loadError;
    final bool loading = bank == null && error == null;
    final bool gameReady = bank != null && _current != null && _options != null && _countdown != null;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.25,
                  colors: <Color>[
                    Color(0x332DD4BF),
                    Color(0x001A103C),
                  ],
                  stops: <double>[0.0, 0.7],
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _interactionLocked ? null : () => context.pop(),
              ),
              title: const Text('无尽爬词塔'),
            ),
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '词库加载失败\n$error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: HtmlDesignTokens.textSub),
                      ),
                    ),
                  )
                else if (loading || !gameReady)
                  const Center(child: CircularProgressIndicator(color: _cyan))
                else
                  _buildGameBody(context),
              ],
            ),
          ),

          // 全屏蒙层（含顶栏区域），避免与外壳留白产生「贴图没铺满」的割裂感
          AnimatedBuilder(
            animation: _successAnim,
            builder: (BuildContext context, Widget? child) {
              if (_successAnim.value == 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35 * _successOpacity.value),
                  child: Center(
                    child: Transform.scale(
                      scale: _successScale.value,
                      child: Opacity(
                        opacity: _successOpacity.value.clamp(0.0, 1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.trending_up_rounded, size: 72, color: _cyan.withValues(alpha: 0.95)),
                            const SizedBox(height: 12),
                            Text(
                              '升至第 ${_promoteBannerFloor ?? _floor} 层',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          AnimatedBuilder(
            animation: _failAnim,
            builder: (BuildContext context, Widget? child) {
              if (_failAnim.value == 0) return const SizedBox.shrink();
              final t = _failShake.value;
              final dx = sin(t * pi * 6) * 10 * (1 - t * 0.5);
              return IgnorePointer(
                child: ColoredBox(
                  color: Color.lerp(Colors.transparent, const Color(0x66FF4D4D), _failOpacity.value)!,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Opacity(
                        opacity: Curves.easeOut.transform(_failOpacity.value.clamp(0.0, 1.0)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.close_rounded, size: 80, color: Colors.red.shade200),
                            const SizedBox(height: 16),
                            Text(
                              '挑战结束',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '返回练习 · 下次从第 1 层开始',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameBody(BuildContext context) {
    final countdown = _countdown!;
    final options = _options!;
    final current = _current!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: HtmlDesignTokens.stackedPageAppBarPadding.copyWith(bottom: 24),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1A2DD4BF),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0x4D2DD4BF)),
              ),
              child: Text(
                'Floor $_floor',
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: countdown,
              builder: (BuildContext context, Widget? child) {
                final v = (1.0 - countdown.value).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: _cyan,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              current.english,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    shadows: <Shadow>[
                      Shadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 20),
                    ],
                  ),
            ),
            const SizedBox(height: 48),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 16),
                itemBuilder: (BuildContext context, int i) {
                  final labels = <String>['A', 'B', 'C', 'D'];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _interactionLocked ? null : () => _onOptionTap(i),
                      borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: HtmlDesignTokens.glassCard,
                          borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
                          border: Border.all(color: HtmlDesignTokens.glassBorder),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${labels[i]}.',
                              style: const TextStyle(
                                color: _cyan,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                options[i],
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
