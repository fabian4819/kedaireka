import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

/// AR Screen with Unity AR integration using URL scheme deep link.
/// Launches Unity AR app (geoclarity) via custom URL scheme.
class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  bool _isLaunching = false;

  Future<void> _launchUnityAR() async {
    setState(() {
      _isLaunching = true;
    });

    try {
      final Uri url = Uri.parse('geoclarity://launch');
      
      // Note: canLaunchUrl() is unreliable for custom URL schemes on iOS
      // We directly launch and catch errors instead
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        if (mounted) {
          _showErrorDialog(
            'Unity AR App Not Installed',
            'Please install the GeoClarity AR app first.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Failed to Launch AR',
          'Could not open Unity AR app. Please make sure it is installed.\n\nError: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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
        title: const Text('AR Measurement'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(
                AppTheme.primaryColor.r.toInt(),
                AppTheme.primaryColor.g.toInt(),
                AppTheme.primaryColor.b.toInt(),
                0.1,
              ),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // AR Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(
                      AppTheme.primaryColor.r.toInt(),
                      AppTheme.primaryColor.g.toInt(),
                      AppTheme.primaryColor.b.toInt(),
                      0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.view_in_ar,
                    size: 80,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'GeoClarity AR',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Visualisasi bangunan dan lahan dalam Augmented Reality dengan data geospasial yang akurat.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // Launch AR Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLaunching ? null : _launchUnityAR,
                    icon: _isLaunching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      _isLaunching ? 'Launching...' : 'Launch AR Experience',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Info text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Requires GeoClarity AR app installed',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
