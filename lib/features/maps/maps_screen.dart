import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late mb.MapboxMap _mapboxMap;

  // Default location (Universitas Gadjah Mada, Yogyakarta)
  static const LatLng _initialPosition = LatLng(-7.771043857941956, 110.37910160750407);
  static const double _initialZoom = 18.0;

  Position? _currentPosition;
  final List<mb.PointAnnotation> _markers = [];
  bool _isLoading = true;
  String _currentStyle = 'custom'; // Options: 'custom', 'satellite', 'street', 'light', 'dark'
  mb.PointAnnotationManager? _pointAnnotationManager;
  double _currentZoom = _initialZoom;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled.');
        _useDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions denied. Using default location.');
          _useDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions permanently denied. Using default location.');
        _useDefaultLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Add current location marker after map is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addCurrentLocationMarker(position);
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location acquired successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      String errorMessage = 'Error getting location: $e';

      // Check for common iOS emulator issues
      if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        errorMessage = 'Location permission issue. Using default location for now.';
      } else if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        errorMessage = 'Location request timed out. Using default location.';
      } else if (e.toString().contains('location') && e.toString().contains('unavailable')) {
        errorMessage = 'Location services unavailable. Using default location.';
      }

      _showLocationError(errorMessage);
      _useDefaultLocation();
    }
  }

  void _useDefaultLocation() {
    setState(() {
      _currentPosition = Position(
        latitude: _initialPosition.latitude,
        longitude: _initialPosition.longitude,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      _isLoading = false;
    });

    // Add marker for default location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addCurrentLocationMarker(_currentPosition!);
    });
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _initializeAnnotationManagers();
  }

  Future<void> _initializeAnnotationManagers() async {
    try {
      _pointAnnotationManager = await _mapboxMap.annotations.createPointAnnotationManager();

      // Add current location marker if available
      if (_currentPosition != null) {
        _addCurrentLocationMarker(_currentPosition!);
      }
    } catch (e) {
      debugPrint('Error initializing annotation managers: $e');
    }
  }

  Future<void> _addCurrentLocationMarker(Position position) async {
    if (_pointAnnotationManager == null) return;

    try {
      final markerOptions = mb.PointAnnotationOptions(
        geometry: mb.Point(
          coordinates: mb.Position(position.longitude, position.latitude),
        ),
        iconSize: 1.5,
      );

      final annotation = await _pointAnnotationManager!.create(markerOptions);
      _markers.add(annotation);
    } catch (e) {
      debugPrint('Error adding current location marker: $e');
    }
  }

  Future<void> _addMapMarker(LatLng latLng) async {
    if (_pointAnnotationManager == null) return;

    try {
      final markerOptions = mb.PointAnnotationOptions(
        geometry: mb.Point(
          coordinates: mb.Position(latLng.longitude, latLng.latitude),
        ),
        iconSize: 1.5,
      );

      final annotation = await _pointAnnotationManager!.create(markerOptions);
      _markers.add(annotation);
    } catch (e) {
      debugPrint('Error adding map marker: $e');
    }
  }

  void _showLocationError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => _showPermissionDialog(),
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To enable location access in iOS Simulator:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. Go to iOS Simulator Settings app'),
              Text('2. Tap "Privacy & Security"'),
              Text('3. Tap "Location Services"'),
              Text('4. Enable Location Services'),
              Text('5. Find "Pix2Land" and set to "While Using"'),
              SizedBox(height: 12),
              Text(
                'Or continue with default location (UGM Campus)',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Use Default Location'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  void _onMapTapped(mb.ScreenCoordinate coordinate) async {
    // For now, just add a marker at the current position
    if (_currentPosition != null) {
      final latLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      await _addMapMarker(latLng);
      _showCoordinateInfo(latLng);
    }
  }

  void _showCoordinateInfo(LatLng latLng) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lat: ${latLng.latitude.toStringAsFixed(6)}\nLng: ${latLng.longitude.toStringAsFixed(6)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleMapType() {
    String nextStyle;

    switch (_currentStyle) {
      case 'custom':
        nextStyle = 'satellite';
        break;
      case 'satellite':
        nextStyle = 'street';
        break;
      case 'street':
        nextStyle = 'light';
        break;
      case 'light':
        nextStyle = 'dark';
        break;
      case 'dark':
      default:
        nextStyle = 'custom';
        break;
    }

    setState(() {
      _currentStyle = nextStyle;
    });

    // Style switching will recreate the map widget with new style
  }

  String _getStyleUri() {
    switch (_currentStyle) {
      case 'satellite':
        return MapboxConfig.satelliteStyle;
      case 'street':
        return MapboxConfig.streetStyle;
      case 'light':
        return MapboxConfig.lightStyle;
      case 'dark':
        return MapboxConfig.darkStyle;
      case 'custom':
      default:
        return MapboxConfig.styleUrl;
    }
  }

  String _getMapTypeName() {
    switch (_currentStyle) {
      case 'satellite':
        return 'Satellite';
      case 'street':
        return 'Street';
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'custom':
      default:
        return 'Custom';
    }
  }

  IconData _getMapTypeIcon() {
    switch (_currentStyle) {
      case 'satellite':
        return Icons.satellite;
      case 'street':
        return Icons.map;
      case 'light':
        return Icons.light_mode;
      case 'dark':
        return Icons.dark_mode;
      case 'custom':
      default:
        return Icons.layers;
    }
  }

  void _clearMarkers() async {
    if (_pointAnnotationManager != null) {
      try {
        // Clear all annotations
        await _pointAnnotationManager!.deleteAll();
        _markers.clear();

        // Re-add current location marker if available
        if (_currentPosition != null) {
          await _addCurrentLocationMarker(_currentPosition!);
        }
      } catch (e) {
        debugPrint('Error clearing markers: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geodetic Maps'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_getMapTypeIcon()),
            onPressed: _toggleMapType,
            tooltip: 'Map: ${_getMapTypeName()}',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearMarkers,
            tooltip: 'Clear Markers',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Current Location',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map...'),
                ],
              ),
            )
          : Stack(
              children: [
                mb.MapWidget(
                  key: ValueKey('mapbox_map_$_currentStyle'),
                  onMapCreated: _onMapCreated,
                  styleUri: _getStyleUri(),
                  cameraOptions: mb.CameraOptions(
                    center: mb.Point(
                      coordinates: mb.Position(
                        _currentPosition?.longitude ?? _initialPosition.longitude,
                        _currentPosition?.latitude ?? _initialPosition.latitude,
                      ),
                    ),
                    zoom: _currentZoom,
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Survey Tools',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.place, color: AppTheme.primaryColor),
                                  Text('${_markers.length} Points'),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(Icons.straighten, color: AppTheme.accentColor),
                                  const Text('Measure'),
                                ],
                              ),
                              Column(
                                children: [
                                  const Icon(Icons.area_chart, color: AppTheme.successColor),
                                  const Text('Area'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}