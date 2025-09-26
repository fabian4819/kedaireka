import 'package:flutter/material.dart';
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
    setState(() {
      _statusMessage = 'Ending session...';
    });

    try {
      // Use the complete end call method to ensure full cleanup
      await _agoraService.endCallCompletely();

      setState(() {
        _isCallStarted = false;
        _statusMessage = 'Session ended';
      });
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
        child: Padding(
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
                child: Icon(
                  Icons.screen_share,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'KEDAIREKA Screen Share',
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
                            Icon(Icons.screen_share),
                            SizedBox(width: 12),
                            Text(
                              'Start Screen Share',
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
                  color: Colors.blue.withValues(alpha: 0.1),
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
                      'Share this channel name with others to join the same session',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.withValues(alpha: 0.8),
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
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Screen sharing indicator
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _agoraService.isScreenSharing
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _agoraService.isScreenSharing ? Colors.green : Colors.grey,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _agoraService.isScreenSharing ? Icons.screen_share : Icons.stop_screen_share,
                    size: 80,
                    color: _agoraService.isScreenSharing ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _agoraService.isScreenSharing
                      ? 'Screen Sharing Active'
                      : 'Screen Sharing Stopped',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _agoraService.isScreenSharing ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _agoraService.isScreenSharing
                      ? 'Your screen is being shared with other participants'
                      : 'Tap the screen share button to start sharing',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                // Remote user indicator
                if (_agoraService.remoteUid != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'User ${_agoraService.remoteUid} joined',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  color: _agoraService.muted ? Colors.red : AppTheme.primaryColor,
                  backgroundColor: _agoraService.muted
                      ? Colors.red.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  onPressed: () async {
                    await _agoraService.toggleMute();
                    setState(() {});
                  },
                ),

                // Screen share toggle
                _buildControlButton(
                  icon: _agoraService.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  color: _agoraService.isScreenSharing ? Colors.orange : AppTheme.primaryColor,
                  backgroundColor: _agoraService.isScreenSharing
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
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

                // End session
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
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 32,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Ensure cleanup when screen is disposed (e.g., user navigates away)
    if (_isCallStarted) {
      _agoraService.endCallCompletely().catchError((error) {
        // Log error during disposal cleanup
        debugPrint('Error during disposal cleanup: $error');
      });
    }
    super.dispose();
  }
}