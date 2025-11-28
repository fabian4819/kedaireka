import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/agora_service.dart';
import '../../core/theme/app_theme.dart';

class ScreenShareIndicator extends StatefulWidget {
  const ScreenShareIndicator({super.key});

  @override
  State<ScreenShareIndicator> createState() => _ScreenShareIndicatorState();
}

class _ScreenShareIndicatorState extends State<ScreenShareIndicator> {
  final AgoraService _agoraService = AgoraService.instance;

  @override
  void initState() {
    super.initState();
    // Set up a periodic timer to refresh the indicator
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    // Refresh every 2 seconds to update the indicator state
    Future.doWhile(() async {
      if (mounted) {
        setState(() {});
        await Future.delayed(const Duration(seconds: 2));
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show when there's an active session and user is not on videocall screen
    if (!_agoraService.localUserJoined ||
        GoRouterState.of(context).uri.path == '/videocall') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _agoraService.isScreenSharing
                ? Colors.green
                : AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            onTap: () {
              // Navigate back to videocall screen
              context.go('/videocall');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _agoraService.isScreenSharing
                      ? Icons.screen_share
                      : Icons.mic,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _agoraService.isScreenSharing
                      ? 'Screen Sharing'
                      : 'Session Active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.touch_app,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}