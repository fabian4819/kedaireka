import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../core/services/agora_service.dart';
import '../../core/theme/app_theme.dart';

class VideocallScreen extends StatefulWidget {
  const VideocallScreen({super.key});

  @override
  State<VideocallScreen> createState() => _VideocallScreenState();
}

class _VideocallScreenState extends State<VideocallScreen> {
  final AgoraService _agoraService = AgoraService.instance;
  bool _isCallStarted = false;
  bool _isLoading = false;
  String _statusMessage = 'Ready to connect';

  @override
  void initState() {
    super.initState();
    _setupAgoraCallbacks();
  }

  void _setupAgoraCallbacks() {
    _agoraService.onJoinChannelSuccess = (connection, elapsed) {
      setState(() {
        _statusMessage = 'Connected to channel';
        _isLoading = false;
      });
    };

    _agoraService.onUserJoined = (uid, elapsed) {
      setState(() {
        _statusMessage = 'User joined: $uid';
      });
    };

    _agoraService.onUserOffline = (uid, reason) {
      setState(() {
        _statusMessage = 'User left: $uid';
      });
    };

    _agoraService.onLeaveChannel = (connection, stats) {
      setState(() {
        _statusMessage = 'Left channel';
        _isCallStarted = false;
      });
    };
  }

  Future<void> _startCall() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting...';
    });

    try {
      await _agoraService.initialize();
      await _agoraService.joinChannel();
      setState(() {
        _isCallStarted = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to connect: $e';
        _isLoading = false;
      });
      _showErrorDialog('Failed to start call: $e');
    }
  }

  Future<void> _endCall() async {
    await _agoraService.leaveChannel();
    setState(() {
      _isCallStarted = false;
      _statusMessage = 'Call ended';
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isCallStarted ? _buildCallInterface() : _buildStartInterface(),
    );
  }

  Widget _buildStartInterface() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_call,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'KEDAIREKA Video Call',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam),
                            SizedBox(width: 12),
                            Text(
                              'Start Video Call',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'Channel: testing',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share this channel name with others to join the same call',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallInterface() {
    return Stack(
      children: [
        // Local video view (full screen)
        Container(
          color: Colors.black,
          child: _agoraService.engine != null
              ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _agoraService.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),

        // Remote video view (top right corner)
        if (_agoraService.remoteUid != null)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _agoraService.engine!,
                    canvas: VideoCanvas(uid: _agoraService.remoteUid),
                    connection: const RtcConnection(channelId: 'testing'),
                  ),
                ),
              ),
            ),
          ),

        // Status indicator
        Positioned(
          top: 50,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _agoraService.localUserJoined ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Control buttons
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Toggle microphone
              _buildControlButton(
                icon: _agoraService.muted ? Icons.mic_off : Icons.mic,
                color: _agoraService.muted ? Colors.red : Colors.white,
                onPressed: () async {
                  await _agoraService.toggleMute();
                  setState(() {});
                },
              ),
              // End call
              _buildControlButton(
                icon: Icons.call_end,
                color: Colors.red,
                backgroundColor: Colors.red,
                onPressed: _endCall,
              ),
              // Toggle camera
              _buildControlButton(
                icon: _agoraService.cameraOff ? Icons.videocam_off : Icons.videocam,
                color: _agoraService.cameraOff ? Colors.red : Colors.white,
                onPressed: () async {
                  await _agoraService.toggleCamera();
                  setState(() {});
                },
              ),
              // Switch camera
              _buildControlButton(
                icon: Icons.switch_camera,
                color: Colors.white,
                onPressed: () async {
                  await _agoraService.switchCamera();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
          size: 28,
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}