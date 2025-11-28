import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/agora_config.dart';

class AgoraService {
  static AgoraService? _instance;
  static AgoraService get instance => _instance ??= AgoraService._internal();

  AgoraService._internal();

  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _muted = false;
  bool _isScreenSharing = false;
  bool _videoEnabled = false;
  bool _cameraEnabled = false;
  String? _currentChannelName;
  String? _currentToken;

  RtcEngine? get engine => _engine;
  bool get localUserJoined => _localUserJoined;
  int? get remoteUid => _remoteUid;
  bool get muted => _muted;
  bool get isScreenSharing => _isScreenSharing;
  bool get isCallActive => _localUserJoined;
  bool get videoEnabled => _videoEnabled;
  bool get cameraEnabled => _cameraEnabled;
  String? get currentChannelName => _currentChannelName;
  String? get currentToken => _currentToken;

  // Callbacks
  Function(int uid, int elapsed)? onUserJoined;
  Function(int uid, UserOfflineReasonType reason)? onUserOffline;
  Function(RtcConnection connection, int uid)? onJoinChannelSuccess;
  Function(RtcConnection connection, RtcStats stats)? onLeaveChannel;
  Function()? onRemoteVideoStateChanged;

  Future<void> initialize() async {
    try {
      // Validate Agora App ID
      if (AgoraConfig.appId == 'YOUR_AGORA_APP_ID' || AgoraConfig.appId.isEmpty) {
        throw Exception(
          'Agora App ID not configured. Please set your Agora App ID in lib/core/config/agora_config.dart\n'
          'Get your App ID from https://console.agora.io/'
        );
      }

      // Request permissions
      await _requestPermissions();

      // Create RTC engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Register event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            log('Local user ${connection.localUid} joined channel');
            _localUserJoined = true;
            onJoinChannelSuccess?.call(connection, elapsed);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            log('Remote user $remoteUid joined channel');
            _remoteUid = remoteUid;
            onUserJoined?.call(remoteUid, elapsed);
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            log('Remote user $remoteUid left channel');
            _remoteUid = null;
            onUserOffline?.call(remoteUid, reason);
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            log('Local user left channel');
            _localUserJoined = false;
            _remoteUid = null;
            onLeaveChannel?.call(connection, stats);
          },
        ),
      );

      // Enable audio and video
      await _engine!.enableAudio();
      await _engine!.enableVideo();
    } catch (e) {
      log('Error initializing Agora: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  Future<void> joinChannel({String? token, String? channelName, int? uid, bool enableVideo = true}) async {
    if (_engine == null) {
      throw Exception('Agora engine not initialized');
    }

    try {
      _currentChannelName = channelName ?? AgoraConfig.channelName;
      _currentToken = token ?? AgoraConfig.tempToken;

      ChannelMediaOptions options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: enableVideo,
        publishMicrophoneTrack: true,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      );

      await _engine!.joinChannel(
        token: _currentToken!,
        channelId: _currentChannelName!,
        uid: uid ?? 0,
        options: options,
      );

      _videoEnabled = enableVideo;
      _cameraEnabled = enableVideo;
    } catch (e) {
      log('Error joining channel: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;

    try {
      // Stop screen sharing if active
      if (_isScreenSharing) {
        await stopScreenSharing();
      }

      // Disable audio and video
      await _engine!.disableAudio();
      await _engine!.disableVideo();

      // Leave the channel
      await _engine!.leaveChannel();

      // Reset all state
      _localUserJoined = false;
      _remoteUid = null;
      _muted = false;
      _isScreenSharing = false;
      _videoEnabled = false;
      _cameraEnabled = false;
      _currentChannelName = null;
      _currentToken = null;

      log('Successfully left channel and cleaned up');
    } catch (e) {
      log('Error leaving channel: $e');
    }
  }

  Future<void> toggleMute() async {
    if (_engine == null) return;

    try {
      _muted = !_muted;
      await _engine!.muteLocalAudioStream(_muted);
    } catch (e) {
      log('Error toggling mute: $e');
    }
  }

  Future<void> toggleCamera() async {
    if (_engine == null) return;

    try {
      _cameraEnabled = !_cameraEnabled;
      await _engine!.muteLocalVideoStream(!_cameraEnabled);
    } catch (e) {
      log('Error toggling camera: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;

    try {
      await _engine!.switchCamera();
    } catch (e) {
      log('Error switching camera: $e');
    }
  }

  Future<void> startScreenSharing() async {
    if (_engine == null) return;

    try {
      // For Android, we need to start screen capture
      await _engine!.startScreenCapture(
        const ScreenCaptureParameters2(
          captureAudio: true,
          captureVideo: true,
          videoParams: ScreenVideoParameters(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 15,
            bitrate: 1000,
          ),
          audioParams: ScreenAudioParameters(
            sampleRate: 48000,
            channels: 2,
            captureSignalVolume: 100,
          ),
        ),
      );

      _isScreenSharing = true;
      log('Screen sharing started');
    } catch (e) {
      log('Error starting screen sharing: $e');
      rethrow;
    }
  }

  Future<void> stopScreenSharing() async {
    if (_engine == null) return;

    try {
      await _engine!.stopScreenCapture();
      _isScreenSharing = false;
      log('Screen sharing stopped');
    } catch (e) {
      log('Error stopping screen sharing: $e');
    }
  }

  Future<void> dispose() async {
    try {
      // Ensure we leave channel first
      await leaveChannel();

      // Event handlers will be cleaned up when the engine is released

      // Release the engine
      await _engine?.release();

      // Clear all references
      _engine = null;
      _localUserJoined = false;
      _remoteUid = null;
      _muted = false;
      _isScreenSharing = false;

      // Clear callbacks
      onUserJoined = null;
      onUserOffline = null;
      onJoinChannelSuccess = null;
      onLeaveChannel = null;

      log('Agora service completely disposed');
    } catch (e) {
      log('Error disposing Agora service: $e');
    }
  }

  Future<void> endCallCompletely() async {
    try {
      log('Ending call completely...');

      // Stop screen sharing if active
      if (_isScreenSharing) {
        await stopScreenSharing();
      }

      // Disable all streams
      await _engine?.disableAudio();
      await _engine?.disableVideo();
      await _engine?.muteLocalAudioStream(true);
      await _engine?.muteLocalVideoStream(true);

      // Leave channel and cleanup
      await leaveChannel();

      // Release the engine but keep singleton intact
      await _engine?.release();
      _engine = null;

      // Clear callbacks
      onUserJoined = null;
      onUserOffline = null;
      onJoinChannelSuccess = null;
      onLeaveChannel = null;
      onRemoteVideoStateChanged = null;

      log('Call ended completely');
    } catch (e) {
      log('Error ending call completely: $e');
    }
  }
}