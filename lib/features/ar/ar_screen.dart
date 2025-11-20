import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/unity_channel_service.dart';
import '../../core/services/map_tiles_service.dart';
import '../../core/services/storage_service.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with WidgetsBindingObserver {
  final UnityChannelService _unityService = UnityChannelService();

  bool _isARInitialized = false;
  bool _isMeasuring = false;
  String _statusMessage = 'AR Mapping feature coming soon!';

  // Measurement data
  int _pointCount = 0;
  double? _currentArea;
  double? _currentPerimeter;

  // Buildings from backend
  List<Building> _buildings = [];
  BuildingStats? _buildingStats;
  List<Building> _savedBuildings = [];
  Building? _selectedBuilding;
  bool _isLoadingBuildings = false;
  bool _showBuildings = true;

  // Mapbox controller for AR screen
  late mb.MapboxMap _mapboxMap;
  mb.PolygonAnnotationManager? _polygonAnnotationManager;
  mb.PointAnnotationManager? _pointAnnotationManager;

  // Default location (Central Jakarta area near buildings data)
  static const LatLng _initialPosition = LatLng(-6.239, 106.792);
  static const double _initialZoom = 16.0;

  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupUnityMessageListener();
    _loadBuildings();
    _getCurrentLocation();
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

  Future<void> _loadBuildings() async {
    setState(() => _isLoadingBuildings = true);
    try {
      final results = await Future.wait([
        MapTilesService().getBuildings(),
        MapTilesService().getBuildingStats(),
      ]);
      final buildings = results[0] as List<Building>;
      final stats = results[1] as BuildingStats;
      setState(() {
        _buildings = buildings;
        _buildingStats = stats;
        _isLoadingBuildings = false;
      });
    } catch (e) {
      setState(() => _isLoadingBuildings = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading buildings: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useDefaultLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      _useDefaultLocation();
    }
  }

  void _useDefaultLocation() {
    setState(() {
      _currentPosition = Position(
        latitude: _initialPosition.latitude,
        longitude: _initialPosition.longitude,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
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
      // In production, parse JSON data
      setState(() {
        _statusMessage = 'Measurement completed!';
      });
    } catch (e) {
      debugPrint('Error parsing measurement: $e');
    }
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _initializeAnnotationManagers();
  }

  Future<void> _initializeAnnotationManagers() async {
    try {
      _polygonAnnotationManager = await _mapboxMap.annotations.createPolygonAnnotationManager();
      _pointAnnotationManager = await _mapboxMap.annotations.createPointAnnotationManager();

      // Add current location marker if available
      if (_currentPosition != null) {
        _addCurrentLocationMarker(_currentPosition!);
      }

      // Add buildings polygons if loaded
      if (_buildings.isNotEmpty && _showBuildings) {
        _addBuildingPolygons();
      }
    } catch (e) {
      debugPrint('Error initializing annotation managers: $e');
    }
  }

  Future<void> _addBuildingPolygons() async {
    if (_polygonAnnotationManager == null || _buildings.isEmpty || _buildingStats == null) return;

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      for (final building in _buildings.take(30)) { // Limit to 30 buildings for performance
        if (building.coordinates.isNotEmpty &&
            building.coordinates[0].isNotEmpty &&
            building.coordinates[0][0].isNotEmpty) {

          try {
            final positions = building.coordinates[0][0].map((point) {
              return mb.Position(point[0], point[1]);
            }).toList();

            // Color based on NJOP value
            final color = _getBuildingColor(building);
            final fillColor = _colorToArgb(color.withOpacity(0.7));

            await _polygonAnnotationManager!.create(
              mb.PolygonAnnotationOptions(
                geometry: mb.Polygon(coordinates: [positions]),
                fillOutlineColor: 0xFF000000, // Black outline
                fillColor: fillColor,
              ),
            );
          } catch (e) {
            debugPrint('Error adding building ${building.id}: $e');
            continue;
          }
        }
      }
    } catch (e) {
      debugPrint('Error in building polygon creation: $e');
    }
  }

  Color _getBuildingColor(Building building) {
    if (_buildingStats == null) return Colors.grey;

    final njop = building.njopTotal ?? 0;
    final min = _buildingStats!.minNjopTotal;
    final max = _buildingStats!.maxNjopTotal;

    // Normalize to 0-1 range
    final normalized = (njop - min) / (max - min);

    // Interpolate between green (low) and red (high)
    if (normalized < 0.5) {
      return Color.lerp(Colors.green, Colors.yellow, normalized * 2) ?? Colors.grey;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, (normalized - 0.5) * 2) ?? Colors.grey;
    }
  }

  int _colorToArgb(Color color) {
    return ((color.alpha * 255).round() << 24) |
           ((color.red * 255).round() << 16) |
           ((color.green * 255).round() << 8) |
           ((color.blue * 255).round());
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

      await _pointAnnotationManager!.create(markerOptions);
    } catch (e) {
      debugPrint('Error adding current location marker: $e');
    }
  }

  void _checkBuildingSelection(LatLng point) {
    for (final building in _buildings) {
      final bounds = building.getBounds();
      if (_isPointInBounds(point, bounds)) {
        setState(() {
          _selectedBuilding = building;
        });
        _showBuildingInfo(building);
        _highlightBuilding(building);
        break;
      }
    }
  }

  bool _isPointInBounds(LatLng point, LatLngBounds bounds) {
    return point.latitude >= bounds.south &&
           point.latitude <= bounds.north &&
           point.longitude >= bounds.west &&
           point.longitude <= bounds.east;
  }

  Future<void> _highlightBuilding(Building building) async {
    if (_polygonAnnotationManager == null) return;

    try {
      if (building.coordinates.isNotEmpty &&
          building.coordinates[0].isNotEmpty &&
          building.coordinates[0][0].isNotEmpty) {

        final positions = building.coordinates[0][0].map((point) {
          return mb.Position(point[0], point[1]);
        }).toList();

        final color = _getBuildingColor(building);
        final fillColor = _colorToArgb(color.withOpacity(0.9));

        await _polygonAnnotationManager!.create(
          mb.PolygonAnnotationOptions(
            geometry: mb.Polygon(coordinates: [positions]),
            fillOutlineColor: 0xFF000000, // Black outline
            fillColor: fillColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error highlighting building: $e');
    }
  }

  void _showBuildingInfo(Building building) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ARBuildingInfoSheet(
        building: building,
        onSave: () => _saveBuilding(building),
        onLaunchAR: _isARInitialized ? _startMeasurement : _launchUnity,
        isARReady: _isARInitialized,
      ),
    );
  }

  void _saveBuilding(Building building) async {
    try {
      // Save to local storage
      await StorageService().saveBuilding(building.id);

      // Update UI state
      setState(() {
        building.isSaved = true;
        _savedBuildings.add(building);
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Building ${building.id} saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save building: $e')),
      );
    }
  }

  void _toggleBuildings() {
    setState(() {
      _showBuildings = !_showBuildings;
    });

    if (_polygonAnnotationManager != null) {
      _polygonAnnotationManager!.deleteAll();
      if (_showBuildings) _addBuildingPolygons();
    }
  }

  Future<void> _launchUnity() async {
    try {
      setState(() {
        _statusMessage = 'Checking permissions...';
      });

      // Check camera permission (required for ARCore)
      PermissionStatus cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          setState(() {
            _statusMessage = 'Camera permission is required for AR';
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission is required for AR functionality'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

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
        title: const Text('AR Buildings Map'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showBuildings ? Icons.location_city : Icons.location_city_outlined),
            onPressed: _toggleBuildings,
            tooltip: _showBuildings ? 'Hide Buildings' : 'Show Buildings',
          ),
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
      body: Column(
        children: [
          // Mapbox Map for Buildings
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                mb.MapWidget(
                  key: const ValueKey('ar_buildings_map'),
                  onMapCreated: _onMapCreated,
                  styleUri: 'mapbox://styles/mapbox/light-v11',
                  cameraOptions: mb.CameraOptions(
                    center: mb.Point(
                      coordinates: mb.Position(
                        _currentPosition?.longitude ?? _initialPosition.longitude,
                        _currentPosition?.latitude ?? _initialPosition.latitude,
                      ),
                    ),
                    zoom: _initialZoom,
                    pitch: 45.0,
                  ),
                ),

                // Loading indicator
                if (_isLoadingBuildings)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Loading buildings...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),

                // Map instructions
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Buildings Map:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Tap on buildings to select',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• Color: Green (low NJOP) → Red (high NJOP)',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // AR Section
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  // AR Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isARInitialized ? Icons.camera_alt : Icons.view_in_ar,
                          size: 48,
                          color: _isARInitialized ? Colors.green : AppTheme.accentColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isMeasuring) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Points: $_pointCount',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (_currentArea != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Area: ${_currentArea!.toStringAsFixed(2)} m²',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_currentPerimeter != null)
                            Text(
                              'Perimeter: ${_currentPerimeter!.toStringAsFixed(2)} m',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // AR Controls
                  Row(
                    children: [
                      if (!_isARInitialized)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _launchUnity,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Launch AR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        )
                      else ...[
                        if (!_isMeasuring)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _startMeasurement,
                              icon: const Icon(Icons.add_location),
                              label: const Text('Start Measuring'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _completeMeasurement,
                                    icon: const Icon(Icons.check),
                                    label: const Text('Complete'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _completeMeasurement,
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('Cancel'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Instructions
                  Text(
                    'Select a building on the map, then launch AR for measurement',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// AR Building Information Modal Widget
class _ARBuildingInfoSheet extends StatelessWidget {
  final Building building;
  final VoidCallback onSave;
  final VoidCallback onLaunchAR;
  final bool isARReady;

  const _ARBuildingInfoSheet({
    required this.building,
    required this.onSave,
    required this.onLaunchAR,
    required this.isARReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Building Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: AppTheme.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Building #${building.id}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        building.isSaved ? 'Saved' : 'Available',
                        style: TextStyle(
                          fontSize: 12,
                          color: building.isSaved ? Colors.green : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Building Details
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.attach_money,
                  label: 'NJOP Total',
                  value: building.formattedNjop,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.local_fire_department,
                  label: 'Fire Hazard',
                  value: building.fireHazard?.toStringAsFixed(3) ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.flood,
                  label: 'Flood Hazard',
                  value: building.floodHazard?.toStringAsFixed(3) ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.warning,
                  label: 'Total Hazard',
                  value: building.hazardSum?.toStringAsFixed(3) ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AR Action Section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_in_ar, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    const Text(
                      'AR Measurement',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Measure this building in AR for accurate dimensions and area calculation.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onLaunchAR,
                    icon: Icon(isARReady ? Icons.check_circle : Icons.play_arrow),
                    label: Text(isARReady ? 'Start Measurement' : 'Launch AR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: building.isSaved ? null : onSave,
                    icon: Icon(
                      building.isSaved ? Icons.check_circle : Icons.save,
                    ),
                    label: Text(
                      building.isSaved ? 'Saved' : 'Save Building',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: building.isSaved ? Colors.grey : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}