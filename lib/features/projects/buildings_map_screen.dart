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
  String _currentStyle = 'satellite';
  double _currentZoom = _initialZoom;

  // Buildings from backend
  List<Building> _buildings = [];
  BuildingStats? _buildingStats;
  List<Building> _savedBuildings = [];
  Building? _selectedBuilding;
  bool _showBuildings = true;

  // Color gradient settings
  String _colorMode = 'default'; // 'njop', 'hazard', 'default'
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

      debugPrint('🏗️ Fetching from: $_baseUrl/buildings');
      
      // Load buildings data only
      final buildingsResponse = await http.get(
        Uri.parse('$_baseUrl/buildings'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('🏗️ Buildings response status: ${buildingsResponse.statusCode}');

      if (buildingsResponse.statusCode == 200) {
        debugPrint('🏗️ Parsing JSON response...');
        final rawGeoJson = jsonDecode(buildingsResponse.body);

        debugPrint('🏗️ Raw GeoJSON parsed, features count: ${rawGeoJson['features']?.length ?? 0}');

        setState(() {
          _rawBuildingsGeoJson = rawGeoJson;
          _isLoadingBuildings = false;
        });
        debugPrint('🏗️ Buildings Map Screen: Loaded raw GeoJSON with ${rawGeoJson['features'].length} buildings');

        // Load processed buildings for compatibility
        debugPrint('🏗️ Loading processed buildings via MapTilesService...');
        final buildings = await MapTilesService().getBuildings();
        debugPrint('🏗️ Loaded ${buildings.length} processed buildings');
        _buildings = buildings;

        // Calculate ranges from building data
        await _calculateDataRanges();

      } else {
        debugPrint('❌ Failed to load buildings: ${buildingsResponse.statusCode}');
        throw Exception('Failed to load buildings data: ${buildingsResponse.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading buildings: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() => _isLoadingBuildings = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading buildings: $e')),
        );
      }
    }
  }




  // Parse stats data and update ranges
  Future<void> _parseAndUpdateStatsData(Map<String, dynamic> statsData) async {
    try {
      debugPrint('🏗️ Parsing stats data...');

      // Parse the stats ranges from API response
      final floodHazardMin = (statsData['flood_hazard_min'] as num?)?.toDouble() ?? 0.0;
      final floodHazardMax = (statsData['flood_hazard_max'] as num?)?.toDouble() ?? 1.0;

      final fireHazardMin = (statsData['fire_hazard_min'] as num?)?.toDouble() ?? 0.0;
      final fireHazardMax = (statsData['fire_hazard_max'] as num?)?.toDouble() ?? 1.0;

      final hazardSumMin = (statsData['hazard_sum_min'] as num?)?.toDouble() ?? 0.0;
      final hazardSumMax = (statsData['hazard_sum_max'] as num?)?.toDouble() ?? 1.0;

      final njopTotalMin = _parseNjopValue(statsData['njop_total_min']);
      final njopTotalMax = _parseNjopValue(statsData['njop_total_max']);

      setState(() {
        _dataRanges = {
          'flood': {'min': floodHazardMin, 'max': floodHazardMax},
          'fire': {'min': fireHazardMin, 'max': fireHazardMax},
          'total': {'min': hazardSumMin, 'max': hazardSumMax},
          'njop': {'min': njopTotalMin, 'max': njopTotalMax},
        };
      });

      debugPrint('🏗️ Updated data ranges:');
      debugPrint('  Flood: $floodHazardMin - $floodHazardMax');
      debugPrint('  Fire: $fireHazardMin - $fireHazardMax');
      debugPrint('  Total: $hazardSumMin - $hazardSumMax');
      debugPrint('  NJOP: $njopTotalMin - $njopTotalMax');

    } catch (e) {
      debugPrint('❌ Error parsing stats data: $e');
      // Fallback to calculated ranges
      await _calculateDataRanges();
    }
  }

  // Parse NJOP values that may be in string format like "1.5M" or "2.1T"
  double _parseNjopValue(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final upperValue = value.toUpperCase().trim();

      if (upperValue.endsWith('K')) {
        final numValue = double.tryParse(upperValue.replaceAll('K', '').trim()) ?? 0.0;
        return numValue * 1000;
      } else if (upperValue.endsWith('M')) {
        final numValue = double.tryParse(upperValue.replaceAll('M', '').trim()) ?? 0.0;
        return numValue * 1000000;
      } else if (upperValue.endsWith('B')) {
        final numValue = double.tryParse(upperValue.replaceAll('B', '').trim()) ?? 0.0;
        return numValue * 1000000000;
      } else if (upperValue.endsWith('T')) {
        final numValue = double.tryParse(upperValue.replaceAll('T', '').trim()) ?? 0.0;
        return numValue * 1000000000000;
      } else {
        return double.tryParse(upperValue) ?? 0.0;
      }
    }

    return 0.0;
  }

  // Backup method to calculate data ranges from building data if API stats fails
  Future<void> _calculateDataRanges() async {
    if (_buildings.isEmpty) {
      debugPrint('🏗️ No buildings available for range calculation');
      return;
    }

    debugPrint('🏗️ Calculating data ranges from building data (fallback)...');

    // Calculate NJOP range
    final njopValues = _buildings.map((b) => b.njopTotal).where((v) => v != null && v! > 0).toList();
    double njopMin = 0, njopMax = 0;
    if (njopValues.isNotEmpty) {
      njopMin = njopValues.reduce((a, b) => a! < b! ? a : b)!;
      njopMax = njopValues.reduce((a, b) => a! > b! ? a : b)!;
    } else {
      // Default range if no NJOP data found
      njopMin = 1500000; // 1.5M
      njopMax = 2100000000000; // 2.1T
    }

    // Calculate hazard ranges
    final fireHazards = _buildings.map((b) => b.fireHazard).where((v) => v != null).toList();
    final floodHazards = _buildings.map((b) => b.floodHazard).where((v) => v != null).toList();
    final totalHazards = _buildings.map((b) => b.hazardSum).where((v) => v != null).toList();

    double fireMin = 0, fireMax = 0;
    if (fireHazards.isNotEmpty) {
      fireMin = fireHazards.reduce((a, b) => a! < b! ? a : b)!;
      fireMax = fireHazards.reduce((a, b) => a! > b! ? a : b)!;
    } else {
      fireMin = 0.24915;
      fireMax = 0.39737;
    }

    double floodMin = 0, floodMax = 0;
    if (floodHazards.isNotEmpty) {
      floodMin = floodHazards.reduce((a, b) => a! < b! ? a : b)!;
      floodMax = floodHazards.reduce((a, b) => a! > b! ? a : b)!;
    } else {
      floodMin = 0.0;
      floodMax = 0.13899;
    }

    double totalMin = 0, totalMax = 0;
    if (totalHazards.isNotEmpty) {
      totalMin = totalHazards.reduce((a, b) => a! < b! ? a : b)!;
      totalMax = totalHazards.reduce((a, b) => a! > b! ? a : b)!;
    } else {
      totalMin = 0.25;
      totalMax = 0.51;
    }

    setState(() {
      _dataRanges = {
        'njop': {'min': njopMin, 'max': njopMax},
        'fire': {'min': fireMin, 'max': fireMax},
        'flood': {'min': floodMin, 'max': floodMax},
        'total': {'min': totalMin, 'max': totalMax},
      };
    });

    debugPrint('🏗️ Data ranges calculated (fallback):');
    debugPrint('  NJOP: ${njopMin.toStringAsFixed(0)} - ${njopMax.toStringAsFixed(0)}');
    debugPrint('  Fire: ${fireMin.toStringAsFixed(3)} - ${fireMax.toStringAsFixed(3)}');
    debugPrint('  Flood: ${floodMin.toStringAsFixed(3)} - ${floodMax.toStringAsFixed(3)}');
    debugPrint('  Total: ${totalMin.toStringAsFixed(3)} - ${totalMax.toStringAsFixed(3)}');
  }

  // Generate solid color based on value and mode (no gradients)
  int _getSolidColorForValue(double value, String mode) {
    final range = _dataRanges[mode];
    if (range == null || range['max'] == 0) return 0xFF3B82F6; // Default blue

    final min = range['min'] as double;
    final max = range['max'] as double;
    // Handle zero values properly - they should be treated as minimum
    final adjustedValue = value == 0 ? min : value;
    final normalizedValue = (adjustedValue - min) / (max - min).clamp(0.0001, 1.0);

    switch (mode) {
      case 'njop':
        // Solid colors for NJOP: Green (low) -> Yellow (medium) -> Red (high)
        // Use absolute thresholds, not normalized
        if (value < 100000000) { // < 100M
          return 0xFF00FF00; // Solid Green for low NJOP
        } else if (value < 1000000000) { // 100M - 1B
          return 0xFFFFFF00; // Solid Yellow for medium NJOP
        } else { // > 1B
          return 0xFFFF0000; // Solid Red for high NJOP
        }

      case 'fire':
        // Solid colors for fire hazard: Blue (low) -> Yellow (medium) -> Red (high)
        if (normalizedValue < 0.33) {
          return 0xFF0000FF; // Solid Blue for low fire hazard
        } else if (normalizedValue < 0.67) {
          return 0xFFFFFF00; // Solid Yellow for medium fire hazard
        } else {
          return 0xFFFF0000; // Solid Red for high fire hazard
        }

      case 'flood':
        // Solid colors for flood hazard: Light Blue (low) -> Yellow (medium) -> Orange (high)
        if (normalizedValue < 0.33) {
          return 0xFF87CEEB; // Solid Light Blue for low flood hazard
        } else if (normalizedValue < 0.67) {
          return 0xFFFFFF00; // Solid Yellow for medium flood hazard
        } else {
          return 0xFFFFA500; // Solid Orange for high flood hazard
        }

      case 'total':
        // Solid colors for total hazard: Green (low) -> Red (medium) -> Purple (high)
        // Use absolute thresholds for consistency
        if (value < 0.3) { // Low hazard threshold
          return 0xFF00FF00; // Solid Green for low hazard
        } else if (value < 0.4) { // Medium hazard threshold
          return 0xFFFF0000; // Solid Red for medium hazard
        } else { // High hazard
          return 0xFF800080; // Solid Purple for high hazard
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
        // Get NJOP from properties using correct field name
        final properties = building.properties;
        final njopValue = properties['njop_total'];
        if (njopValue != null) {
          value = _parseNjopValueForGradient(njopValue);
        } else {
          value = 0.0;
        }
        mode = 'njop';
        debugPrint('🏗️ Building ${building.id}: NJOP value = $value');
        break;
      case 'hazard':
        // Get hazard sum from properties using correct field name
        final properties = building.properties;
        final hazardValue = properties['hazard_sum'];
        if (hazardValue != null) {
          value = hazardValue is num ? hazardValue.toDouble() : double.tryParse(hazardValue.toString()) ?? 0.0;
        } else {
          value = 0.0;
        }
        mode = 'total';
        debugPrint('🏗️ Building ${building.id}: Hazard value = $value');
        break;
      default:
        return 0xFF3B82F6;
    }

    if (value == null || value == 0) {
      // For NJOP and hazard modes, treat null/0 as low range (green)
      return _getLowRangeColorForMode(_colorMode);
    }

    return _getSolidColorForValue(value, mode);
  }

  // Parse NJOP value for gradient coloring (handles numeric and string formats)
  double _parseNjopValueForGradient(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final cleanValue = value.trim();
      // Remove common separators
      final processedValue = cleanValue.replaceAll(',', '').replaceAll(' ', '');

      debugPrint('🏗️ Parsing NJOP string: "$cleanValue" to number');

      final parsedValue = double.tryParse(processedValue) ?? 0.0;
      debugPrint('🏗️ Parsed NJOP value: $parsedValue');

      return parsedValue;
    }

    return 0.0;
  }

  // Get low range color based on mode
  int _getLowRangeColorForMode(String mode) {
    switch (mode) {
      case 'njop':
        return 0xFF00FF00; // Green for low NJOP
      case 'hazard':
        return 0xFF00FF00; // Green for low hazard
      default:
        return 0xFF3B82F6; // Blue default
    }
  }

  // Get medium range color based on mode
  int _getMediumRangeColorForMode(String mode) {
    switch (mode) {
      case 'njop':
        return 0xFFFFFF00; // Yellow for medium NJOP
      case 'hazard':
        return 0xFFFFFF00; // Yellow for medium hazard
      default:
        return 0xFF3B82F6; // Blue default
    }
  }

  // Get high range color based on mode
  int _getHighRangeColorForMode(String mode) {
    switch (mode) {
      case 'njop':
        return 0xFFFF0000; // Red for high NJOP
      case 'hazard':
        return 0xFF800080; // Purple for high hazard
      default:
        return 0xFF3B82F6; // Blue default
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

  // Process GeoJSON to add height and solid color properties for 3D visualization
  Map<String, dynamic> _processGeoJsonWithSolidColors(Map<String, dynamic> geoJson) {
    try {
      final processedGeoJson = Map<String, dynamic>.from(geoJson);
      final features = processedGeoJson['features'] as List<dynamic>;

      debugPrint('🏗️ Processing ${features.length} buildings with solid colors for mode: $_colorMode');

      for (int i = 0; i < features.length; i++) {
        final feature = features[i] as Map<String, dynamic>;
        final properties = Map<String, dynamic>.from(feature['properties'] as Map<String, dynamic>);

        // Ensure essential properties exist to prevent hollow buildings
        _ensureRequiredProperties(properties);

        // Create building object to calculate height and color
        final building = Building(
          id: properties['id'] as int? ?? i,
          coordinates: [], // Not needed for height calculation
          properties: properties,
        );

        // Calculate height based on NJOP value (fixed 30m for all)
        final height = 30.0; // Fixed 30m height for all buildings

        // Calculate solid color based on current color mode
        final color = _getColorForBuilding(building);

        // Add height and color to properties
        properties['height'] = height;
        properties['color'] = color;
        properties['colorMode'] = _colorMode;

        feature['properties'] = properties;
        features[i] = feature;
      }

      processedGeoJson['features'] = features;
      debugPrint('🏗️ Processed ${features.length} buildings with solid colors');
      return processedGeoJson;
    } catch (e) {
      debugPrint('❌ Error processing GeoJSON with solid colors: $e');
      return geoJson;
    }
  }

  // Ensure required properties exist to prevent hollow buildings
  void _ensureRequiredProperties(Map<String, dynamic> properties) {
    debugPrint('🏗️ Ensuring properties for building ${properties['id']}: original properties = ${properties.keys.toList()}');

    // Use the correct field names from the API
    if (!properties.containsKey('njop_total')) {
      debugPrint('🏗️ Building ${properties['id']}: Missing njop_total, checking alternatives');
    }

    // Check for any NJOP field with case-insensitive comparison
    bool hasNjop = properties.keys.any((key) =>
        key.toLowerCase().contains('njop') ||
        key.toLowerCase().contains('property') && properties[key] != null
    );

    bool hasHazard = properties.keys.any((key) =>
        key.toLowerCase().contains('hazard') ||
        key.toLowerCase().contains('danger')
    );

    debugPrint('🏗️ Building ${properties['id']}: Has NJOP=$hasNjop, Has Hazard=$hasHazard');

    // Set default values if missing (but don't override existing data)
    if (!hasNjop && !properties.containsKey('njop_total')) {
      properties['njop_total'] = 0;
      debugPrint('🏗️ Set default njop_total=0 for building ${properties['id']}');
    }

    if (!hasHazard && !properties.containsKey('hazard_sum')) {
      properties['hazard_sum'] = 0;
      debugPrint('🏗️ Set default hazard_sum=0 for building ${properties['id']}');
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

      // Process GeoJSON with solid colors
      final processedGeoJson = _processGeoJsonWithSolidColors(_rawBuildingsGeoJson);

      // Add source for our custom buildings with gradient colors
      final buildingSource = mb.GeoJsonSource(
        id: "buildings-source",
        data: jsonEncode(processedGeoJson),
      );
      await _mapboxMap.style.addSource(buildingSource);
      debugPrint('✅ Buildings source with solid colors added successfully');

      // **MULTIPLE 3D LAYERS**: Add buildings with different colors based on value ranges
      await _addBuildingLayersByValueRanges();

      // Add building outlines for better 3D definition (transparan)
      final outlineLayer = mb.LineLayer(
        id: "buildings-3d-outline",
        sourceId: "buildings-source",
        lineOpacity: 0.0, // Diubah menjadi 0.0 agar transparan
        lineColor: Colors.black.value,
        lineWidth: 1.0,
      );
      await _mapboxMap.style.addLayer(outlineLayer);
      debugPrint('✅ 3D outline layer added for definition (transparent)');

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

      // Convert screen coordinate to geographic coordinates
      final point = await _mapboxMap.coordinateForPixel(coordinate);
      final tapLatLng = LatLng(point.coordinates.lat.toDouble(), point.coordinates.lng.toDouble());

      debugPrint('🏗️ Converted screen coordinates to: ${tapLatLng.latitude}, ${tapLatLng.longitude}');

      // Find the building that contains the tapped point
      for (final building in _buildings) {
        if (_isPointInBuilding(tapLatLng, building)) {
          debugPrint('🏗️ Found building ${building.id} at tapped location');
          return [building];
        }
      }

      // If no exact match found, find the nearest building
      if (_buildings.isNotEmpty) {
        final nearestBuilding = _findNearestBuilding(tapLatLng);
        debugPrint('🏗️ No exact match found, selecting nearest building: ${nearestBuilding.id}');
        return [nearestBuilding];
      }

      debugPrint('🏗️ No buildings found at tapped location');
      return [];
    } catch (e) {
      debugPrint('❌ Error querying features: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Check if a point is within a building's bounds
  bool _isPointInBuilding(LatLng point, Building building) {
    try {
      final bounds = building.getBounds();
      return point.latitude >= bounds.south &&
             point.latitude <= bounds.north &&
             point.longitude >= bounds.west &&
             point.longitude <= bounds.east;
    } catch (e) {
      debugPrint('❌ Error checking if point is in building ${building.id}: $e');
      return false;
    }
  }

  // Find the nearest building to a given point
  Building _findNearestBuilding(LatLng point) {
    Building nearest = _buildings.first;
    double minDistance = _calculateDistance(point, nearest.getCenter());

    for (final building in _buildings.skip(1)) {
      final distance = _calculateDistance(point, building.getCenter());
      if (distance < minDistance) {
        minDistance = distance;
        nearest = building;
      }
    }

    return nearest;
  }

  // Calculate distance between two points (simplified)
  double _calculateDistance(LatLng point1, LatLng point2) {
    final latDiff = point1.latitude - point2.latitude;
    final lngDiff = point1.longitude - point2.longitude;
    return (latDiff * latDiff + lngDiff * lngDiff).abs();
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

  void _showColorModeSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Mode Tampilan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeOption('default', 'Default', Icons.color_lens, 'Semua bangunan dengan warna biru standar'),
              _buildModeOption('njop', 'NJOP Value', Icons.attach_money, 'Bangunan berdasarkan nilai NJOP'),
              _buildModeOption('hazard', 'Hazard Level', Icons.warning, 'Bangunan berdasarkan tingkat bahaya'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeOption(String mode, String title, IconData icon, String description) {
    final isSelected = _colorMode == mode;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _changeColorMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _changeColorMode(String newMode) {
    if (_colorMode == newMode) return;

    debugPrint('🏗️ Changing color mode from $_colorMode to $newMode');

    // Only change color mode, keep map intact
    setState(() {
      _colorMode = newMode;
    });

    // Rebuild only the building layers, not the entire map
    _rebuildBuildingsLayer();
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

      // Only rebuild building layers, keep map and data intact

      // Ensure data is loaded
      if (_rawBuildingsGeoJson.isEmpty) {
        debugPrint('🏗️ No GeoJSON data available, loading first...');
        await _loadBuildingsOnly();
        return;
      }

      debugPrint('🏗️ Adding new building layers for $_colorMode mode...');

      // Add new layers with current color mode (using unique IDs to avoid conflicts)
      await _addBuildingLayersByValueRanges();

      debugPrint('✅ Buildings layer rebuilt with color mode: $_colorMode');

      // Show message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mode changed to ${_getColorModeDisplayName()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error rebuilding buildings layer: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Note: Since Mapbox SDK doesn't support layer removal, we rely on unique IDs

  // SIMPLIFIED LAYER RESET: Use unique IDs instead of removing layers
  Future<void> _completelyResetAllBuildingLayers() async {
    debugPrint('🏗️ SIMPLIFIED RESET: Using unique IDs instead of removing layers');
    // Since Mapbox SDK doesn't support layer removal, we use unique IDs for each mode
    // This prevents conflicts without needing to remove layers
  }

  // Simple cleanup method - just log since SDK doesn't support layer removal
  void _toggleMapStyle() {
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

    debugPrint('🗺️ Changing map style from $_currentStyle to $nextStyle');

    setState(() {
      _currentStyle = nextStyle;
    });
  }

  Future<void> _removeAllBuildingLayers() async {
    debugPrint('🏗️ Note: Layer cleanup not supported by SDK, using unique layer IDs instead');
  }

  // Note: Mapbox SDK doesn't support layer removal, rely on unique layer IDs
  // All layers are created without outlines (fillExtrusionBase: 0.0)

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
          // Icon 1: Mode Tampilan (Default/NJOP/Hazard)
          IconButton(
            icon: Icon(_getColorModeIcon()),
            onPressed: _showColorModeSelector,
            tooltip: 'Pilih Mode Tampilan',
          ),
          // Icon 2: Map Style (Satellite/Street/Light/Dark)
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _toggleMapStyle,
            tooltip: 'Ganti Map Style',
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
                  key: ValueKey('3d_buildings_map_$_currentStyle-$_colorMode'),
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
      debugPrint('🏗️ Raw buildings data available: ${_rawBuildingsGeoJson['features']?.length ?? 0} buildings');

      if (_colorMode == 'default') {
        // Default mode: single blue layer with ALL buildings
        await _addSingleBuildingLayer(0xFF3B82F6);
        return;
      }

      // For NJOP and Hazard modes, ensure ALL buildings are displayed
      debugPrint('🏗️ Processing ${_colorMode} mode - ensuring all buildings are included');

      // Add ALL buildings to a single layer for NJOP and Hazard modes
      await _addSingleBuildingLayerWithSolidColors();

      debugPrint('✅ Created solid color building layer for $_colorMode mode with ALL buildings');
    } catch (e) {
      debugPrint('❌ Error creating building layers: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');

      // Fallback: try to add a simple layer
      try {
        await _addSingleBuildingLayer(0xFF3B82F6);
        debugPrint('✅ Added fallback layer');
      } catch (fallbackError) {
        debugPrint('❌ Even fallback layer failed: $fallbackError');
      }
    }
  }

  // Add multiple layers with solid colors based on value ranges
  Future<void> _addSingleBuildingLayerWithSolidColors() async {
    try {
      debugPrint('🏗️ Adding solid color layers for $_colorMode mode...');

      if (_colorMode == 'default') {
        // Default: single blue layer
        final defaultLayer = mb.FillExtrusionLayer(
          id: "buildings-default-layer-$_colorMode",
          sourceId: "buildings-source",
          fillExtrusionOpacity: 0.8,
          fillExtrusionHeight: 30.0,
          fillExtrusionBase: 0.0,
          fillExtrusionColor: 0xFF3B82F6,
        );
        await _mapboxMap.style.addLayer(defaultLayer);
      } else {
        // NJOP/Hazard: create separate layers for each color range
        String mode = _colorMode == 'hazard' ? 'total' : _colorMode;
        final range = _dataRanges[mode];

        if (range != null) {
          final min = range['min'] as double;
          final max = range['max'] as double;
          final rangeSize = max - min;

          if (rangeSize > 0) {
            // Calculate thresholds with better distribution
            double lowThreshold, mediumThreshold;

            if (mode == 'njop') {
              // For NJOP, use more realistic thresholds
              // Low: < 100M, Medium: 100M - 1B, High: > 1B
              lowThreshold = 100000000; // 100 million
              mediumThreshold = 1000000000; // 1 billion

              // Adjust if data range is different
              if (max < 1000000000) {
                lowThreshold = min + (rangeSize * 0.4);
                mediumThreshold = min + (rangeSize * 0.7);
              }
            } else {
              // For hazard values, use standard distribution
              lowThreshold = min + (rangeSize * 0.3);
              mediumThreshold = min + (rangeSize * 0.7);
            }

            debugPrint('🏗️ Creating solid color layers for $_colorMode mode:');
            debugPrint('  Data range: $min - $max');
            debugPrint('  Low range: 0 - $lowThreshold');
            debugPrint('  Medium range: $lowThreshold - $mediumThreshold');
            debugPrint('  High range: $mediumThreshold - ∞');

            // Low range layer
            await _createSolidColorLayer(
              'buildings-low-$_colorMode',
              0.0,
              lowThreshold,
              _getSolidColorForValue(min + (rangeSize * 0.16), mode), // Low color
              mode
            );

            // Medium range layer
            await _createSolidColorLayer(
              'buildings-medium-$_colorMode',
              lowThreshold,
              mediumThreshold,
              _getSolidColorForValue(min + (rangeSize * 0.5), mode), // Medium color
              mode
            );

            // High range layer
            await _createSolidColorLayer(
              'buildings-high-$_colorMode',
              mediumThreshold,
              double.infinity,
              _getSolidColorForValue(min + (rangeSize * 0.83), mode), // High color
              mode
            );
          } else {
            // Fallback: single layer with low color
            final fallbackLayer = mb.FillExtrusionLayer(
              id: "buildings-fallback-$_colorMode",
              sourceId: "buildings-source",
              fillExtrusionOpacity: 0.8,
              fillExtrusionHeight: 30.0,
              fillExtrusionBase: 0.0,
              fillExtrusionColor: _getSolidColorForValue(min, mode),
            );
            await _mapboxMap.style.addLayer(fallbackLayer);
          }
        }
      }

      debugPrint('✅ Added solid color layers for $_colorMode mode');

    } catch (e) {
      debugPrint('❌ Error adding solid color layer: $e');
      rethrow;
    }
  }

  // Create a solid color layer for buildings within a specific value range
  Future<void> _createSolidColorLayer(
    String layerId,
    double minValue,
    double maxValue,
    int color,
    String mode,
  ) async {
    try {
      final features = _rawBuildingsGeoJson['features'] as List<dynamic>;
      final filteredFeatures = <dynamic>[];

      for (final feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>;
        dynamic value = 0;

        // Get value based on mode
        if (mode == 'njop') {
          value = properties['njop_total'] ??
                  properties['njop_total'] ??
                  properties['njopTotal'] ??
                  properties['njop'] ??
                  0;

          if (value is String) {
            final cleanedValue = value.replaceAll('B', '').replaceAll(',', '').trim();
            value = double.tryParse(cleanedValue) ?? 0.0;
            value = value * 1000000000;
          } else if (value != null) {
            value = value is int ? value.toDouble() : value;
          }
        } else if (mode == 'total') {
          value = properties['hazard_sum'] ??
                  properties['hazardSum'] ??
                  properties['total_hazard'] ??
                  properties['totalHazard'] ??
                  0;

          if (value is String) {
            value = double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
          } else if (value != null) {
            value = value is int ? value.toDouble() : value;
          }
        }

        if (value == null) value = 0.0;

        // Include buildings in this range
        if (value >= minValue && (maxValue == double.infinity || value <= maxValue)) {
          filteredFeatures.add(feature);
        } else if (value == 0 && minValue == 0.0) {
          // Add zero-value buildings to the lowest range
          filteredFeatures.add(feature);
        }
      }

      if (filteredFeatures.isEmpty) {
        debugPrint('🏗️ No buildings for layer $layerId (${minValue.toStringAsFixed(1)}-${maxValue == double.infinity ? '∞' : maxValue.toStringAsFixed(1)})');
        return;
      }

      debugPrint('🏗️ Layer $layerId: ${filteredFeatures.length} buildings (${minValue.toStringAsFixed(1)}-${maxValue == double.infinity ? '∞' : maxValue.toStringAsFixed(1)})');

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

      // Add solid color layer
      final extrusionLayer = mb.FillExtrusionLayer(
        id: layerId,
        sourceId: '${layerId}-source',
        fillExtrusionOpacity: 0.8,
        fillExtrusionHeight: 30.0,
        fillExtrusionBase: 0.0,
        fillExtrusionColor: color,
      );
      await _mapboxMap.style.addLayer(extrusionLayer);

      debugPrint('✅ Created solid color layer $layerId with color: 0x${color.toRadixString(16)}');

    } catch (e) {
      debugPrint('❌ Error creating solid color layer $layerId: $e');
    }
  }

  // Create multiple layers for gradient effect based on data ranges
  Future<void> _createGradientLayersForMode() async {
    try {
      debugPrint('🏗️ Creating gradient layers for $_colorMode mode...');

      String mode = _colorMode == 'hazard' ? 'total' : _colorMode;
      final range = _dataRanges[mode];

      if (range == null || range['max'] == 0) {
        debugPrint('⚠️ No data range available for mode: $_colorMode');
        debugPrint('🏗️ Available ranges: $_dataRanges');

        debugPrint('🏗️ Using available range data for $_colorMode mode');
      }

      final min = range['min'] as double;
      final max = range['max'] as double;
      final rangeSize = max - min;

      if (rangeSize <= 0) {
        debugPrint('⚠️ Invalid range size for mode: $_colorMode');
        await _addSingleBuildingLayer(_getLowRangeColorForMode(_colorMode));
        return;
      }

      // Calculate thresholds for gradient - adjusted for actual data distribution
      final lowThreshold = min + (rangeSize * 0.25);  // 25% for low
      final mediumThreshold = min + (rangeSize * 0.75); // 75% for medium

      debugPrint('🏗️ Creating gradient layers for $_colorMode mode:');
      debugPrint('  Range: $min - $max');
      debugPrint('  Low range: 0 - $lowThreshold');
      debugPrint('  Medium range: $lowThreshold - $mediumThreshold');
      debugPrint('  High range: $mediumThreshold - ∞');

      // Create filtered layers for each range
      await _createBuildingLayerForRange(
        'buildings-3d-low-$_colorMode',
        0.0,
        lowThreshold,
        _getLowRangeColorForMode(_colorMode),
        _rawBuildingsGeoJson,
      );

      await _createBuildingLayerForRange(
        'buildings-3d-medium-$_colorMode',
        lowThreshold,
        mediumThreshold,
        _getMediumRangeColorForMode(_colorMode),
        _rawBuildingsGeoJson,
      );

      await _createBuildingLayerForRange(
        'buildings-3d-high-$_colorMode',
        mediumThreshold,
        double.infinity,
        _getHighRangeColorForMode(_colorMode),
        _rawBuildingsGeoJson,
      );

    } catch (e) {
      debugPrint('❌ Error creating gradient layers: $e');
      rethrow;
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
          // Check all possible NJOP field names
          value = properties['njop_total'] ??
                  properties['njop_total'] ??
                  properties['njopTotal'] ??
                  properties['njop'] ??
                  0;

          debugPrint('🏗️ Processing building ${properties['id']} for NJOP: raw value = $value');

          if (value is String) {
            // Remove 'B' and convert to double, then multiply by 1,000,000,000 for actual value
            final cleanedValue = value.replaceAll('B', '').replaceAll(',', '').trim();
            value = double.tryParse(cleanedValue) ?? 0.0;
            value = value * 1000000000; // Convert from billions to actual number
            debugPrint('🏗️ Converted NJOP string "$value" to ${value}');
          } else if (value != null) {
            // Already a number, ensure it's in the right format
            value = value is int ? value.toDouble() : value;
            debugPrint('🏗️ NJOP numeric value: $value');
          }
        } else if (mode == 'total') {
          // Check all possible hazard field names
          value = properties['hazard_sum'] ??
                  properties['hazardSum'] ??
                  properties['total_hazard'] ??
                  properties['totalHazard'] ??
                  0;

          debugPrint('🏗️ Processing building ${properties['id']} for hazard: raw value = $value');

          if (value is String) {
            value = double.tryParse(value.replaceAll(',', '').trim()) ?? 0.0;
            debugPrint('🏗️ Converted hazard string "$value" to $value');
          } else if (value != null) {
            value = value is int ? value.toDouble() : value;
            debugPrint('🏗️ Hazard numeric value: $value');
          }
        }

        // Ensure value is a number and not null
        if (value == null) {
          value = 0.0;
        }

        debugPrint('🏗️ Building ${properties['id']}: final value = $value, range = [$minValue, $maxValue]');

        // Include buildings with valid data in appropriate ranges
        if (value >= minValue && (maxValue == double.infinity || value <= maxValue)) {
          filteredFeatures.add(feature);
          debugPrint('🏗️ Building ${properties['id']} added to $layerId (value in range)');
        } else if (value == 0) {
          // Add zero-value buildings to the lowest range
          if (layerId.contains('low')) {
            filteredFeatures.add(feature);
            debugPrint('🏗️ Building ${properties['id']} added to $layerId (zero value)');
          }
        } else {
          debugPrint('🏗️ Building ${properties['id']} NOT added to $layerId (value $value outside range)');
        }
      }

      debugPrint('🏗️ Layer $layerId: ${filteredFeatures.length} buildings (${minValue.toStringAsFixed(1)}-${maxValue == double.infinity ? '∞' : maxValue.toStringAsFixed(1)})');

      if (filteredFeatures.isEmpty) return;

      // Create filtered GeoJSON
      final filteredGeoJson = {
        'type': 'FeatureCollection',
        'features': filteredFeatures,
      };

      // Add source for this layer with unique ID
      final uniqueLayerId = '${layerId}-$_colorMode';
      final buildingSource = mb.GeoJsonSource(
        id: '${uniqueLayerId}-source',
        data: jsonEncode(filteredGeoJson),
      );
      await _mapboxMap.style.addSource(buildingSource);

      // Add 3D layer for this range with unique ID
      final extrusionLayer = mb.FillExtrusionLayer(
        id: uniqueLayerId,
        sourceId: '${uniqueLayerId}-source',
        fillExtrusionOpacity: 0.8,
        fillExtrusionHeight: 30.0,
        fillExtrusionBase: 0.0, // No outline - buildings start from ground level
        fillExtrusionColor: color,
      );
      await _mapboxMap.style.addLayer(extrusionLayer);

    } catch (e) {
      debugPrint('❌ Error creating layer $layerId: $e');
    }
  }

  Future<void> _addSingleBuildingLayer(int color) async {
    try {
      final uniqueLayerId = "buildings-3d-single-$_colorMode";
      final singleLayer = mb.FillExtrusionLayer(
        id: uniqueLayerId,
        sourceId: "buildings-source",
        fillExtrusionOpacity: 0.8,
        fillExtrusionHeight: 30.0,
        fillExtrusionBase: 0.0, // Start from ground level, no outline
        fillExtrusionColor: color,
      );
      await _mapboxMap.style.addLayer(singleLayer);
      debugPrint('✅ Single building layer added with color: $color for $_colorMode mode');
    } catch (e) {
      debugPrint('❌ Error adding single building layer: $e');
    }
  }

  // Create layer for buildings with no data
  Future<void> _createNoDataLayer() async {
    try {
      debugPrint('🏗️ Creating no-data layer...');

      final features = _rawBuildingsGeoJson['features'] as List<dynamic>;
      final noDataFeatures = <dynamic>[];
      String mode = _colorMode == 'hazard' ? 'total' : _colorMode;

      // Find buildings with no data for current mode
      for (final feature in features) {
        final properties = feature['properties'] as Map<String, dynamic>;
        bool hasData = false;

        if (mode == 'njop') {
          // Check all possible NJOP field names
          final njopValue = properties['njop_total'] ??
                          properties['njop_total'] ??
                          properties['njopTotal'] ??
                          properties['njop'];

          debugPrint('🏗️ Building ${properties['id']}: NJOP value = $njopValue');

          if (njopValue != null) {
            // Handle string values (like "1.23B")
            String valueStr = njopValue.toString().toLowerCase().trim();
            hasData = valueStr != '' &&
                     valueStr != 'null' &&
                     valueStr != '0' &&
                     valueStr != '0.0' &&
                     !valueStr.startsWith('0b'); // Exclude zero-based values
          }
        } else if (mode == 'total') {
          // Check all possible hazard field names
          final hazardValue = properties['hazard_sum'] ??
                             properties['hazardSum'] ??
                             properties['total_hazard'] ??
                             properties['totalHazard'];

          debugPrint('🏗️ Building ${properties['id']}: Hazard value = $hazardValue');

          if (hazardValue != null) {
            // Handle string or numeric values
            String valueStr = hazardValue.toString().trim();
            hasData = valueStr != '' &&
                     valueStr != 'null' &&
                     valueStr != '0' &&
                     valueStr != '0.0';
          }
        }

        if (!hasData) {
          debugPrint('🏗️ Building ${properties['id']} has no data for $mode mode');
          noDataFeatures.add(feature);
        }
      }

      debugPrint('🏗️ Found ${noDataFeatures.length} buildings with no data for $mode mode');

      if (noDataFeatures.isEmpty) {
        debugPrint('🏗️ No no-data buildings to display');
        return;
      }

      // Create GeoJSON for no-data buildings
      final noDataGeoJson = {
        'type': 'FeatureCollection',
        'features': noDataFeatures,
      };

      // Add source for no-data buildings with unique ID
      final noDataSource = mb.GeoJsonSource(
        id: 'buildings-no-data-source-$_colorMode',
        data: jsonEncode(noDataGeoJson),
      );
      await _mapboxMap.style.addSource(noDataSource);

      // Add layer for no-data buildings (gray color) with unique ID
      final noDataLayer = mb.FillExtrusionLayer(
        id: 'buildings-no-data-layer-$_colorMode',
        sourceId: 'buildings-no-data-source-$_colorMode',
        fillExtrusionOpacity: 0.8,
        fillExtrusionHeight: 30.0,
        fillExtrusionBase: 0.0,
        fillExtrusionColor: 0xFF808080, // Gray color for no data
      );
      await _mapboxMap.style.addLayer(noDataLayer);

      debugPrint('✅ No-data layer added with ${noDataFeatures.length} buildings');
    } catch (e) {
      debugPrint('❌ Error creating no-data layer: $e');
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
              _colorMode == 'njop' ? 'NJOP' : '${_getColorModeDisplayName()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendWithGradientAndValues(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendWithGradientAndValues() {
    String mode = _colorMode == 'hazard' ? 'total' : _colorMode;
    final range = _dataRanges[mode];

    String lowValue, highValue;
    if (range != null) {
      final min = range['min'] as double;
      final max = range['max'] as double;

      switch (_colorMode) {
        case 'njop':
          lowValue = _formatNumber(min);
          highValue = _formatNumber(max);
          break;
        case 'hazard':
          lowValue = min.toStringAsFixed(3);
          highValue = max.toStringAsFixed(3);
          break;
        default:
          lowValue = min.toStringAsFixed(1);
          highValue = max.toStringAsFixed(1);
      }
    } else {
      lowValue = 'No data';
      highValue = 'No data';
    }

    List<Color> colors;
    switch (_colorMode) {
      case 'njop':
        colors = [const Color(0xFF00FF00), const Color(0xFFFFFF00), const Color(0xFFFF0000)];
        break;
      case 'hazard':
        colors = [const Color(0xFF00FF00), const Color(0xFFFF0000), const Color(0xFF800080)];
        break;
      default:
        colors = [const Color(0xFF00FF00), const Color(0xFFFFFF00), const Color(0xFFFF0000)];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gradient bar on the left
        Container(
          height: 60,
          width: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Values aligned with gradient positions on the right
        SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _colorMode == 'njop' ? '> 1B' : 'High',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
              Text(
                _colorMode == 'njop' ? '100M-1B' : 'Med',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
              Text(
                _colorMode == 'njop' ? '< 100M' : 'Low',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to format numbers with scientific notation
  String _formatNumber(double num) {
    if (num == 0) return '0';

    final absNum = num.abs();

    // If number is less than 1000, show as is
    if (absNum < 1000) {
      return num.toStringAsFixed(0);
    }

    // Calculate exponent
    int exponent = 0;
    double mantissa = absNum;

    while (mantissa >= 10) {
      mantissa /= 10;
      exponent++;
    }

    // Round mantissa to 2 decimal places for display
    mantissa = double.parse(mantissa.toStringAsFixed(2));

    return '${mantissa}×10³';
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
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.map,
                        label: 'Sub zona RDTR',
                        value: building.kodszntext ?? 'N/A',
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