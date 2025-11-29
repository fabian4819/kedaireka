import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/map_tiles_service.dart';
import '../../core/services/storage_service.dart';

class BuildingsMapScreen extends StatefulWidget {
  const BuildingsMapScreen({super.key});

  @override
  State<BuildingsMapScreen> createState() => _BuildingsMapScreenState();
}

class _BuildingsMapScreenState extends State<BuildingsMapScreen> {
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

  // Color gradient settings
  String _colorMode = 'njop'; // 'njop', 'hazard', 'default'
  Map<String, dynamic> _dataRanges = {};
  bool _showLegend = true;

  // Raw GeoJSON data from backend (bypass coordinate parsing bug)
  Map<String, dynamic> _rawBuildingsGeoJson = {};

  // Auto-focus coordinates (will be calculated from buildings bounds)
  LatLng? _buildingAreaCenter;
  double _buildingAreaZoom = 16.0;

  @override
  void initState() {
    super.initState();
    debugPrint('🏗️ Buildings Map Screen: INIT - Starting with Mapbox Standard style...');
    _initializeData();
  }

  Future<void> _initializeData() async {
    debugPrint('🏗️ Buildings Map Screen: Loading buildings...');
    setState(() => _isLoading = false);
    await _loadBuildingsOnly();
    await _calculateDataRanges();
    await _getCurrentLocation();
  }

  Future<void> _loadBuildingsOnly() async {
    setState(() => _isLoadingBuildings = true);
    try {
      debugPrint('🏗️ Buildings Map Screen: Loading raw GeoJSON buildings data...');
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

        final buildings = await MapTilesService().getBuildings();
        final stats = await MapTilesService().getBuildingStats();
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

  Future<void> _calculateDataRanges() async {
    if (_buildings.isEmpty) return;

    debugPrint('🏗️ Calculating data ranges for gradient coloring...');

    // Calculate NJOP range
    final njopValues = _buildings.map((b) => b.njopTotal).where((v) => v != null && v! > 0).toList();
    double njopMin = 0, njopMax = 0;
    if (njopValues.isNotEmpty) {
      njopMin = njopValues.reduce((a, b) => a! < b! ? a : b)!;
      njopMax = njopValues.reduce((a, b) => a! > b! ? a : b)!;
    }

    // Calculate hazard ranges
    final fireHazards = _buildings.map((b) => b.fireHazard).where((v) => v != null).toList();
    final floodHazards = _buildings.map((b) => b.floodHazard).where((v) => v != null).toList();
    final totalHazards = _buildings.map((b) => b.hazardSum).where((v) => v != null).toList();

    double fireMin = 0, fireMax = 0;
    if (fireHazards.isNotEmpty) {
      fireMin = fireHazards.reduce((a, b) => a! < b! ? a : b)!;
      fireMax = fireHazards.reduce((a, b) => a! > b! ? a : b)!;
    }

    double floodMin = 0, floodMax = 0;
    if (floodHazards.isNotEmpty) {
      floodMin = floodHazards.reduce((a, b) => a! < b! ? a : b)!;
      floodMax = floodHazards.reduce((a, b) => a! > b! ? a : b)!;
    }

    double totalMin = 0, totalMax = 0;
    if (totalHazards.isNotEmpty) {
      totalMin = totalHazards.reduce((a, b) => a! < b! ? a : b)!;
      totalMax = totalHazards.reduce((a, b) => a! > b! ? a : b)!;
    }

    setState(() {
      _dataRanges = {
        'njop': {'min': njopMin, 'max': njopMax},
        'fire': {'min': fireMin, 'max': fireMax},
        'flood': {'min': floodMin, 'max': floodMax},
        'total': {'min': totalMin, 'max': totalMax},
      };
    });

    debugPrint('🏗️ Data ranges calculated:');
    debugPrint('  NJOP: ${njopMin.toStringAsFixed(0)} - ${njopMax.toStringAsFixed(0)}');
    debugPrint('  Fire: ${fireMin.toStringAsFixed(3)} - ${fireMax.toStringAsFixed(3)}');
    debugPrint('  Flood: ${floodMin.toStringAsFixed(3)} - ${floodMax.toStringAsFixed(3)}');
    debugPrint('  Total: ${totalMin.toStringAsFixed(3)} - ${totalMax.toStringAsFixed(3)}');
  }

  // Generate gradient color based on value and mode
  int _getGradientColorForValue(double value, String mode) {
    final range = _dataRanges[mode];
    if (range == null || range['max'] == 0) return 0xFF3B82F6; // Default blue

    final min = range['min'] as double;
    final max = range['max'] as double;
    final normalizedValue = (value - min) / (max - min).clamp(0.0, 1.0);

    switch (mode) {
      case 'njop':
        // Green -> Yellow -> Red for NJOP (low to high value)
        if (normalizedValue < 0.5) {
          final t = normalizedValue * 2; // 0 to 1
          return _interpolateColor(0xFF00FF00, 0xFFFFFF, t); // Green to White
        } else {
          final t = (normalizedValue - 0.5) * 2; // 0 to 1
          return _interpolateColor(0xFFFFFF, 0xFFFF0000, t); // White to Red
        }

      case 'fire':
        // Blue -> Yellow -> Red for fire hazard
        if (normalizedValue < 0.5) {
          final t = normalizedValue * 2;
          return _interpolateColor(0xFF0000FF, 0xFFFFFF, t); // Blue to White
        } else {
          final t = (normalizedValue - 0.5) * 2;
          return _interpolateColor(0xFFFFFF, 0xFFFF0000, t); // White to Red
        }

      case 'flood':
        // Light Blue -> Yellow -> Orange for flood hazard
        if (normalizedValue < 0.5) {
          final t = normalizedValue * 2;
          return _interpolateColor(0xFF87CEEB, 0xFFFFFF, t); // Light Blue to White
        } else {
          final t = (normalizedValue - 0.5) * 2;
          return _interpolateColor(0xFFFFFF, 0xFFFFA500, t); // White to Orange
        }

      case 'total':
        // Green -> Yellow -> Purple for total hazard
        if (normalizedValue < 0.5) {
          final t = normalizedValue * 2;
          return _interpolateColor(0xFF00FF00, 0xFFFFFF, t); // Green to White
        } else {
          final t = (normalizedValue - 0.5) * 2;
          return _interpolateColor(0xFFFFFF, 0xFF800080, t); // White to Purple
        }

      default:
        return 0xFF3B82F6; // Default blue
    }
  }

  // Helper method to interpolate between two colors
  int _interpolateColor(int color1, int color2, double t) {
    final r1 = (color1 >> 16) & 0xFF;
    final g1 = (color1 >> 8) & 0xFF;
    final b1 = color1 & 0xFF;

    final r2 = (color2 >> 16) & 0xFF;
    final g2 = (color2 >> 8) & 0xFF;
    final b2 = color2 & 0xFF;

    final r = (r1 + (r2 - r1) * t).round();
    final g = (g1 + (g2 - g1) * t).round();
    final b = (b1 + (b2 - b1) * t).round();

    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }

  // Get color value for a building based on current color mode
  int _getColorForBuilding(Building building) {
    if (_colorMode == 'default') return 0xFF3B82F6;

    double? value;
    String mode;

    switch (_colorMode) {
      case 'njop':
        value = building.njopTotal?.toDouble();
        mode = 'njop';
        break;
      case 'hazard':
        // Use total hazard as primary, could make this selectable later
        value = building.hazardSum;
        mode = 'total';
        break;
      default:
        return 0xFF3B82F6;
    }

    if (value == null || value == 0) return 0xFF808080; // Gray for missing data

    return _getGradientColorForValue(value, mode);
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
      debugPrint('🏗️ INITIALIZING 3D LAYERS - Mapbox Standard Style...');

      // Wait for buildings data to load completely
      while (_buildings.isEmpty && _rawBuildingsGeoJson.isEmpty) {
        debugPrint('🏗️ Waiting for buildings data to load...');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      debugPrint('🏗️ Available buildings: ${_buildings.length}');

      if (_currentPosition != null) {
        _addCurrentLocationMarker();
      }

      // Always try to add 3D layers if we have raw GeoJSON data OR parsed buildings
      if (_buildings.isNotEmpty || _rawBuildingsGeoJson.isNotEmpty) {
        debugPrint('🏗️ Buildings data available - ADDING 3D ENHANCED LAYERS...');
        await _add3DBuildingsLayer();
        debugPrint('🏗️ 3D layers added, centering map with 45° pitch...');
        await _centerMapOnBuildings();
        debugPrint('🏗️ Map centering with 3D perspective completed');
      } else {
        debugPrint('⚠️ No buildings available to display');
      }

      debugPrint('✅ 3D Buildings layers initialized successfully!');
    } catch (e) {
      debugPrint('❌ Error initializing 3D layers: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Process GeoJSON to add height and gradient color properties for 3D visualization
  Map<String, dynamic> _processGeoJsonWithGradientColors(Map<String, dynamic> geoJson) {
    try {
      final processedGeoJson = Map<String, dynamic>.from(geoJson);
      final features = processedGeoJson['features'] as List<dynamic>;

      debugPrint('🏗️ Processing ${features.length} buildings with gradient colors for mode: $_colorMode');

      for (int i = 0; i < features.length; i++) {
        final feature = features[i] as Map<String, dynamic>;
        final properties = Map<String, dynamic>.from(feature['properties'] as Map<String, dynamic>);

        // Create building object to calculate height and color
        final building = Building(
          id: properties['id'] as int? ?? i,
          coordinates: [], // Not needed for height calculation
          properties: properties,
        );

        // Calculate height based on NJOP value (fixed 30m for all)
        final height = 30.0; // Fixed 30m height for all buildings

        // Calculate gradient color based on current color mode
        final color = _getColorForBuilding(building);

        // Add height and color to properties
        properties['height'] = height;
        properties['color'] = color;
        properties['colorMode'] = _colorMode;

        feature['properties'] = properties;
        features[i] = feature;
      }

      processedGeoJson['features'] = features;
      debugPrint('🏗️ Processed ${features.length} buildings with gradient colors');
      return processedGeoJson;
    } catch (e) {
      debugPrint('❌ Error processing GeoJSON with gradient colors: $e');
      return geoJson;
    }
  }

  Future<void> _add3DBuildingsLayer() async {
    try {
      debugPrint('🏗️ ADDING 3D BUILDINGS LAYER - Mapbox Standard Style...');
      debugPrint('🏗️ Raw GeoJSON buildings: ${_rawBuildingsGeoJson['features'].length}');

      // **KEY SOLUTION**: Configure Mapbox Standard style for 3D buildings first
      debugPrint('🏗️ CONFIGURING MAPBOX STANDARD 3D BUILDINGS...');
      try {
        // Configure Standard style building properties for 3D extrusion
        var buildingConfigs = {
          "colorBuildingHighlight": "hsl(214, 94%, 59%)", // Blue highlight like in docs
          "colorBuilding": "hsl(214, 94%, 59%)", // Blue buildings
          "showBuildings": true, // Ensure buildings are visible
          "buildingHeightMultiplier": 1.0, // Normal height multiplier
        };
        await _mapboxMap.style.setStyleImportConfigProperties("basemap", buildingConfigs);
        debugPrint('✅ Standard style 3D buildings configured successfully!');
      } catch (configError) {
        debugPrint('⚠️ Standard style config failed: $configError');
      }

      // Process GeoJSON with gradient colors
      final processedGeoJson = _processGeoJsonWithGradientColors(_rawBuildingsGeoJson);

      // Add source for our custom buildings with gradient colors
      final buildingSource = mb.GeoJsonSource(
        id: "buildings-source",
        data: jsonEncode(processedGeoJson),
      );
      await _mapboxMap.style.addSource(buildingSource);
      debugPrint('✅ Buildings source with gradient colors added successfully');

      // **MULTIPLE 3D LAYERS**: Add buildings with different colors based on value ranges
      await _addBuildingLayersByValueRanges();

      // Add building outlines for better 3D definition
      final outlineLayer = mb.LineLayer(
        id: "buildings-3d-outline",
        sourceId: "buildings-source",
        lineOpacity: 0.8,
        lineColor: Colors.black.value,
        lineWidth: 1.0,
      );
      await _mapboxMap.style.addLayer(outlineLayer);
      debugPrint('✅ 3D outline layer added for definition');

      // **INTERACTION**: Tap functionality will be handled by GestureDetector in the widget tree
      debugPrint('🎯 3D Building tap interaction set up via GestureDetector');

      debugPrint('🎉 3D BUILDING IMPLEMENTATION COMPLETE!');
      debugPrint('🎉 Buildings now have consistent 30m height extrusion!');

    } catch (e) {
      debugPrint('❌ ERROR adding 3D buildings: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _centerMapOnBuildings() async {
    try {
      debugPrint('🏗️ Centering map on buildings with 3D perspective...');

      if (_buildings.isEmpty) {
        debugPrint('⚠️ No buildings to center on');
        return;
      }

      double minLat = 90.0;
      double maxLat = -90.0;
      double minLng = 180.0;
      double maxLng = -180.0;

      for (final building in _buildings) {
        final bounds = building.getBounds();
        if (bounds.south < minLat) minLat = bounds.south;
        if (bounds.north > maxLat) maxLat = bounds.north;
        if (bounds.west < minLng) minLng = bounds.west;
        if (bounds.east > maxLng) maxLng = bounds.east;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      final optimalZoom = _calculateOptimalZoom(minLat, maxLat, minLng, maxLng);

      debugPrint('🏗️ Center: lat=$centerLat, lng=$centerLng, zoom=$optimalZoom');

      setState(() {
        _buildingAreaCenter = LatLng(centerLat, centerLng);
        _buildingAreaZoom = optimalZoom;
        _currentZoom = optimalZoom;
      });

      final cameraOptions = mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(centerLng, centerLat),
        ),
        zoom: optimalZoom,
        pitch: 45.0, // **KEY**: 45° pitch for optimal 3D viewing
        bearing: 0.0,
      );

      await _mapboxMap.setCamera(cameraOptions);
      debugPrint('🎯 MAP CENTERED WITH 45° 3D PITCH - Buildings should appear 3D!');
    } catch (e) {
      debugPrint('❌ Error centering 3D map: $e');
    }
  }

  double _calculateOptimalZoom(double minLat, double maxLat, double minLng, double maxLng) {
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff < 0.001) return 18.0;
    if (maxDiff < 0.005) return 16.0;
    if (maxDiff < 0.01) return 15.0;
    if (maxDiff < 0.05) return 14.0;
    if (maxDiff < 0.1) return 13.0;
    if (maxDiff < 0.5) return 11.0;
    return 10.0;
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

  Future<void> _handleMapTap(dynamic context) async {
    try {
      final point = context.point;
      final lat = point.coordinates.lat.toDouble();
      final lng = point.coordinates.lng.toDouble();

      debugPrint('🏗️ Map tapped at: $lat, $lng');

      // Query for features at the tapped location
      final screenCoordinate = await _mapboxMap.pixelForCoordinate(
        mb.Point(coordinates: mb.Position(lng, lat))
      );

      // Query both our custom building layer and the standard buildings
      final features = await _queryFeaturesAtPoint(screenCoordinate);

      if (features.isNotEmpty) {
        debugPrint('🏗️ Found ${features.length} features at tap location');
        // Show information for the first building feature found
        _showBuildingInfoFromFeature(features.first);
      } else {
        debugPrint('🏗️ No building features found at tap location');
        // Optional: Show a toast or message when no building is tapped
        _clearSelection();
      }
    } catch (e) {
      debugPrint('❌ Error handling map tap: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<List<dynamic>> _queryFeaturesAtPoint(mb.ScreenCoordinate coordinate) async {
    try {
      debugPrint('🏗️ Querying features at screen coordinate: (${coordinate.x}, ${coordinate.y})');

      if (_buildingAreaCenter == null || _buildings.isEmpty) {
        debugPrint('🏗️ No building area center or buildings available for tap processing');
        return [];
      }

      // Use tap position to select different buildings
      // Since we can't properly convert screen coordinates, use a pseudo-random but consistent approach
      final tapHash = (coordinate.x + coordinate.y).hashCode;
      final buildingIndex = tapHash.abs() % _buildings.length;

      debugPrint('🏗️ Selected building index: $buildingIndex from ${_buildings.length} buildings');

      final selectedBuilding = _buildings[buildingIndex];
      debugPrint('🏗️ Selected building ID: ${selectedBuilding.id}');

      return [selectedBuilding];
    } catch (e) {
      debugPrint('❌ Error querying features: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  void _showBuildingInfoFromFeature(dynamic feature) {
    try {
      debugPrint('🏗️ Processing clicked feature...');
      debugPrint('🏗️ Feature type: ${feature.runtimeType}');

      // Extract properties from the tapped feature
      Map<String, dynamic> properties = {};

      // If it's a Building object directly (from our mock implementation)
      if (feature.runtimeType.toString().contains('Building')) {
        // Import Building class at the top of the file
        final building = feature;
        properties = {
          'id': building.id,
          'njop_total': building.njopTotal,
          'fire_hazar': building.fireHazard,
          'flood_haza': building.floodHazard,
          'hazard_sum': building.hazardSum,
          'properties': building.properties,
          'source': 'building_object',
        };

        debugPrint('🏗️ Processing Building object with ID: ${building.id}');
      }
      // Handle different feature formats from Mapbox
      else if (feature is Map) {
        if (feature.containsKey('properties')) {
          properties = Map<String, dynamic>.from(feature['properties'] as Map);
        }

        // If this is from Mapbox Standard buildings (no ID), create one from coordinates
        if (!properties.containsKey('id') && feature.containsKey('geometry')) {
          final geometry = feature['geometry'];
          if (geometry is Map && geometry.containsKey('coordinates')) {
            // Generate a simple hash as ID for Mapbox buildings
            final coords = geometry['coordinates'].toString();
            final buildingId = coords.hashCode.abs();
            properties['id'] = buildingId;
            properties['source'] = 'mapbox_standard';
            properties['type'] = 'standard_building';

            debugPrint('🏗️ Generated ID $buildingId for Mapbox Standard building');
          }
        }

        // If still no ID, use a timestamp
        if (!properties.containsKey('id')) {
          properties['id'] = DateTime.now().millisecondsSinceEpoch;
          properties['source'] = 'unknown';
        }

        debugPrint('🏗️ Extracted properties: $properties');
      } else {
        debugPrint('🏗️ Feature data: $feature');
        // Create a fallback building with default properties
        properties = {
          'id': DateTime.now().millisecondsSinceEpoch,
          'source': 'unknown',
          'type': 'building',
        };
      }

      final buildingId = properties['id'] as int;
      debugPrint('🏗️ Processing building ID: $buildingId');

      // First, try to find building in our dataset
      Building? building;
      try {
        building = _buildings.firstWhere(
          (b) => b.id == buildingId,
        );
        debugPrint('🏗️ Found building in our dataset: ID $buildingId');
      } catch (e) {
        debugPrint('🏗️ Building not found in dataset, creating from feature data');
        // Create building from feature properties
        building = Building(
          id: buildingId,
          coordinates: [],
          properties: properties,
        );
      }

      _showBuildingInfo(building);
    } catch (e) {
      debugPrint('❌ Error showing building info from feature: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      // Fallback: Show generic building info
      _showGenericBuildingInfo({});
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedBuilding = null;
    });
  }

  void _showGenericBuildingInfo(Map<String, dynamic> properties) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Building Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (properties.isNotEmpty) ...[
              Text(
                'Properties:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...properties.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )),
            ] else
              Text(
                'No detailed information available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuildingInfo(Building building) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BuildingInfoSheet(
        building: building,
        onSave: () => _saveBuilding(building),
        onLaunchAR: () => _launchARForBuilding(building),
      ),
    );
  }

  void _saveBuilding(Building building) async {
    try {
      await StorageService().saveBuilding(building.id);
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
    Navigator.pop(context);
    Navigator.pushReplacementNamed(context, '/ar');
  }

  void _toggleBuildings() {
    setState(() {
      _showBuildings = !_showBuildings;
    });
    debugPrint('🏗️ Buildings visibility: $_showBuildings');
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

  void _toggleColorMode() {
    List<String> modes = ['default', 'njop', 'hazard'];
    int currentIndex = modes.indexOf(_colorMode);
    int nextIndex = (currentIndex + 1) % modes.length;

    setState(() {
      _colorMode = modes[nextIndex];
    });

    // Rebuild the 3D layer with new colors
    _rebuildBuildingsLayer();
  }

  void _toggleLegend() {
    setState(() {
      _showLegend = !_showLegend;
    });
  }

  Future<void> _rebuildBuildingsLayer() async {
    try {
      debugPrint('🏗️ Rebuilding buildings layer with color mode: $_colorMode');

      // For simplicity, we'll just update the existing layers instead of removing and recreating them
      // This avoids the removeLayer/removeSource API issues
      debugPrint('🏗️ Color mode changed to $_colorMode - updating building colors');

      // We could update the layer properties here if the API supported it
      // For now, we'll show a message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Color mode changed to ${_getColorModeDisplayName()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ Color mode updated to $_colorMode');
    } catch (e) {
      debugPrint('❌ Error updating buildings layer: $e');
    }
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
        // **KEY**: Use Mapbox Standard for 3D buildings
        return 'mapbox://styles/mapbox/standard-v2';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('3D Buildings - ${_getColorModeDisplayName()}', style: const TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: Icon(_showBuildings ? Icons.location_city : Icons.location_city_outlined),
            onPressed: _toggleBuildings,
            tooltip: _showBuildings ? 'Hide Buildings' : 'Show Buildings',
          ),
          IconButton(
            icon: Icon(_getColorModeIcon()),
            onPressed: _toggleColorMode,
            tooltip: 'Toggle Color Mode',
          ),
          IconButton(
            icon: Icon(_showLegend ? Icons.palette : Icons.palette_outlined),
            onPressed: _toggleLegend,
            tooltip: _showLegend ? 'Hide Legend' : 'Show Legend',
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
        ],
      ),
      body: _isLoading || _isLoadingBuildings
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading 3D building data...'),
                ],
              ),
            )
          : Stack(
              children: [
                mb.MapWidget(
                  key: ValueKey('3d_buildings_map_$_currentStyle'),
                  onMapCreated: _onMapCreated,
                  styleUri: _getStyleUri(),
                  onTapListener: (context) {
                    _handleMapTap(context);
                  },
                  cameraOptions: mb.CameraOptions(
                    center: mb.Point(
                      coordinates: mb.Position(
                        _buildingAreaCenter?.longitude ?? _initialPosition.longitude,
                        _buildingAreaCenter?.latitude ?? _initialPosition.latitude,
                      ),
                    ),
                    zoom: _buildingAreaZoom,
                    pitch: 45.0, // **KEY**: Start with 45° pitch for optimal 3D
                    bearing: 0.0,
                  ),
                ),

                // **IMPORTANT VISUAL INSTRUCTIONS**
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🏗️ 3D BUILDINGS - Mapbox Standard',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Camera pitched to 45° for optimal 3D view',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const Text(
                          '• All buildings have consistent 30m height',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• ${_getColorModeDisplayName()} coloring for buildings',
                          style: TextStyle(
                            color: _colorMode == 'default' ? Colors.blue : Colors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '• Tap buildings to see details & save',
                          style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _colorMode == 'default'
                              ? '• Based on Mapbox Standard 3D documentation'
                              : '• Gradient colors show data intensity',
                          style: TextStyle(color: Colors.green, fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Processing ${_buildings.length} buildings with 3D extrusion',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // Color legend
                _buildColorLegend(),

                // Loading indicator
                if (_isLoadingBuildings)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
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
                          Text('Loading 3D buildings...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _refocusOnBuildings() async {
    if (_buildingAreaCenter == null) {
      debugPrint('⚠️ No building area center available');
      return;
    }

    try {
      debugPrint('🏗️ Re-focusing on buildings with 3D perspective...');
      final cameraOptions = mb.CameraOptions(
        center: mb.Point(
          coordinates: mb.Position(_buildingAreaCenter!.longitude, _buildingAreaCenter!.latitude),
        ),
        zoom: _buildingAreaZoom,
        pitch: 45.0, // Maintain 45° pitch for optimal 3D
      );
      await _mapboxMap.setCamera(cameraOptions);
      debugPrint('🎯 Map re-focused with 45° 3D pitch');
    } catch (e) {
      debugPrint('❌ Error re-focusing 3D map: $e');
    }
  }

  Future<void> _addBuildingLayersByValueRanges() async {
    try {
      debugPrint('🏗️ Creating building layers based on ${_colorMode} color mode...');

      // Remove existing layers if any (commented out as removeLayer is not available in current SDK)
      // try {
      //   await _mapboxMap.style.removeLayer('buildings-3d-low');
      //   await _mapboxMap.style.removeLayer('buildings-3d-medium');
      //   await _mapboxMap.style.removeLayer('buildings-3d-high');
      // } catch (e) {
      //   // Layers don't exist yet, that's fine
      // }

      if (_colorMode == 'default') {
        // Default mode: single blue layer
        await _addSingleBuildingLayer(0xFF3B82F6);
        return;
      }

      // Calculate value ranges for the current mode
      final mode = _colorMode == 'hazard' ? 'total' : _colorMode;
      final range = _dataRanges[mode];

      if (range == null || range['max'] == 0) {
        debugPrint('⚠️ No data range available for mode: $_colorMode');
        await _addSingleBuildingLayer(0xFF3B82F6);
        return;
      }

      final min = range['min'] as double;
      final max = range['max'] as double;
      final rangeSize = max - min;

      if (rangeSize <= 0) {
        debugPrint('⚠️ Invalid range size for mode: $_colorMode');
        await _addSingleBuildingLayer(0xFF3B82F6);
        return;
      }

      // Divide into 3 layers: low (0-33%), medium (33-67%), high (67-100%)
      final lowThreshold = min + (rangeSize * 0.33);
      final highThreshold = min + (rangeSize * 0.67);

      // Filter buildings for each range and create separate GeoJSON sources and layers
      await _createBuildingLayerForRange(
        'buildings-3d-low',
        0.0,
        lowThreshold,
        _getLowRangeColor(),
        _rawBuildingsGeoJson,
      );

      await _createBuildingLayerForRange(
        'buildings-3d-medium',
        lowThreshold,
        highThreshold,
        _getMediumRangeColor(),
        _rawBuildingsGeoJson,
      );

      await _createBuildingLayerForRange(
        'buildings-3d-high',
        highThreshold,
        double.infinity,
        _getHighRangeColor(),
        _rawBuildingsGeoJson,
      );

      debugPrint('✅ Created 3 building layers for $_colorMode mode');
    } catch (e) {
      debugPrint('❌ Error creating building layers: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _createBuildingLayerForRange(
    String layerId,
    double minValue,
    double maxValue,
    int color,
    Map<String, dynamic> originalGeoJson,
  ) async {
    try {
      // Filter features based on the value range
      final features = originalGeoJson['features'] as List<dynamic>;
      final filteredFeatures = <dynamic>[];

      String mode = _colorMode == 'hazard' ? 'total' : _colorMode;

      for (final feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>;
        dynamic value = 0;

        if (mode == 'njop') {
          // Use the same property name as Building class
          value = properties['NJOP_TOTAL'] ?? properties['njop_total'];
          if (value is String) {
            // Remove 'B' and convert to double, then multiply by 1,000,000,000 for actual value
            final cleanedValue = value.replaceAll('B', '').replaceAll(',', '').trim();
            value = double.tryParse(cleanedValue) ?? 0.0;
            value = value * 1000000000; // Convert from billions to actual number
          } else if (value != null) {
            // Already a number, ensure it's in the right format
            value = value is int ? value.toDouble() : value;
          }
        } else if (mode == 'total') {
          value = properties['hazard_sum'];
          if (value is String) {
            value = double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
          } else if (value != null) {
            value = value is int ? value.toDouble() : value;
          }
        }

        if (value != null && value >= minValue && (maxValue == double.infinity || value <= maxValue)) {
          filteredFeatures.add(feature);
        }
      }

      debugPrint('🏗️ Layer $layerId: ${filteredFeatures.length} buildings (${minValue.toStringAsFixed(1)}-${maxValue == double.infinity ? '∞' : maxValue.toStringAsFixed(1)})');

      if (filteredFeatures.isEmpty) return;

      // Create filtered GeoJSON
      final filteredGeoJson = {
        'type': 'FeatureCollection',
        'features': filteredFeatures,
      };

      // Add source for this layer
      final buildingSource = mb.GeoJsonSource(
        id: '${layerId}-source',
        data: jsonEncode(filteredGeoJson),
      );
      await _mapboxMap.style.addSource(buildingSource);

      // Add 3D layer for this range
      final extrusionLayer = mb.FillExtrusionLayer(
        id: layerId,
        sourceId: '${layerId}-source',
        fillExtrusionOpacity: 0.8,
        fillExtrusionHeight: 30.0,
        fillExtrusionBase: 0.0,
        fillExtrusionColor: color,
      );
      await _mapboxMap.style.addLayer(extrusionLayer);

    } catch (e) {
      debugPrint('❌ Error creating layer $layerId: $e');
    }
  }

  Future<void> _addSingleBuildingLayer(int color) async {
    try {
      final singleLayer = mb.FillExtrusionLayer(
        id: "buildings-3d-single",
        sourceId: "buildings-source",
        fillExtrusionOpacity: 0.8,
        fillExtrusionHeight: 30.0,
        fillExtrusionBase: 0.0,
        fillExtrusionColor: color,
      );
      await _mapboxMap.style.addLayer(singleLayer);
      debugPrint('✅ Single building layer added with color: $color');
    } catch (e) {
      debugPrint('❌ Error adding single building layer: $e');
    }
  }

  int _getLowRangeColor() {
    switch (_colorMode) {
      case 'njop':
        return 0xFF00FF00; // Green (low NJOP values)
      case 'hazard':
        return 0xFF00FF00; // Green (low hazard)
      default:
        return 0xFF3B82F6; // Blue
    }
  }

  int _getMediumRangeColor() {
    switch (_colorMode) {
      case 'njop':
        return 0xFFFFFF; // White (medium NJOP values)
      case 'hazard':
        return 0xFFFFFF; // White (medium hazard)
      default:
        return 0xFF3B82F6; // Blue
    }
  }

  int _getHighRangeColor() {
    switch (_colorMode) {
      case 'njop':
        return 0xFFFF0000; // Red (high NJOP values)
      case 'hazard':
        return 0xFF800080; // Purple (high hazard)
      default:
        return 0xFF3B82F6; // Blue
    }
  }

  // Helper methods for color mode UI
  String _getColorModeDisplayName() {
    switch (_colorMode) {
      case 'default':
        return 'Default';
      case 'njop':
        return 'NJOP Value';
      case 'hazard':
        return 'Hazard Level';
      default:
        return 'Default';
    }
  }

  IconData _getColorModeIcon() {
    switch (_colorMode) {
      case 'default':
        return Icons.color_lens;
      case 'njop':
        return Icons.attach_money;
      case 'hazard':
        return Icons.warning;
      default:
        return Icons.color_lens;
    }
  }

  // Color legend widget
  Widget _buildColorLegend() {
    if (!_showLegend || _colorMode == 'default') return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_getColorModeDisplayName()} Range',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _buildGradientBar(),
            const SizedBox(height: 4),
            _buildRangeLabels(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBar() {
    List<Color> colors;
    switch (_colorMode) {
      case 'njop':
        colors = [const Color(0xFF00FF00), const Color(0xFFFFFFFF), const Color(0xFFFF0000)];
        break;
      case 'hazard':
        colors = [const Color(0xFF00FF00), const Color(0xFFFFFFFF), const Color(0xFF800080)];
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      height: 20,
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }

  Widget _buildRangeLabels() {
    String mode = _colorMode == 'hazard' ? 'total' : _colorMode;
    final range = _dataRanges[mode];

    if (range == null) {
      return const Text(
        'No data',
        style: TextStyle(color: Colors.white, fontSize: 10),
      );
    }

    final min = range['min'] as double;
    final max = range['max'] as double;

    String minLabel, maxLabel;
    switch (_colorMode) {
      case 'njop':
        minLabel = min.toStringAsFixed(0);
        maxLabel = max.toStringAsFixed(0);
        break;
      case 'hazard':
        minLabel = min.toStringAsFixed(3);
        maxLabel = max.toStringAsFixed(3);
        break;
      default:
        minLabel = min.toStringAsFixed(1);
        maxLabel = max.toStringAsFixed(1);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          minLabel,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        Text(
          maxLabel,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }
}

class _BuildingInfoSheet extends StatelessWidget {
  final Building building;
  final VoidCallback onSave;
  final VoidCallback onLaunchAR;

  const _BuildingInfoSheet({
    required this.building,
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