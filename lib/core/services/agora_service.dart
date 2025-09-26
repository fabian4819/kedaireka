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
  bool _cameraOff = false;

  RtcEngine? get engine => _engine;
  bool get localUserJoined => _localUserJoined;
  int? get remoteUid => _remoteUid;
  bool get muted => _muted;
  bool get cameraOff => _cameraOff;

  // Callbacks
  Function(int uid, int elapsed)? onUserJoined;
  Function(int uid, UserOfflineReasonType reason)? onUserOffline;
  Function(RtcConnection connection, int uid)? onJoinChannelSuccess;
  Function(RtcConnection connection, RtcStats stats)? onLeaveChannel;

  Future<void> initialize() async {
    try {
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

      // Enable video
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } catch (e) {
      log('Error initializing Agora: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  Future<void> joinChannel({String? token, String? channelName, int? uid}) async {
    if (_engine == null) {
      throw Exception('Agora engine not initialized');
    }

    try {
      ChannelMediaOptions options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      );

      await _engine!.joinChannel(
        token: token ?? AgoraConfig.tempToken,
        channelId: channelName ?? AgoraConfig.channelName,
        uid: uid ?? 0,
        options: options,
      );
    } catch (e) {
      log('Error joining channel: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel() async {
    if (_engine == null) return;

    try {
      await _engine!.leaveChannel();
      _localUserJoined = false;
      _remoteUid = null;
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
      _cameraOff = !_cameraOff;
      await _engine!.muteLocalVideoStream(_cameraOff);
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

  Future<void> dispose() async {
    try {
      await leaveChannel();
      await _engine?.release();
      _engine = null;
      _instance = null;
    } catch (e) {
      log('Error disposing Agora service: $e');
    }
  }
}