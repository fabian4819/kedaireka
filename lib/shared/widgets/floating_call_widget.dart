import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/call_state_provider.dart';
import '../../core/theme/app_theme.dart';

class FloatingCallWidget extends StatefulWidget {
  const FloatingCallWidget({super.key});

  @override
  State<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<FloatingCallWidget> {
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Try to get the provider, return empty if not available
    final callState = context.watch<CallStateProvider>();

    // Only show if call is active
    if (!callState.showFloatingWidget) {
      return const SizedBox.shrink();
    }

    // Check current route safely
    String currentRoute = '';
    try {
      currentRoute = GoRouterState.of(context).uri.path;
    } catch (e) {
      // Route not available yet
      return const SizedBox.shrink();
    }

    if (currentRoute == '/videocall') {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(
                0,
                MediaQuery.of(context).size.width - 150,
              ),
              (_position.dy + details.delta.dy).clamp(
                MediaQuery.of(context).padding.top,
                MediaQuery.of(context).size.height - 200,
              ),
            );
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onTap: () {
          if (!callState.isMinimized) {
            // Navigate to videocall screen
            context.go('/videocall');
          }
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: callState.isMinimized ? 80 : 150,
            height: callState.isMinimized ? 80 : 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: callState.isScreenSharing ? Colors.green : AppTheme.primaryColor,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Video view or placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: callState.remoteUid != null
                      ? AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: callState.agoraService.engine!,
                            canvas: VideoCanvas(uid: callState.remoteUid),
                            connection: RtcConnection(
                              channelId: callState.agoraService.currentChannelName,
                            ),
                          ),
                        )
                      : _buildPlaceholder(callState),
                ),

                // Controls overlay
                if (!callState.isMinimized)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlIcon(
                            icon: Icons.minimize,
                            onTap: () => callState.toggleMinimize(),
                          ),
                          _buildControlIcon(
                            icon: Icons.videocam,
                            onTap: () => context.go('/videocall'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Minimized state indicator
                if (callState.isMinimized)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          callState.isScreenSharing
                              ? Icons.screen_share
                              : Icons.videocam,
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Expand button when minimized
                if (callState.isMinimized)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => callState.toggleMinimize(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(CallStateProvider callState) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              callState.isScreenSharing
                  ? Icons.screen_share
                  : Icons.person,
              color: Colors.white54,
              size: callState.isMinimized ? 30 : 50,
            ),
            if (!callState.isMinimized) ...[
              const SizedBox(height: 8),
              Text(
                callState.isScreenSharing
                    ? 'Screen Sharing'
                    : 'Waiting...',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
