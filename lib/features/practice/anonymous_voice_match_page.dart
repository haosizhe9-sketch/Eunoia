import 'dart:async';
import 'dart:math' show Random;
import 'dart:ui' show FontFeature, PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/community_demo_ids.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/providers/community_social_providers.dart';
import '../../core/theme/html_design_tokens.dart';
import '../../core/ui/app_snackbar.dart';
import 'anonymous_voice_match_controller.dart';
import 'daily_task_resource_loader.dart';

const int _kChatSeconds = 60;
const int _kMatchWaitSeconds = 60;
const String _kIcebreakerFallback =
    'Describe a movie you watched recently that you felt disappointed about.';
const String _kRemoteLabel = '烤鸭_8921';

/// 为 `false` 时走真实信令 + WebRTC；为 `true` 时约 1.6s 后进入模拟通话与加好友流程。
const bool _kSimulateVoiceMatch = bool.fromEnvironment(
  'VOICE_MATCH_SIMULATE',
  defaultValue: true,
);

/// 匿名电波匹配：Socket.IO 排队配对 + WebRTC 语音（需自建信令服务，见 `server/voice-match/`）。
enum _VoicePhase { idle, matching, inCall, summary }

class AnonymousVoiceMatchPage extends ConsumerStatefulWidget {
  const AnonymousVoiceMatchPage({super.key});

  @override
  ConsumerState<AnonymousVoiceMatchPage> createState() => _AnonymousVoiceMatchPageState();
}

class _AnonymousVoiceMatchPageState extends ConsumerState<AnonymousVoiceMatchPage>
    with SingleTickerProviderStateMixin {

  _VoicePhase _phase = _VoicePhase.idle;
  Timer? _matchCountdownTimer;
  Timer? _callTimer;
  int _matchSecondsLeft = _kMatchWaitSeconds;
  int _secondsLeftInCall = _kChatSeconds;
  int _elapsedSeconds = 0;
  final Random _rng = Random();
  List<String> _icebreakerPool = <String>[];
  String _sessionIcebreaker = _kIcebreakerFallback;
  String _remoteDisplayLabel = _kRemoteLabel;
  String _summaryPeerLabel = _kRemoteLabel;
  /// 为 `true` 时总结页可调用真实好友请求（指向演示 NPC）。
  bool _voiceSessionIsSimulated = false;

  AnonymousVoiceMatchController? _voice;

  late final AnimationController _radarRing;

  @override
  void initState() {
    super.initState();
    _radarRing = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    DailyTaskResourceLoader.loadSpeakingIcebreakerPool().then((List<String> pool) {
      if (!mounted) {
        return;
      }
      setState(() => _icebreakerPool = pool);
    });
  }

  @override
  void dispose() {
    _matchCountdownTimer?.cancel();
    _callTimer?.cancel();
    unawaited(_voice?.dispose());
    _radarRing.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _matchCountdownTimer?.cancel();
    _matchCountdownTimer = null;
    _callTimer?.cancel();
    _callTimer = null;
  }

  String _mmSs(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startMatching() async {
    _cancelTimers();
    await _voice?.dispose();
    _voice = null;
    _voiceSessionIsSimulated = false;

    setState(() {
      _phase = _VoicePhase.matching;
      _matchSecondsLeft = _kMatchWaitSeconds;
    });

    _matchCountdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      setState(() {
        if (_matchSecondsLeft > 0) {
          _matchSecondsLeft--;
        }
      });
    });

    if (_kSimulateVoiceMatch) {
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted || _phase != _VoicePhase.matching) {
          return;
        }
        _cancelTimers();
        _voiceSessionIsSimulated = true;
        _enterSimulatedCall();
      });
      return;
    }

    final AnonymousVoiceMatchController voice = AnonymousVoiceMatchController(
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onMatchedUi: _onVoiceMatchedUi,
      onMatchTimeout: _onVoiceMatchTimeout,
      onPeerEnded: _onVoicePeerEnded,
      onError: _onVoiceError,
    );
    _voice = voice;
    await voice.startMatching();
  }

  void _enterSimulatedCall() {
    _cancelTimers();
    final List<String> pool = _icebreakerPool;
    final String topic =
        pool.isEmpty ? _kIcebreakerFallback : pool[_rng.nextInt(pool.length)];
    setState(() {
      _phase = _VoicePhase.inCall;
      _sessionIcebreaker = topic;
      _remoteDisplayLabel = '电波旅人_Aria';
      _secondsLeftInCall = _kChatSeconds;
      _elapsedSeconds = 0;
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        return;
      }
      final int nextLeft = _secondsLeftInCall - 1;
      if (nextLeft <= 0) {
        t.cancel();
        _callTimer = null;
        unawaited(_hangUpDueToTimeLimit());
        return;
      }
      setState(() {
        _secondsLeftInCall = nextLeft;
        _elapsedSeconds = _kChatSeconds - nextLeft;
      });
    });
  }

  Future<void> _sendVoiceDemoFriendRequest() async {
    await ref.read(communitySocialRepositoryProvider).ensureDemoSocialScenario();
    final String? err = await ref
        .read(communitySocialRepositoryProvider)
        .sendFriendRequest(CommunityDemoIds.voicePeerUserId);
    if (!mounted) {
      return;
    }
    showAppTopSnackBar(
      context,
      Text(err ?? AppStrings.of(context).voiceMatchFriendSentOk),
    );
  }

  void _onVoiceMatchedUi() {
    if (!mounted) return;
    _cancelTimers();
    final AnonymousVoiceMatchController? v = _voice;
    final List<String> pool = _icebreakerPool;
    final String fallbackTopic = pool.isEmpty ? _kIcebreakerFallback : pool[_rng.nextInt(pool.length)];
    setState(() {
      _phase = _VoicePhase.inCall;
      _sessionIcebreaker = (v?.sessionTopic.isNotEmpty ?? false) ? v!.sessionTopic : fallbackTopic;
      _remoteDisplayLabel = (v?.peerLabel.isNotEmpty ?? false) ? v!.peerLabel : _kRemoteLabel;
      _secondsLeftInCall = _kChatSeconds;
      _elapsedSeconds = 0;
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) return;
      final int nextLeft = _secondsLeftInCall - 1;
      if (nextLeft <= 0) {
        t.cancel();
        _callTimer = null;
        unawaited(_hangUpDueToTimeLimit());
        return;
      }
      setState(() {
        _secondsLeftInCall = nextLeft;
        _elapsedSeconds = _kChatSeconds - nextLeft;
      });
    });
  }

  void _onVoiceMatchTimeout() {
    if (!mounted) return;
    _cancelTimers();
    _voice?.cancelMatching();
    _voice = null;
    context.pop();
  }

  void _onVoiceError(String message) {
    if (!mounted) return;
    showAppTopSnackBar(context, Text(message));
    if (_phase == _VoicePhase.matching) {
      _cancelTimers();
      unawaited(_voice?.resetForNewAttempt());
      _voice = null;
      setState(() => _phase = _VoicePhase.idle);
    }
  }

  void _onVoicePeerEnded() {
    if (!mounted) return;
    if (_phase != _VoicePhase.inCall) return;
    _cancelTimers();
    final String remote = _remoteDisplayLabel;
    final int elapsed = (_kChatSeconds - _secondsLeftInCall).clamp(0, _kChatSeconds);
    unawaited(_voice?.resetForNewAttempt());
    _voice = null;
    setState(() {
      _summaryPeerLabel = remote;
      _elapsedSeconds = elapsed;
      _phase = _VoicePhase.summary;
    });
  }

  void _cancelMatching() {
    _cancelTimers();
    _voice?.cancelMatching();
    _voice = null;
    setState(() => _phase = _VoicePhase.idle);
  }

  Future<void> _hangUp() async {
    if (_phase != _VoicePhase.inCall) return;
    _cancelTimers();
    final String remote = _remoteDisplayLabel;
    final int elapsed = (_kChatSeconds - _secondsLeftInCall).clamp(0, _kChatSeconds);
    await _voice?.hangUp();
    _voice = null;
    if (!mounted) return;
    setState(() {
      _summaryPeerLabel = remote;
      _elapsedSeconds = elapsed;
      _phase = _VoicePhase.summary;
    });
  }

  Future<void> _hangUpDueToTimeLimit() async {
    if (!mounted) return;
    if (_phase != _VoicePhase.inCall) return;
    await _hangUp();
  }

  void _resetIdle() {
    _cancelTimers();
    _voiceSessionIsSimulated = false;
    setState(() {
      _phase = _VoicePhase.idle;
      _secondsLeftInCall = _kChatSeconds;
      _elapsedSeconds = 0;
      _remoteDisplayLabel = _kRemoteLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings s = AppStrings.of(context);
    final bool urgent = _phase == _VoicePhase.inCall && _secondsLeftInCall <= 10;
    final RTCVideoRenderer? remoteAudioRenderer = _voice?.remoteRenderer;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: HtmlDesignTokens.backgroundGradient)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.65),
                  radius: 1.15,
                  colors: <Color>[
                    switch (_phase) {
                      _VoicePhase.matching => const Color(0x4D7C3AED),
                      _VoicePhase.inCall => const Color(0x382DD4BF),
                      _VoicePhase.summary => const Color(0x337C3AED),
                      _ => const Color(0x262DD4BF),
                    },
                    Colors.transparent,
                  ],
                  stops: const <double>[0.0, 0.72],
                ),
              ),
            ),
          ),
          if (remoteAudioRenderer != null)
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 1,
                height: 1,
                child: RTCVideoView(remoteAudioRenderer, mirror: false),
              ),
            ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () async {
                  if (_phase == _VoicePhase.matching) {
                    _cancelMatching();
                    if (context.mounted) context.pop();
                    return;
                  }
                  if (_phase == _VoicePhase.inCall) {
                    _cancelTimers();
                    await _voice?.hangUp();
                    _voice = null;
                    if (context.mounted) context.pop();
                    return;
                  }
                  if (context.mounted) context.pop();
                },
              ),
              title: Text(s.voiceMatchAppBarTitle),
            ),
            body: Column(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: HtmlDesignTokens.stackedPageAppBarPadding.copyWith(bottom: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: switch (_phase) {
                        _VoicePhase.idle => _IdlePane(
                            key: const ValueKey<String>('idle'),
                            strings: s,
                          ),
                        _VoicePhase.matching => _MatchingPane(
                            key: const ValueKey<String>('match'),
                            ring: _radarRing,
                            secondsLeft: _matchSecondsLeft,
                            strings: s,
                          ),
                        _VoicePhase.inCall => _CallPane(
                            key: const ValueKey<String>('call'),
                            timerText: _mmSs(_secondsLeftInCall.clamp(0, _kChatSeconds)),
                            urgent: urgent,
                            icebreakerTopic: _sessionIcebreaker,
                            remoteLabel: _remoteDisplayLabel,
                            strings: s,
                          ),
                        _VoicePhase.summary => _SummaryPane(
                            key: const ValueKey<String>('sum'),
                            elapsedText: _mmSs(_elapsedSeconds),
                            peerLabel: _summaryPeerLabel,
                            strings: s,
                            onAddFriendPressed: _voiceSessionIsSimulated
                                ? () => unawaited(_sendVoiceDemoFriendRequest())
                                : () => showAppTopSnackBar(
                                    context,
                                    Text(s.voiceMatchFriendSentToast),
                                  ),
                          ),
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: HtmlDesignTokens.stackedPageAppBarPadding.copyWith(bottom: 22),
                  child: _buildBottomActions(context, s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, AppStrings s) {
    return switch (_phase) {
      _VoicePhase.idle => _GradientPillButton(
          label: s.voiceMatchEmitSignal,
          onPressed: () => unawaited(_startMatching()),
        ),
      _VoicePhase.matching => _GlassPillButton(
          label: s.voiceMatchCancelSignal,
          onPressed: _cancelMatching,
        ),
      _VoicePhase.inCall => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _RoundControl(
              icon: (_voice?.micEnabled ?? true) ? Icons.mic_rounded : Icons.mic_off_rounded,
              // 开麦为默认玻璃样式；闭麦后为红色
              filled: !(_voice?.micEnabled ?? true),
              onPressed: () {
                _voice?.toggleMic();
                setState(() {});
              },
            ),
            const SizedBox(width: 24),
            _RoundControl(
              icon: Icons.call_end_rounded,
              filled: true,
              color: const Color(0xFFEF4444),
              onPressed: () {
                unawaited(_hangUp());
              },
            ),
            const SizedBox(width: 24),
            _RoundControl(
              icon: (_voice?.remoteAudioEnabled ?? true) ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              // 对方语音打开为默认玻璃样式；静音后为红色
              filled: !(_voice?.remoteAudioEnabled ?? true),
              onPressed: () {
                _voice?.toggleRemoteAudio();
                setState(() {});
              },
            ),
          ],
        ),
      _VoicePhase.summary => _GlassPillButton(
          label: s.voiceMatchBackLobby,
          onPressed: _resetIdle,
        ),
    };
  }
}

class _IdlePane extends StatelessWidget {
  const _IdlePane({super.key, required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const Text('📻', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(
            strings.voiceMatchIdleHeadline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: HtmlDesignTokens.textMain,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.voiceMatchIdleBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: HtmlDesignTokens.textSub,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 28),
          _FeatureTile(
            emoji: '🎭',
            title: strings.voiceMatchFeature1Title,
            subtitle: strings.voiceMatchFeature1Sub,
            iconTint: HtmlDesignTokens.primary.withValues(alpha: 0.15),
            iconAccent: HtmlDesignTokens.primaryLight,
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            emoji: '📝',
            title: strings.voiceMatchFeature2Title,
            subtitle: strings.voiceMatchFeature2Sub,
            iconTint: HtmlDesignTokens.accent.withValues(alpha: 0.15),
            iconAccent: HtmlDesignTokens.accent,
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.iconTint,
    required this.iconAccent,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color iconTint;
  final Color iconAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.glassCard,
        borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusMd),
        border: Border.all(color: HtmlDesignTokens.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(emoji, style: TextStyle(fontSize: 18, color: iconAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: HtmlDesignTokens.textMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    fontFamily: 'system-ui',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: HtmlDesignTokens.textSub,
                    fontSize: 12,
                    fontFamily: 'system-ui',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchingPane extends StatelessWidget {
  const _MatchingPane({
    super.key,
    required this.ring,
    required this.secondsLeft,
    required this.strings,
  });

  final AnimationController ring;
  final int secondsLeft;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 40),
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              RotationTransition(
                turns: ring,
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _DashedRingPainter(color: HtmlDesignTokens.accent.withValues(alpha: 0.4)),
                ),
              ),
              ...List<Widget>.generate(3, (int i) {
                return _RadarWave(delay: Duration(milliseconds: 800 * i));
              }),
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HtmlDesignTokens.accent,
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.55), blurRadius: 24),
                  ],
                ),
                child: const Text('🎧', style: TextStyle(fontSize: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Text(
          strings.voiceMatchSearchingHeadline,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: HtmlDesignTokens.accent,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.voiceMatchSearchingSub,
          style: TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
        ),
        const SizedBox(height: 6),
        Text(
          strings.voiceMatchSecondsLeft(secondsLeft.clamp(0, _kMatchWaitSeconds)),
          style: TextStyle(fontSize: 11, color: HtmlDesignTokens.textSub.withValues(alpha: 0.85), fontFamily: 'system-ui'),
        ),
      ],
    );
  }
}

class _RadarWave extends StatefulWidget {
  const _RadarWave({required this.delay});

  final Duration delay;

  @override
  State<_RadarWave> createState() => _RadarWaveState();
}

class _RadarWaveState extends State<_RadarWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final scale = 1 + t * 3;
        final opacity = (0.85 * (1 - t)).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: HtmlDesignTokens.accent, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final PathMetric metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double next = (d + 8).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), p);
        d += 16;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) => oldDelegate.color != color;
}

class _CallPane extends StatelessWidget {
  const _CallPane({
    super.key,
    required this.timerText,
    required this.urgent,
    required this.icebreakerTopic,
    required this.remoteLabel,
    required this.strings,
  });

  final String timerText;
  final bool urgent;
  final String icebreakerTopic;
  final String remoteLabel;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          strings.voiceMatchSignalConnected,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
        ),
        const SizedBox(height: 8),
        Text(
          timerText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w300,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            color: urgent ? const Color(0xFFEF4444) : HtmlDesignTokens.textMain,
            shadows: <Shadow>[
              Shadow(
                color: (urgent ? const Color(0xFFEF4444) : Colors.white).withValues(alpha: 0.35),
                blurRadius: 20,
              ),
            ],
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusLg),
            gradient: LinearGradient(
              begin: const Alignment(-1, -1),
              end: const Alignment(1, 1),
              colors: <Color>[
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.voiceMatchPart2TopicLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: HtmlDesignTokens.accent,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                icebreakerTopic,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: HtmlDesignTokens.textMain,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _CallAvatar(
              emoji: '👾',
              label: strings.voiceMatchYouLabel,
              labelColor: HtmlDesignTokens.accent,
              gradient: const LinearGradient(
                colors: <Color>[HtmlDesignTokens.primary, HtmlDesignTokens.accent],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(5, (int i) {
                final double h = <double>[0.2, 0.6, 1.0, 0.4, 0.8][i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _AudioBar(heightFactor: h),
                );
              }),
            ),
            _CallAvatar(
              emoji: '🦊',
              label: remoteLabel,
              labelColor: HtmlDesignTokens.textSub,
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFF61D2), Color(0xFFFE9090)],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CallAvatar extends StatelessWidget {
  const _CallAvatar({
    required this.emoji,
    required this.label,
    required this.labelColor,
    required this.gradient,
  });

  final String emoji;
  final String label;
  final Color labelColor;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: gradient,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HtmlDesignTokens.accent.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: labelColor, fontFamily: 'system-ui'),
        ),
      ],
    );
  }
}

class _AudioBar extends StatefulWidget {
  const _AudioBar({required this.heightFactor});

  final double heightFactor;

  @override
  State<_AudioBar> createState() => _AudioBarState();
}

class _AudioBarState extends State<_AudioBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final t = Curves.easeInOut.transform(_c.value);
        final h = 40 * (0.3 + widget.heightFactor * 0.7 * t);
        return Container(
          width: 4,
          height: h,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 4,
            height: h,
            decoration: BoxDecoration(
              color: HtmlDesignTokens.accent,
              borderRadius: BorderRadius.circular(4),
              boxShadow: <BoxShadow>[
                BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.45), blurRadius: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    super.key,
    required this.elapsedText,
    required this.peerLabel,
    required this.strings,
    required this.onAddFriendPressed,
  });

  final String elapsedText;
  final String peerLabel;
  final AppStrings strings;
  final VoidCallback onAddFriendPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: 8),
        const Text('✨', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 8),
        Text(
          strings.voiceMatchSummaryTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: HtmlDesignTokens.textMain,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.gachaSubBg,
            borderRadius: BorderRadius.circular(HtmlDesignTokens.radiusXl),
            border: Border.all(color: HtmlDesignTokens.glassBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 48,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFF61D2), Color(0xFFFE9090)],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: const Color(0xFFFF61D2).withValues(alpha: 0.35), blurRadius: 18),
                  ],
                ),
                child: const Text('🦊', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 14),
              Text(
                peerLabel,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: HtmlDesignTokens.textMain,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                strings.voiceMatchElapsedLabel(elapsedText),
                style: const TextStyle(fontSize: 13, color: HtmlDesignTokens.textSub, fontFamily: 'system-ui'),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: Material(
                  borderRadius: BorderRadius.circular(100),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddFriendPressed,
                    borderRadius: BorderRadius.circular(100),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        gradient: const LinearGradient(
                          colors: <Color>[HtmlDesignTokens.primary, Color(0xFF9333EA)],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: HtmlDesignTokens.primary.withValues(alpha: 0.45),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            strings.voiceMatchAddFriend,
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientPillButton extends StatelessWidget {
  const _GradientPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(
                colors: <Color>[HtmlDesignTokens.accent, Color(0xFF0EA5E9)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(color: HtmlDesignTokens.accent.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.5,
                    color: Color(0xFF0D071C),
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

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: HtmlDesignTokens.glassCard,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: HtmlDesignTokens.glassBorder),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: HtmlDesignTokens.textMain,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.filled,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? (color ?? const Color(0xFFEF4444)) : HtmlDesignTokens.glassCard;
    return Material(
      color: bg,
      shape: CircleBorder(
        side: filled ? BorderSide.none : BorderSide(color: HtmlDesignTokens.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
