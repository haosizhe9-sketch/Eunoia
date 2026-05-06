import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/config/voice_match_config.dart';

/// 匹配与 WebRTC 语音：连接 Socket.IO 信令服务，完成 offer/answer 与 ICE。
class AnonymousVoiceMatchController {
  AnonymousVoiceMatchController({
    required this.onStateChanged,
    this.onMatchedUi,
    this.onMatchTimeout,
    this.onPeerEnded,
    this.onError,
  });

  final VoidCallback onStateChanged;
  /// 已从服务端配对成功（话题与昵称已就绪），应切换 UI 至通话中并开始通话倒计时。
  final VoidCallback? onMatchedUi;
  final VoidCallback? onMatchTimeout;
  final VoidCallback? onPeerEnded;
  final void Function(String message)? onError;

  io.Socket? _socket;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _remoteRenderer;

  Completer<void>? _mediaReady;
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];

  String peerLabel = '';
  String sessionTopic = '';
  bool micEnabled = true;
  bool remoteAudioEnabled = true;

  bool _signalingAttached = false;
  bool _matchedHandled = false;

  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;

  bool get isSocketBusy => _socket != null && _socket!.connected;

  Future<void> startMatching() async {
    await resetForNewAttempt();
    final String url = VoiceMatchConfig.resolveSignalUrl();
    if (url.isEmpty) {
      onError?.call('信令地址无效');
      return;
    }

    try {
      // Polling 优先：部分反代/防火墙对 WS 升级不友好，长轮询仍可连上。
      _socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(<String>['polling', 'websocket'])
            .enableForceNew()
            .setTimeout(45000)
            .build(),
      );
    } catch (e) {
      onError?.call('无法创建连接：$e');
      return;
    }

    _attachSocketHandlers();
    _socket!.connect();
    onStateChanged();
  }

  void _attachSocketHandlers() {
    if (_signalingAttached || _socket == null) return;
    _signalingAttached = true;

    _socket!.onConnect((_) {
      _socket!.emit('join_match');
    });

    _socket!.onConnectError((dynamic err) {
      onError?.call('信令连接失败：$err');
    });

    _socket!.on('match_timeout', (_) {
      onMatchTimeout?.call();
    });

    _socket!.on('matched', (dynamic raw) {
      unawaited(_onMatchedEvent(raw));
    });

    _socket!.on('webrtc_signal', (dynamic raw) {
      unawaited(_onWebrtcSignal(raw));
    });

    _socket!.on('peer_hang_up', (_) {
      unawaited(_onPeerLeft());
    });

    _socket!.on('peer_disconnected', (_) {
      unawaited(_onPeerLeft());
    });
  }

  Future<void> _onMatchedEvent(dynamic raw) async {
    if (_matchedHandled) return;
    _matchedHandled = true;
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw as Map);
      sessionTopic = data['topic'] as String? ?? '';
      peerLabel = data['peerLabel'] as String? ?? '匿名';
      final bool isCaller = data['isCaller'] as bool? ?? false;

      _mediaReady = Completer<void>();
      final Completer<void> ready = _mediaReady!;

      _remoteRenderer = RTCVideoRenderer();
      await _remoteRenderer!.initialize();

      _pc = await createPeerConnection(<String, dynamic>{
        'iceServers': <Map<String, dynamic>>[
          <String, dynamic>{
            'urls': <String>['stun:stun.l.google.com:19302'],
          },
        ],
      }, <String, dynamic>{});

      _pc!.onIceCandidate = (RTCIceCandidate? c) {
        if (c == null) return;
        _socket?.emit('webrtc_signal', <String, dynamic>{
          'type': 'candidate',
          'candidate': c.toMap(),
        });
      };

      _pc!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isEmpty) return;
        _remoteStream = event.streams[0];
        _remoteRenderer?.srcObject = _remoteStream;
        _applyRemoteMute();
        onStateChanged();
      };

      _localStream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': false,
      });

      for (final MediaStreamTrack t in _localStream!.getTracks()) {
        await _pc!.addTrack(t, _localStream!);
      }

      if (!ready.isCompleted) {
        ready.complete();
      }

      onMatchedUi?.call();
      onStateChanged();

      if (isCaller) {
        final RTCSessionDescription offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        _socket?.emit('webrtc_signal', <String, dynamic>{
          'type': offer.type,
          'sdp': offer.sdp,
        });
      }
    } catch (e, st) {
      if (_mediaReady != null && !_mediaReady!.isCompleted) {
        try {
          _mediaReady!.completeError(e, st);
        } catch (_) {}
      }
      _socket?.emit('hang_up');
      await _disposePeerOnly();
      _disconnectSocket();
      _resetMatchFlags();
      _matchedHandled = false;
      final String errStr = e.toString();
      final bool likelyMic =
          kIsWeb &&
          (errStr.contains('NotAllowed') ||
              errStr.contains('Permission') ||
              errStr.contains('permission') ||
              errStr.contains('NotFoundError'));
      onError?.call(
        likelyMic
            ? '麦克风未授权：请在浏览器允许本站使用麦克风，并确保通过 HTTPS 打开站点'
            : '通话初始化失败：$e',
      );
    }
  }

  Future<void> _onWebrtcSignal(dynamic raw) async {
    try {
      if (_mediaReady == null) return;
      await _mediaReady!.future;

      final Map<String, dynamic> m = Map<String, dynamic>.from(raw as Map);
      final String? t = m['type'] as String?;
      if (t == null || _pc == null) return;

      if (t == 'offer') {
        final String? sdp = m['sdp'] as String?;
        if (sdp == null) return;
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        await _drainPendingRemoteCandidates();
        final RTCSessionDescription answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _socket?.emit('webrtc_signal', <String, dynamic>{
          'type': answer.type,
          'sdp': answer.sdp,
        });
      } else if (t == 'answer') {
        final String? sdp = m['sdp'] as String?;
        if (sdp == null) return;
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        await _drainPendingRemoteCandidates();
      } else if (t == 'candidate') {
        final dynamic rawC = m['candidate'];
        if (rawC is! Map) return;
        final Map<String, dynamic> cMap = Map<String, dynamic>.from(rawC);
        final RTCIceCandidate cand = RTCIceCandidate(
          cMap['candidate'] as String?,
          cMap['sdpMid'] as String?,
          cMap['sdpMLineIndex'] as int?,
        );
        if (await _pc!.getRemoteDescription() != null) {
          await _pc!.addCandidate(cand);
        } else {
          _pendingRemoteCandidates.add(cand);
        }
      }
    } catch (e) {
      onError?.call('信令处理失败：$e');
    }
  }

  Future<void> _drainPendingRemoteCandidates() async {
    if (_pc == null) return;
    final List<RTCIceCandidate> copy = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final RTCIceCandidate c in copy) {
      await _pc!.addCandidate(c);
    }
  }

  Future<void> _onPeerLeft() async {
    await _disposePeerOnly();
    onPeerEnded?.call();
  }

  void cancelMatching() {
    _socket?.emit('cancel_match');
    _disconnectSocket();
    _resetMatchFlags();
  }

  Future<void> hangUp() async {
    _socket?.emit('hang_up');
    await _disposePeerOnly();
    _disconnectSocket();
    _resetMatchFlags();
  }

  Future<void> resetForNewAttempt() async {
    await _disposePeerOnly();
    _disconnectSocket();
    _resetMatchFlags();
  }

  void _resetMatchFlags() {
    _signalingAttached = false;
    _matchedHandled = false;
    _mediaReady = null;
    peerLabel = '';
    sessionTopic = '';
  }

  void _disconnectSocket() {
    _socket?.dispose();
    _socket = null;
    _signalingAttached = false;
  }

  Future<void> _disposePeerOnly() async {
    try {
      for (final MediaStreamTrack t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _localStream?.dispose();
      _localStream = null;

      await _remoteRenderer?.dispose();
      _remoteRenderer = null;
      _remoteStream = null;

      await _pc?.close();
      _pc = null;
      _pendingRemoteCandidates.clear();
    } catch (_) {
      // ignore
    }
  }

  void toggleMic() {
    micEnabled = !micEnabled;
    final MediaStream? s = _localStream;
    if (s != null) {
      for (final MediaStreamTrack t in s.getAudioTracks()) {
        t.enabled = micEnabled;
      }
    }
    onStateChanged();
  }

  void toggleRemoteAudio() {
    remoteAudioEnabled = !remoteAudioEnabled;
    _applyRemoteMute();
    onStateChanged();
  }

  void _applyRemoteMute() {
    final MediaStream? s = _remoteStream;
    if (s == null) return;
    for (final MediaStreamTrack t in s.getAudioTracks()) {
      t.enabled = remoteAudioEnabled;
    }
  }

  Future<void> dispose() async {
    cancelMatching();
    await _disposePeerOnly();
  }
}
