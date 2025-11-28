import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../core/services/agora_service.dart';
import '../../core/providers/call_state_provider.dart';
import '../../core/theme/app_theme.dart';

class VideocallScreen extends StatefulWidget {
  const VideocallScreen({super.key});

  @override
  State<VideocallScreen> createState() => _VideocallScreenState();
}

class _VideocallScreenState extends State<VideocallScreen> {
  final AgoraService _agoraService = AgoraService.instance;
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _channelController = TextEditingController();

  bool _isCallStarted = false;
  bool _isLoading = false;
  String _statusMessage = 'Ready to connect';
  String _generatedToken = '';
  bool _isCreatingRoom = false;

  @override
  void initState() {
    super.initState();
    _setupAgoraCallbacks();
    _checkExistingSession();
  }

  void _checkExistingSession() {
    if (_agoraService.localUserJoined) {
      setState(() {
        _isCallStarted = true;
        _statusMessage = _agoraService.isScreenSharing
            ? 'Screen sharing active'
            : 'Session active';
      });
      // Update provider to hide floating widget when on this screen
      Provider.of<CallStateProvider>(context, listen: false).updateCallState();
    }
  }

  void _setupAgoraCallbacks() {
    _agoraService.onJoinChannelSuccess = (connection, elapsed) {
      setState(() {
        _statusMessage = 'Connected to channel';
        _isLoading = false;
      });
      Provider.of<CallStateProvider>(context, listen: false).updateCallState();
    };

    _agoraService.onUserJoined = (uid, elapsed) {
      setState(() {
        _statusMessage = 'User joined: $uid';
      });
      Provider.of<CallStateProvider>(context, listen: false).updateCallState();
    };

    _agoraService.onUserOffline = (uid, reason) {
      setState(() {
        _statusMessage = 'User left: $uid';
      });
      Provider.of<CallStateProvider>(context, listen: false).updateCallState();
    };

    _agoraService.onLeaveChannel = (connection, stats) {
      setState(() {
        _statusMessage = 'Left channel';
        _isCallStarted = false;
      });
      Provider.of<CallStateProvider>(context, listen: false).hideFloatingWidget();
    };
  }

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating room...';
      _isCreatingRoom = true;
    });

    try {
      await _agoraService.initialize();

      // Generate a simple channel name (in production, use a proper token server)
      final channelName = 'room_${DateTime.now().millisecondsSinceEpoch}';

      await _agoraService.joinChannel(
        channelName: channelName,
        enableVideo: true,
      );

      setState(() {
        _isCallStarted = true;
        _generatedToken = channelName; // In production, this would be the actual token
        _statusMessage = 'Room created! Share the code with others.';
      });

      Provider.of<CallStateProvider>(context, listen: false).setShowFloatingWidget(true);
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to create room: $e';
        _isLoading = false;
      });
      _showErrorDialog('Failed to create room: $e');
    }
  }

  Future<void> _joinRoom() async {
    final token = _tokenController.text.trim();
    final channel = _channelController.text.trim();

    if (channel.isEmpty) {
      _showErrorDialog('Please enter a room code');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Joining room...';
      _isCreatingRoom = false;
    });

    try {
      await _agoraService.initialize();
      await _agoraService.joinChannel(
        channelName: channel,
        token: token.isEmpty ? null : token,
        enableVideo: true,
      );

      setState(() {
        _isCallStarted = true;
      });

      Provider.of<CallStateProvider>(context, listen: false).setShowFloatingWidget(true);
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to join room: $e';
        _isLoading = false;
      });
      _showErrorDialog('Failed to join room: $e');
    }
  }

  Future<void> _endCall() async {
    setState(() {
      _statusMessage = 'Ending session...';
    });

    try {
      await _agoraService.endCallCompletely();

      setState(() {
        _isCallStarted = false;
        _statusMessage = 'Session ended';
        _generatedToken = '';
        _tokenController.clear();
        _channelController.clear();
      });

      Provider.of<CallStateProvider>(context, listen: false).hideFloatingWidget();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error ending session: $e';
        _isCallStarted = false;
      });
    }
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room code copied to clipboard!'),
        duration: Duration(seconds: 2),
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
            AppTheme.primaryColor.withValues(alpha: 0.1),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_call,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Pix2Land Video Call',
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

              // Create Room Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createRoom,
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
                            Icon(Icons.add_circle_outline),
                            SizedBox(width: 12),
                            Text(
                              'Create Room',
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
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Join Room Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Join Existing Room',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _channelController,
                      decoration: InputDecoration(
                        labelText: 'Room Code *',
                        hintText: 'Enter room code',
                        prefixIcon: const Icon(Icons.meeting_room),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Token (Optional)',
                        hintText: 'Enter token if required',
                        prefixIcon: const Icon(Icons.key),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _joinRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Join Room',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _agoraService.localUserJoined ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isCreatingRoom && _generatedToken.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Room Code:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _generatedToken,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          onPressed: () => _copyToClipboard(_generatedToken),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Video views
          Expanded(
            child: Stack(
              children: [
                // Remote video (full screen)
                if (_agoraService.remoteUid != null)
                  AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _agoraService.engine!,
                      canvas: VideoCanvas(uid: _agoraService.remoteUid),
                      connection: RtcConnection(
                        channelId: _agoraService.currentChannelName,
                      ),
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _agoraService.isScreenSharing
                              ? Icons.screen_share
                              : Icons.person,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _agoraService.isScreenSharing
                              ? 'Screen sharing active\nWaiting for others to join...'
                              : 'Waiting for others to join...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Local video (small preview)
                if (_agoraService.cameraEnabled)
                  Positioned(
                    top: 20,
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
                          controller: VideoViewController(
                            rtcEngine: _agoraService.engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control buttons at bottom
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Toggle microphone
                _buildControlButton(
                  icon: _agoraService.muted ? Icons.mic_off : Icons.mic,
                  color: _agoraService.muted ? Colors.red : Colors.white,
                  backgroundColor: _agoraService.muted
                      ? Colors.red
                      : AppTheme.primaryColor,
                  onPressed: () async {
                    await _agoraService.toggleMute();
                    setState(() {});
                  },
                ),

                // Toggle camera
                _buildControlButton(
                  icon: _agoraService.cameraEnabled ? Icons.videocam : Icons.videocam_off,
                  color: _agoraService.cameraEnabled ? Colors.white : Colors.red,
                  backgroundColor: _agoraService.cameraEnabled
                      ? AppTheme.primaryColor
                      : Colors.red,
                  onPressed: () async {
                    await _agoraService.toggleCamera();
                    setState(() {});
                  },
                ),

                // Switch camera
                _buildControlButton(
                  icon: Icons.flip_camera_android,
                  color: Colors.white,
                  backgroundColor: AppTheme.primaryColor,
                  onPressed: () async {
                    await _agoraService.switchCamera();
                  },
                ),

                // Screen share toggle
                _buildControlButton(
                  icon: _agoraService.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  color: Colors.white,
                  backgroundColor: _agoraService.isScreenSharing ? Colors.orange : AppTheme.primaryColor,
                  onPressed: () async {
                    if (_agoraService.isScreenSharing) {
                      await _agoraService.stopScreenSharing();
                    } else {
                      try {
                        await _agoraService.startScreenSharing();
                      } catch (e) {
                        _showErrorDialog('Failed to start screen sharing: $e');
                      }
                    }
                    setState(() {});
                  },
                ),

                // End call
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.white,
                  backgroundColor: Colors.red,
                  onPressed: _endCall,
                ),
              ],
            ),
          ),
        ],
      ),
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
          color: backgroundColor ?? AppTheme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
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
    _tokenController.dispose();
    _channelController.dispose();
    super.dispose();
  }
}
