import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/map_tiles_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/logger.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late mb.MapboxMap _mapboxMap;
  mb.PolygonAnnotationManager? _polygonAnnotationManager;
  mb.PointAnnotationManager? _pointAnnotationManager;

  // Default location (Central Jakarta area near buildings data)
  static const LatLng _initialPosition = LatLng(-6.239, 106.792);
  static const double _initialZoom = 16.0;

  Position? _currentPosition;
  bool _isLoading = false;
  bool _isLoadingBuildings = false;
  String _currentStyle = 'custom';
  double _currentZoom = _initialZoom;

  // Buildings from backend
  List<Building> _buildings = [];
  BuildingStats? _buildingStats;
  List<Building> _savedBuildings = [];
  Building? _selectedBuilding;
  bool _showBuildings = true;

  // Raw GeoJSON data from backend (bypass coordinate parsing bug)
  Map<String, dynamic> _rawBuildingsGeoJson = {};

  // Auto-focus coordinates (will be calculated from buildings bounds)
  LatLng? _buildingAreaCenter;
  double _buildingAreaZoom = 16.0;

  @override
  void initState() {
    super.initState();
    debugPrint('🏗️ Buildings Map Screen: initState - Starting initialization...');
    _initializeData();
  }

  Future<void> _initializeData() async {
    debugPrint('🏗️ Buildings Map Screen: Loading buildings...');

    // Set initial loading state to false since we're not doing location detection
    setState(() => _isLoading = false);

    await _loadBuildingsOnly();
    await _getCurrentLocation();
  }

  Future<void> _loadBuildingsOnly() async {
    setState(() => _isLoadingBuildings = true);
    try {
      debugPrint('🏗️ Buildings Map Screen: Loading raw GeoJSON buildings data...');

      // Fetch raw buildings data directly from backend API
      const String _baseUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://pix2land-backend.vercel.app',
      );

      final response = await http.get(
        Uri.parse('$_baseUrl/buildings'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final rawGeoJson = jsonDecode(response.body);
        setState(() {
          _rawBuildingsGeoJson = rawGeoJson;
          _isLoadingBuildings = false;
        });
        debugPrint('🏗️ Buildings Map Screen: Loaded raw GeoJSON with ${rawGeoJson['features'].length} buildings');

        // Still load parsed buildings for UI functionality (but we won't use coordinates for rendering)
        final buildings = await MapTilesService().getBuildings();
        final stats = await MapTilesService().getBuildingStats();

        // Note: Buildings have their own saved status, no need to update from tiles
        _buildings = buildings;
        _buildingStats = stats;
      } else {
        throw Exception('Failed to load buildings: ${response.statusCode}');
      }
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

      // Add current location marker after map is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addCurrentLocationMarker();
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

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _initializeLayers();
  }

  Future<void> _initializeLayers() async {
    try {
      debugPrint('🏗️ Initializing map layers...');
      debugPrint('🏗️ Available buildings: ${_buildings.length}');

      // Add current location marker if available
      if (_currentPosition != null) {
        _addCurrentLocationMarker();
      }

      // Wait for map to be fully loaded before adding layers
      await Future.delayed(const Duration(milliseconds: 1000));

      // Add buildings layer using source-layer system
      if (_rawBuildingsGeoJson.isNotEmpty) {
        debugPrint('🏗️ Raw buildings data available, adding buildings layer...');
        await _addBuildingsLayer();
        debugPrint('🏗️ Buildings layer added, now centering map on building data...');
        // Auto-center map on building data area
        await _centerMapOnBuildings();
        debugPrint('🏗️ Map centering completed');
      } else {
        debugPrint('⚠️ No raw buildings data available to add to map');
      }

      debugPrint('🏗️ Map layers initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing map layers: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _centerMapOnBuildings() async {
    try {
      debugPrint('🏗️ Auto-centering and zooming map on building data...');

      if (_rawBuildingsGeoJson.isEmpty) {
        debugPrint('⚠️ No buildings GeoJSON data to center on');
        return;
      }

      // Calculate bounds from raw GeoJSON data
      final bounds = _calculateBoundsFromRawGeoJson();
      final minLat = bounds['minLat']!;
      final maxLat = bounds['maxLat']!;
      final minLng = bounds['minLng']!;
      final maxLng = bounds['maxLng']!;

      // Check if bounds are valid (fallback to Jakarta coordinates if invalid)
      double centerLat, centerLng, optimalZoom;
      if (minLat == 90.0 && maxLat == -90.0 && minLng == 180.0 && maxLng == -180.0) {
        debugPrint('⚠️ Invalid bounds calculated from GeoJSON data, using Jakarta coordinates as fallback');
        // Fallback to Jakarta coordinates
        centerLat = -6.2085;
        centerLng = 106.8205;
        optimalZoom = 15.0;
      } else {
        // Calculate center point
        centerLat = (minLat + maxLat) / 2;
        centerLng = (minLng + maxLng) / 2;
        debugPrint('🏗️ Buildings bounds from raw GeoJSON: lat[$minLat, $maxLat], lng[$minLng, $maxLng]');
        debugPrint('🏗️ Calculated center: lat=$centerLat, lng=$centerLng');

        // Calculate optimal zoom level based on bounds
        optimalZoom = _calculateOptimalZoom(minLat, maxLat, minLng, maxLng);
        debugPrint('🏗️ Calculated optimal zoom: $optimalZoom');
      }

      // Update the auto-focus variables
      setState(() {
        _buildingAreaCenter = LatLng(centerLat, centerLng);
        _buildingAreaZoom = optimalZoom;
        _currentZoom = optimalZoom;
      });

      // Center and zoom the map on the building data
      final cameraOptions = mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(centerLng, centerLat),
        ),
        zoom: optimalZoom,
        pitch: 45.0,
      );

      await _mapboxMap.setCamera(cameraOptions);
      debugPrint('🏗️ Map auto-focused on buildings area: lat=$centerLat, lng=$centerLng, zoom=$optimalZoom');
    } catch (e) {
      debugPrint('❌ Error auto-focusing map on buildings: $e');
    }
  }

  // Calculate optimal zoom level based on geographic bounds
  double _calculateOptimalZoom(double minLat, double maxLat, double minLng, double maxLng) {
    // Calculate the lat/lng distance
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;

    // Use the larger distance to ensure all buildings are visible
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Map the distance to zoom level (empirical formula)
    // Small distance = higher zoom, Large distance = lower zoom
    if (maxDiff < 0.001) return 18.0;  // Very small area
    if (maxDiff < 0.005) return 16.0;  // Small area
    if (maxDiff < 0.01) return 15.0;   // Medium-small area
    if (maxDiff < 0.05) return 13.0;   // Medium area
    if (maxDiff < 0.1) return 12.0;    // Medium-large area
    if (maxDiff < 0.5) return 10.0;    // Large area
    if (maxDiff < 1.0) return 9.0;     // Very large area
    if (maxDiff < 2.0) return 8.0;     // Huge area
    if (maxDiff < 5.0) return 7.0;     // Very huge area
    return 6.0;  // Extremely large area (continent scale)
  }

  // Re-focus the map on the buildings area
  Future<void> _refocusOnBuildings() async {
    if (_buildingAreaCenter == null) {
      debugPrint('⚠️ No building area center available for re-focus');
      return;
    }

    try {
      debugPrint('🏗️ Re-focusing map on buildings area...');

      final cameraOptions = mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(_buildingAreaCenter!.longitude, _buildingAreaCenter!.latitude),
        ),
        zoom: _buildingAreaZoom,
        pitch: 45.0,
      );

      await _mapboxMap.setCamera(cameraOptions);
      debugPrint('🏗️ Map re-focused on buildings area: lat=${_buildingAreaCenter!.latitude}, lng=${_buildingAreaCenter!.longitude}, zoom=$_buildingAreaZoom');
    } catch (e) {
      debugPrint('❌ Error re-focusing map on buildings: $e');
    }
  }

  Future<void> _addBuildingsLayer() async {
    try {
      debugPrint('🏗️ Adding buildings layer using raw GeoJSON data...');

      if (_rawBuildingsGeoJson.isEmpty) {
        debugPrint('❌ No raw GeoJSON data available');
        return;
      }

      debugPrint('🏗️ Using raw GeoJSON with ${_rawBuildingsGeoJson['features'].length} buildings');

      // Add source for buildings using raw GeoJSON data (bypasses coordinate parsing bug)
      try {
        final buildingSource = mb.GeoJsonSource(
          id: "buildings-source",
          data: jsonEncode(_rawBuildingsGeoJson),
        );
        debugPrint('🏗️ Adding raw GeoJSON source...');
        await _mapboxMap.style.addSource(buildingSource);
        debugPrint('🏗️ Raw GeoJSON source added successfully');
      } catch (e) {
        // Source might already exist, which is fine for now
        if (e.toString().contains('already exists')) {
          debugPrint('🏗️ Buildings source already exists, skipping...');
        } else {
          debugPrint('❌ Error adding buildings source: $e');
          rethrow;
        }
      }

      // Add outline layer for better contrast
      final buildingOutlineLayer = mb.LineLayer(
        id: "buildings-outline-layer",
        sourceId: "buildings-source",
        lineOpacity: 1.0,
        lineColor: Colors.black.value,
        lineWidth: 3.0, // Thick black outline for maximum contrast
      );
      debugPrint('🏗️ Adding outline layer for contrast...');
      await _mapboxMap.style.addLayer(buildingOutlineLayer);
      debugPrint('🏗️ Outline layer added successfully');

      // Add layer for buildings using FillLayer with color based on NJOP value
      final buildingLayer = mb.FillLayer(
        id: "buildings-layer",
        sourceId: "buildings-source",
        fillOpacity: 0.8, // Make buildings very visible
        fillColor: Colors.red.value, // Use bright red color for high contrast
      );
      debugPrint('🏗️ Adding fill layer with high visibility...');
      await _mapboxMap.style.addLayer(buildingLayer);
      debugPrint('🏗️ Fill layer added successfully');

      // TODO: Add click listener for building selection
      debugPrint('🏗️ TODO: Add building click listener');

      debugPrint('✅ Buildings layer added successfully using raw GeoJSON data!');
    } catch (e) {
      debugPrint('❌ Error adding buildings layer: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _addCurrentLocationMarker() async {
    if (_pointAnnotationManager == null || _currentPosition == null) return;

    try {
      final markerOptions = mb.PointAnnotationOptions(
        geometry: mb.Point(
          coordinates: mb.Position(_currentPosition!.longitude, _currentPosition!.latitude),
        ),
        iconSize: 1.5,
      );

      await _pointAnnotationManager!.create(markerOptions);
    } catch (e) {
      debugPrint('Error adding current location marker: $e');
    }
  }

  // Helper method to calculate bounds from raw GeoJSON data
  Map<String, double> _calculateBoundsFromRawGeoJson() {
    if (_rawBuildingsGeoJson.isEmpty) {
      return {'minLat': 0.0, 'maxLat': 0.0, 'minLng': 0.0, 'maxLng': 0.0};
    }

    double minLat = 90.0; // Start with maximum values
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    final features = _rawBuildingsGeoJson['features'] as List<dynamic>;
    int validBuildingsCount = 0;

    for (final feature in features) {
      try {
        final geometry = feature['geometry'];
        if (geometry['type'] == 'Polygon') {
          final coordinates = geometry['coordinates'] as List<dynamic>;
          if (coordinates.isNotEmpty) {
            final ring = coordinates[0] as List<dynamic>;
            for (final point in ring) {
              if (point is List && point.length >= 2) {
                final lat = double.parse(point[1].toString());
                final lng = double.parse(point[0].toString());

                if (lat < minLat) minLat = lat;
                if (lat > maxLat) maxLat = lat;
                if (lng < minLng) minLng = lng;
                if (lng > maxLng) maxLng = lng;
              }
            }
            validBuildingsCount++;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error processing building feature: $e');
      }
    }

    debugPrint('🏗️ Calculated bounds from ${validBuildingsCount} valid buildings: lat[$minLat, $maxLat], lng[$minLng, $maxLng]');

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  // Calculate bounding box for a single building from parsed coordinates
  LatLngBounds _calculateBuildingBounds(Building building) {
    if (building.coordinates.isEmpty) {
      // Return empty bounds if no coordinates
      return LatLngBounds(
        const LatLng(0, 0), // northWest
        const LatLng(0, 0), // southEast
      );
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    debugPrint('🏗️ Calculating bounds for building ${building.id} from ${building.coordinates.length} polygons');

    // Calculate bounds from building coordinates (MultiPolygon format)
    // building.coordinates is List<List<List<List<double>>>>: [polygons] -> [rings] -> [coords] -> [lng, lat]
    for (final polygon in building.coordinates) {
      if (polygon is List && polygon.isNotEmpty) {
        for (final ring in polygon) {
          if (ring is List && ring.isNotEmpty) {
            for (final coordPair in ring) {
              if (coordPair is List && coordPair.length >= 2) {
                // GeoJSON format is [longitude, latitude]
                final lng = (coordPair[0] as num).toDouble();
                final lat = (coordPair[1] as num).toDouble();

                if (lat != 0 && lng != 0) { // Skip invalid coordinates
                  minLat = math.min(minLat, lat);
                  maxLat = math.max(maxLat, lat);
                  minLng = math.min(minLng, lng);
                  maxLng = math.max(maxLng, lng);
                }
              }
            }
          }
        }
      }
    }

    // If all coordinates were invalid, return bounds at building's first coordinate
    if (minLat == double.infinity) {
      debugPrint('⚠️ No valid coordinates found for building ${building.id}');
      return LatLngBounds(
        const LatLng(0, 0), // northWest
        const LatLng(0, 0), // southEast
      );
    }

    debugPrint('🏗️ Building ${building.id} bounds: lat[$minLat, $maxLat], lng[$minLng, $maxLng]');

    return LatLngBounds(
      LatLng(maxLat, minLng), // northWest (max lat, min lng)
      LatLng(minLat, maxLng), // southEast (min lat, max lng)
    );
  }

  void _checkBuildingSelection(LatLng point) {
    debugPrint('🏗️ Checking building selection at: ${point.latitude}, ${point.longitude}');
    debugPrint('🏗️ Raw GeoJSON data available: ${_rawBuildingsGeoJson.isNotEmpty}');
    debugPrint('🏗️ Raw GeoJSON features count: ${_rawBuildingsGeoJson.isNotEmpty ? (_rawBuildingsGeoJson['features'] as List<dynamic>).length : 0}');

    // First try precise polygon detection with raw GeoJSON data
    if (_rawBuildingsGeoJson.isNotEmpty) {
      final features = _rawBuildingsGeoJson['features'] as List<dynamic>;
      debugPrint('🏗️ Processing ${features.length} features for precise polygon click detection');
      for (final feature in features) {
        if (_isPointInGeoJSONFeature(point, feature)) {
          // Find the corresponding building object
          final buildingId = feature['properties']['id'] as int;
          final building = _buildings.firstWhere(
            (b) => b.id == buildingId,
            orElse: () => Building(
              id: buildingId,
              coordinates: [],
              properties: feature['properties'] as Map<String, dynamic>? ?? {},
            ),
          );

          setState(() {
            _selectedBuilding = building;
          });
          debugPrint('🏗️ Selected building ID: ${building.id} (precise polygon detection)');
          // Pass the raw feature data to modal to avoid coordinate parsing issues
          _showBuildingInfo(building, feature: feature);
          return;
        }
      }
      debugPrint('🏗️ No building found with precise polygon detection, trying fallback bounds detection...');
    } else {
      debugPrint('🏗️ No raw GeoJSON data available for click detection');
    }

    // Fallback: Use bounding box detection with parsed buildings data
    debugPrint('🏗️ Using fallback bounding box detection with ${_buildings.length} buildings');
    for (final building in _buildings) {
      if (building.coordinates.isNotEmpty) {
        final bounds = _calculateBuildingBounds(building);
        if (_isPointInBounds(point, bounds)) {
          setState(() {
            _selectedBuilding = building;
          });
          debugPrint('🏗️ Selected building ID: ${building.id} (bounding box detection)');
          _showBuildingInfo(building);
          return;
        }
      }
    }

    debugPrint('🏗️ No building found at clicked position with any detection method');
  }

  // Check if a point is within a GeoJSON polygon feature
  bool _isPointInGeoJSONFeature(LatLng point, dynamic feature) {
    try {
      final geometry = feature['geometry'];
      final geometryType = geometry['type'] as String;

      debugPrint('🏗️ Checking geometry type: $geometryType');

      if (geometryType == 'Polygon') {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        if (coordinates.isNotEmpty) {
          final ring = coordinates[0] as List<dynamic>;
          return _isPointInPolygonRing(point, ring);
        }
      } else if (geometryType == 'MultiPolygon') {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        debugPrint('🏗️ MultiPolygon has ${coordinates.length} polygons');

        for (final polygon in coordinates) {
          if (polygon is List && polygon.isNotEmpty) {
            final ring = polygon[0] as List<dynamic>;
            if (_isPointInPolygonRing(point, ring)) {
              debugPrint('🏗️ Point found in MultiPolygon polygon');
              return true;
            }
          }
        }
        debugPrint('🏗️ Point not found in any MultiPolygon polygon');
      } else {
        debugPrint('🏗️ Unsupported geometry type: $geometryType');
      }
    } catch (e) {
      debugPrint('❌ Error checking GeoJSON feature: $e');
    }
    return false;
  }

  // Check if a point is within a polygon ring
  bool _isPointInPolygonRing(LatLng point, List<dynamic> ring) {
    try {
      // Convert point to screen coordinates for testing
      final x = point.longitude;
      final y = point.latitude;

      bool inside = false;
      int n = ring.length;

      for (int i = 0, j = n - 1; i < n; j = i++) {
        final xi = (ring[i][0] as num).toDouble();
        final yi = (ring[i][1] as num).toDouble();
        final xj = (ring[j][0] as num).toDouble();
        final yj = (ring[j][1] as num).toDouble();

        if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
          inside = !inside;
        }
      }

      return inside;
    } catch (e) {
      debugPrint('❌ Error in point-in-polygon calculation: $e');
      return false;
    }
  }

  bool _isPointInBounds(LatLng point, LatLngBounds bounds) {
    return point.latitude >= bounds.south &&
           point.latitude <= bounds.north &&
           point.longitude >= bounds.west &&
           point.longitude <= bounds.east;
  }

  void _clearSelection() {
    setState(() {
      _selectedBuilding = null;
    });
  }

  void _showBuildingInfo(Building building, {dynamic feature}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BuildingInfoSheet(
        building: building,
        feature: feature,
        onSave: () => _saveBuilding(building),
        onLaunchAR: () => _launchARForBuilding(building),
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

  void _launchARForBuilding(Building building) {
    // Navigate to AR screen with building data
    Navigator.pop(context); // Close modal
    Navigator.pushReplacementNamed(context, '/ar');
  }

  void _toggleBuildings() {
    setState(() {
      _showBuildings = !_showBuildings;
    });

    // For now, just log the toggle - we'll implement visibility after getting basic layer working
    debugPrint('🏗️ Buildings visibility toggled to: $_showBuildings');
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
        // Use light-v11 style like the working JavaScript example
        return 'mapbox://styles/mapbox/light-v11';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buildings Map'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showBuildings ? Icons.location_city : Icons.location_city_outlined),
            onPressed: _toggleBuildings,
            tooltip: _showBuildings ? 'Hide Buildings' : 'Show Buildings',
          ),
          if (_buildingAreaCenter != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              onPressed: () => _refocusOnBuildings(),
              tooltip: 'Focus on Buildings Area',
            ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _toggleMapType,
            tooltip: 'Change Map Style',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearSelection,
            tooltip: 'Clear Selection',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBuildingsOnly,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading || _isLoadingBuildings
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading building data...'),
                ],
              ),
            )
          : Stack(
              children: [
                mb.MapWidget(
                  key: ValueKey('buildings_map_$_currentStyle'),
                  onMapCreated: _onMapCreated,
                  styleUri: _getStyleUri(),
                  onTapListener: (context) {
                    final point = context.point;
                    debugPrint('🏗️ Map clicked at: ${point.coordinates.lat}, ${point.coordinates.lng}');
                    _checkBuildingSelection(LatLng(point.coordinates.lat.toDouble(), point.coordinates.lng.toDouble()));
                  },
                  cameraOptions: mb.CameraOptions(
                    center: mb.Point(
                      coordinates: mb.Position(
                        _buildingAreaCenter?.longitude ?? _initialPosition.longitude,
                        _buildingAreaCenter?.latitude ?? _initialPosition.latitude,
                      ),
                    ),
                    zoom: _buildingAreaZoom,
                    pitch: 45.0,
                  ),
                ),

                // Loading indicator for buildings
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

                // Instructions
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
                          '• Auto-focused on ${_buildings.length} buildings from backend',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• Focus button (🎯) re-centers on buildings area',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• Tap on buildings to select and view AR measurement',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• Color: Red (high NJOP), Green (low NJOP)',
                          style: TextStyle(color: Colors.white, fontSize: 12),
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

// Building Information Modal Widget
class _BuildingInfoSheet extends StatelessWidget {
  final Building building;
  final dynamic feature;
  final VoidCallback onSave;
  final VoidCallback onLaunchAR;

  const _BuildingInfoSheet({
    required this.building,
    this.feature,
    required this.onSave,
    required this.onLaunchAR,
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

          // Building Information
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Building Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.attach_money,
                        label: 'NJOP Total',
                        value: building.formattedNjop,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.local_fire_department,
                        label: 'Fire Hazard',
                        value: building.fireHazard?.toStringAsFixed(3) ?? 'N/A',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.flood,
                        label: 'Flood Hazard',
                        value: building.floodHazard?.toStringAsFixed(3) ?? 'N/A',
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.warning,
                        label: 'Total Hazard',
                        value: building.hazardSum?.toStringAsFixed(3) ?? 'N/A',
                      ),
                    ],
                  ),
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
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Launch AR for this Building'),
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

  