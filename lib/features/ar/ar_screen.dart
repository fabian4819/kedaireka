import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  String _statusMessage = 'Ready to launch AR';

  // Measurement data
  int _pointCount = 0;
  double? _currentArea;
  double? _currentPerimeter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupUnityMessageListener();
    _initializeLocation();
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

  Future<void> _initializeLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusMessage = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage = 'Location permissions are permanently denied';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Location permission granted. Ready to launch AR';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing location: $e';
      });
    }
  }

  Future<void> _launchUnity() async {
    try {
      setState(() {
        _statusMessage = 'Launching Unity AR...';
      });

      // Launch Unity activity
      await _unityService.launchUnity();

      // Get current position
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

      setState(() {
        _isARInitialized = true;
        _statusMessage = 'AR session initializing...';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error launching AR: $e';
      });
    }
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
      // In production, parse JSON data
      setState(() {
        _statusMessage = 'Measurement completed!';
      });
    } catch (e) {
      debugPrint('Error parsing measurement: $e');
    }
  }

  Future<void> _startMeasurement() async {
    if (!_isARInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please launch AR first')),
      );
      return;
    }

    await _unityService.startMeasurement('area');
  }

  Future<void> _completeMeasurement() async {
    await _unityService.completeMeasurement();
  }

  Future<void> _resetARSession() async {
    await _unityService.resetARSession();
    setState(() {
      _isARInitialized = false;
      _isMeasuring = false;
      _pointCount = 0;
      _currentArea = null;
      _currentPerimeter = null;
    });
  }

  Future<void> _closeUnity() async {
    await _unityService.closeUnity();
    setState(() {
      _isARInitialized = false;
      _isMeasuring = false;
      _statusMessage = 'AR session closed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Land Mapping'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isARInitialized) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetARSession,
              tooltip: 'Reset AR Session',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _closeUnity,
              tooltip: 'Close AR',
            ),
          ],
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // AR Icon
              Icon(
                _isARInitialized ? Icons.camera_alt : Icons.view_in_ar,
                size: 100,
                color: _isARInitialized ? Colors.green : AppTheme.accentColor,
              ),
              const SizedBox(height: 32),

              // Status Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isMeasuring) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Points: $_pointCount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (_currentArea != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Area: ${_currentArea!.toStringAsFixed(2)} m²',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentPerimeter != null)
                        Text(
                          'Perimeter: ${_currentPerimeter!.toStringAsFixed(2)} m',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Launch/Control Buttons
              if (!_isARInitialized)
                ElevatedButton.icon(
                  onPressed: _launchUnity,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Launch Unity AR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                )
              else ...[
                if (!_isMeasuring)
                  ElevatedButton.icon(
                    onPressed: _startMeasurement,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Start Measuring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _completeMeasurement,
                        icon: const Icon(Icons.check),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _completeMeasurement,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Tap "Launch Unity AR" to start'),
                    const Text('2. Point camera at ground surface'),
                    const Text('3. Wait for AR to initialize'),
                    const Text('4. Tap "Start Measuring" to begin'),
                    const Text('5. Tap on surfaces to add points'),
                    const Text('6. Tap "Complete" when done'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
