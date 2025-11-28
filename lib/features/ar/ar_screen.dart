import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/unity_channel_service.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with WidgetsBindingObserver {
  final UnityChannelService _unityService = UnityChannelService();

  bool _isARInitialized = false;
  bool _isMeasuring = false;
  String _statusMessage = 'Ready to launch AR for measurement';
  int _pointCount = 0;
  double? _currentArea;
  double? _currentPerimeter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupUnityMessageListener();
  }

  @override
  void dispose() {
    _unityService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _unityService.pauseUnity();
        break;
      case AppLifecycleState.resumed:
        _unityService.resumeUnity();
        break;
      default:
        break;
    }
  }

  void _setupUnityMessageListener() {
    _unityService.onUnityMessage.listen((message) {
      _handleUnityMessage(message);
    });
  }

  void _handleUnityMessage(Map<String, dynamic> message) {
    final String type = message['type'] ?? '';
    final String data = message['data'] ?? '';

    setState(() {
      switch (type) {
        case 'unity_ready':
          _statusMessage = 'Unity ready: $data';
          break;
        case 'ar_initialized':
          _isARInitialized = true;
          _statusMessage = 'AR initialized. Ready to measure!';
          break;
        case 'ar_error':
          _statusMessage = 'AR Error: $data';
          break;
        case 'measurement_started':
          _isMeasuring = true;
          _pointCount = 0;
          _currentArea = null;
          _currentPerimeter = null;
          _statusMessage = 'Tap to add measurement points';
          break;
        case 'point_added':
          _pointCount++;
          _statusMessage = 'Point $_pointCount added';
          break;
        case 'measurement_completed':
          _isMeasuring = false;
          _parseMeasurementResult(data);
          break;
        case 'tracking_state':
          _statusMessage = 'Tracking: $data';
          break;
        case 'error':
          _statusMessage = 'Error: $data';
          break;
      }
    });
  }

  void _parseMeasurementResult(String jsonData) {
    try {
      // In production, parse JSON data for area and perimeter
      setState(() {
        _statusMessage = 'Measurement completed!';
        // Mock data for now
        _currentArea = 150.5;
        _currentPerimeter = 50.2;
      });
    } catch (e) {
      debugPrint('Error parsing measurement: $e');
    }
  }

  Future<void> _launchUnity() async {
    try {
      setState(() {
        _statusMessage = 'Checking permissions...';
      });

      // Check and request camera permission with enhanced handling
      PermissionStatus cameraStatus = await Permission.camera.status;
      debugPrint('Camera permission status: $cameraStatus');

      if (!cameraStatus.isGranted) {
        debugPrint('Camera permission not granted, requesting...');
        setState(() {
          _statusMessage = 'Requesting camera permission...';
        });

        // Show a dialog explaining why camera is needed
        _showCameraPermissionDialog();

        cameraStatus = await Permission.camera.request();
        debugPrint('Camera permission after request: $cameraStatus');

        if (!cameraStatus.isGranted) {
          debugPrint('Camera permission denied by user');
          setState(() {
            _statusMessage = 'Camera permission denied. Please enable in Settings.';
          });

          if (mounted) {
            _showPermissionDeniedDialog();
          }
          return;
        }

        if (cameraStatus.isPermanentlyDenied) {
          debugPrint('Camera permission permanently denied');
          setState(() {
            _statusMessage = 'Camera permission permanently denied. Please enable in Settings.';
          });

          if (mounted) {
            _showPermanentlyDeniedDialog();
          }
          return;
        }
      }

      setState(() {
        _statusMessage = 'Launching Unity AR...';
      });

      // Add a small delay after permission is granted before launching Unity
      await Future.delayed(const Duration(milliseconds: 500));

      // Launch Unity activity
      await _unityService.launchUnity();

      // Get current position for AR initialization
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Give Unity time to initialize
        await Future.delayed(const Duration(seconds: 2));

        // Send location to Unity
        await _unityService.initializeARWithLocation(
          position.latitude,
          position.longitude,
          position.altitude,
          position.accuracy,
        );
      } catch (e) {
        debugPrint('Warning: Could not get location for AR: $e');
        // Continue without location
        await Future.delayed(const Duration(seconds: 2));
      }

      setState(() {
        _isARInitialized = true;
        _statusMessage = 'AR session ready for measurement';
      });
    } catch (e) {
      debugPrint('Error launching AR: $e');
      setState(() {
        _statusMessage = 'Error launching AR: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _startMeasurement() async {
    if (!_isARInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please launch AR first')),
      );
      return;
    }

    try {
      await _unityService.startMeasurement('area');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting measurement: $e')),
      );
    }
  }

  Future<void> _completeMeasurement() async {
    try {
      await _unityService.completeMeasurement();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing measurement: $e')),
      );
    }
  }

  Future<void> _cancelMeasurement() async {
    try {
      await _unityService.resetARSession();
      setState(() {
        _isMeasuring = false;
        _pointCount = 0;
        _currentArea = null;
        _currentPerimeter = null;
        _statusMessage = 'Measurement cancelled';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling measurement: $e')),
      );
    }
  }

  Future<void> _closeUnity() async {
    try {
      await _unityService.closeUnity();
      setState(() {
        _isARInitialized = false;
        _isMeasuring = false;
        _pointCount = 0;
        _currentArea = null;
        _currentPerimeter = null;
        _statusMessage = 'AR session closed';
      });
    } catch (e) {
      debugPrint('Error closing Unity: $e');
    }
  }

  void _showCameraPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Icon(Icons.camera_alt, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Camera Permission Required',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Pix2Land needs camera access to provide AR measurement features. This allows you to measure land areas and buildings using your device\'s camera.\n\nPlease grant camera permission when prompted.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Permission Denied',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Camera permission was denied. AR measurement features require camera access to function.\n\nPlease enable camera permission in your device settings to use AR features.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            if (Platform.isIOS)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
          ],
        );
      },
    );
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Permission Permanently Denied',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Camera permission was permanently denied. You\'ll need to enable it in your device settings to use AR features.\n\nGo to Settings > Pix2Land > Camera and enable permission.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Measurement'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isARInitialized) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _closeUnity,
              tooltip: 'Close AR',
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AR Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _isARInitialized ? Icons.camera_alt : Icons.view_in_ar,
                    size: 80,
                    color: _isARInitialized ? Colors.green : AppTheme.accentColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isARInitialized ? 'AR Ready' : 'AR Measurement',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Measurement Results
                  if (_isMeasuring) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Measuring...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Points: $_pointCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_currentArea != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Measurement Complete',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Area: ${_currentArea!.toStringAsFixed(2)} m²',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_currentPerimeter != null)
                            Text(
                              'Perimeter: ${_currentPerimeter!.toStringAsFixed(2)} m',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // AR Controls
            if (!_isARInitialized)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchUnity,
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text('Launch AR', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else ...[
              if (!_isMeasuring)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startMeasurement,
                    icon: const Icon(Icons.add_location, size: 24),
                    label: const Text('Start Measuring', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _completeMeasurement,
                        icon: const Icon(Icons.check, size: 24),
                        label: const Text('Complete', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cancelMeasurement,
                        icon: const Icon(Icons.cancel, size: 24),
                        label: const Text('Cancel', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isARInitialized
                        ? 'Point your device at the area you want to measure'
                        : 'Launch AR to start measuring land areas and buildings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}