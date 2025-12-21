import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

class MapTile {
  final int id;
  final List<List<List<List<double>>>> coordinates; // Polygon coordinates
  final Map<String, dynamic> properties;
  bool isSaved;

  MapTile({
    required this.id,
    required this.coordinates,
    required this.properties,
    this.isSaved = false,
  });

  factory MapTile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final rawCoords = json['geometry']['coordinates'];

    debugPrint('🏗️ Creating MapTile ID: $id');
    debugPrint('📐 Raw coordinates type: ${rawCoords.runtimeType}');
    debugPrint('📐 Raw coordinates: $rawCoords');

    final coordinates = _parseCoordinates(rawCoords);

    debugPrint('✅ Parsed ${coordinates.length} coordinate arrays');
    if (coordinates.isNotEmpty) {
      debugPrint('🔍 First coord array length: ${coordinates[0].length}');
      if (coordinates[0].isNotEmpty) {
        debugPrint('🔍 First ring length: ${coordinates[0][0].length}');
        if (coordinates[0][0].isNotEmpty) {
          debugPrint('🔍 First point: ${coordinates[0][0][0]}');
        }
      }
    }

    return MapTile(
      id: id,
      coordinates: coordinates,
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );
  }

  static List<List<List<List<double>>>> _parseCoordinates(dynamic coords) {
    if (coords is! List) return [];

    return coords.map((coord) {
      if (coord is! List) return <List<List<double>>>[];
      return coord.map((ring) {
        if (ring is! List) return <List<double>>[];
        return ring.map((point) {
          if (point is! List || point.length < 2) return [0.0, 0.0];
          try {
            final x = double.parse(point[0].toString());
            final y = double.parse(point[1].toString());
            return [x, y];
          } catch (e) {
            return [0.0, 0.0];
          }
        }).toList();
      }).toList();
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'geometry': {
        'coordinates': coordinates,
      },
      'properties': properties,
      'isSaved': isSaved,
    };
  }

  // Get center point of the tile for map focusing
  LatLng getCenter() {
    if (coordinates.isEmpty || coordinates[0].isEmpty || coordinates[0][0].isEmpty) {
      debugPrint('⚠️ Tile $id: Empty coordinates, returning (0,0)');
      return LatLng(0, 0);
    }

    // For the parsed coordinate structure, we need coordinates[0][0] to get the ring with coordinate points
    final firstRing = coordinates[0][0];
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    debugPrint('🔍 Tile $id: Processing ${firstRing.length} coordinate points');

    for (final point in firstRing) {
      // point is a List<double> containing [longitude, latitude]
      final lng = point[0] as double; // longitude
      final lat = point[1] as double; // latitude
      totalLat += lat;
      totalLng += lng;
      count++;
    }

    final centerLat = totalLat / count;
    final centerLng = totalLng / count;
    debugPrint('📍 Tile $id: Center calculated at ($centerLat, $centerLng)');

    return LatLng(centerLat, centerLng);
  }

  // Get bounding box for the tile
  LatLngBounds getBounds() {
    if (coordinates.isEmpty || coordinates[0].isEmpty || coordinates[0][0].isEmpty) {
      debugPrint('⚠️ Tile $id: Empty coordinates for bounds, returning (0,0)');
      return LatLngBounds(LatLng(0, 0), LatLng(0, 0));
    }

    // For the parsed coordinate structure, we need coordinates[0][0] to get the ring with coordinate points
    final firstRing = coordinates[0][0];
    final firstPoint = firstRing[0];
    double minLat = firstPoint[1] as double; // latitude
    double maxLat = firstPoint[1] as double; // latitude
    double minLng = firstPoint[0] as double; // longitude
    double maxLng = firstPoint[0] as double; // longitude

    debugPrint('🔍 Tile $id: Initial bounds: lat[$minLat,$maxLat], lng[$minLng,$maxLng]');

    for (final point in firstRing) {
      final lng = point[0] as double; // longitude
      final lat = point[1] as double; // latitude

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    debugPrint('📐 Tile $id: Final bounds: lat[$minLat,$maxLat], lng[$minLng,$maxLng]');

    // Fix: LatLngBounds expects (northWest, southEast) but we were passing (southWest, northEast)
    return LatLngBounds(LatLng(maxLat, minLng), LatLng(minLat, maxLng));
  }

  MapTile copyWith({
    int? id,
    List<List<List<List<double>>>>? coordinates,
    Map<String, dynamic>? properties,
    bool? isSaved,
  }) {
    return MapTile(
      id: id ?? this.id,
      coordinates: coordinates ?? this.coordinates,
      properties: properties ?? this.properties,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

class Building {
  final int id;
  final List<List<List<List<double>>>> coordinates; // MultiPolygon coordinates
  final Map<String, dynamic> properties;
  bool isSaved;

  Building({
    required this.id,
    required this.coordinates,
    required this.properties,
    this.isSaved = false,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['id'] as int,
      coordinates: _parseCoordinates(json['geometry']['coordinates']),
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );
  }

  static List<List<List<List<double>>>> _parseCoordinates(dynamic coords) {
    if (coords is! List) return [];

    return coords.map((coord) {
      if (coord is! List) return <List<List<double>>>[];
      return coord.map((ring) {
        if (ring is! List) return <List<double>>[];
        return ring.map((point) {
          if (point is! List || point.length < 2) return [0.0, 0.0];
          try {
            final x = double.parse(point[0].toString());
            final y = double.parse(point[1].toString());
            return [x, y];
          } catch (e) {
            return [0.0, 0.0];
          }
        }).toList();
      }).toList();
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'geometry': {
        'coordinates': coordinates,
      },
      'properties': properties,
      'isSaved': isSaved,
    };
  }

  // Get center point of the building for map focusing
  LatLng getCenter() {
    if (coordinates.isEmpty || coordinates[0].isEmpty || coordinates[0][0].isEmpty) {
      return LatLng(0, 0);
    }

    final firstRing = coordinates[0][0];
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    for (final point in firstRing) {
      totalLat += point[1]; // latitude
      totalLng += point[0]; // longitude
      count++;
    }

    return LatLng(totalLat / count, totalLng / count);
  }

  // Get bounding box for the building
  LatLngBounds getBounds() {
    if (coordinates.isEmpty || coordinates[0].isEmpty || coordinates[0][0].isEmpty) {
      return LatLngBounds(LatLng(0, 0), LatLng(0, 0));
    }

    final firstRing = coordinates[0][0];
    double minLat = firstRing[0][1];
    double maxLat = firstRing[0][1];
    double minLng = firstRing[0][0];
    double maxLng = firstRing[0][0];

    for (final point in firstRing) {
      final lat = point[1];
      final lng = point[0];

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  // Get NJOP value from properties
  double? get njopTotal {
    final value = properties['njop_total'];
    if (value == null) return null;

    if (value is String) {
      // Remove 'B' and convert to double, then multiply by 1,000,000,000 for actual value
      final cleanedValue = value.replaceAll('B', '').replaceAll(',', '').trim();
      final parsed = double.tryParse(cleanedValue);
      return parsed != null ? parsed * 1000000000 : null;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }
    return null;
  }

  // Get formatted NJOP value
  String get formattedNjop {
    final njop = njopTotal;
    if (njop == null) return 'N/A';

    if (njop >= 1000000000) {
      return '${(njop / 1000000000).toStringAsFixed(1)}B';
    } else if (njop >= 1000000) {
      return '${(njop / 1000000).toStringAsFixed(1)}M';
    } else if (njop >= 1000) {
      return '${(njop / 1000).toStringAsFixed(1)}K';
    } else {
      return njop.toStringAsFixed(0);
    }
  }

  // Get hazard values
  double? get fireHazard => properties['fire_hazar']?.toDouble();
  double? get floodHazard => properties['flood_haza']?.toDouble();
  double? get hazardSum => properties['hazard_sum']?.toDouble();

  // Get zone code text (kodszntext)
  String? get kodszntext => properties['kodszntext'] as String?;


  // Calculate extrusion height based on NJOP value (property tax)
  double calculateExtrusionHeight({double minHeight = 15.0, double maxHeight = 50.0}) {
    final njop = njopTotal;
    if (njop == null) return 25.0; // Default height for buildings without NJOP data

    // Map NJOP values to height ranges (logarithmic scale for better distribution)
    // Higher NJOP = taller building (indicating more valuable property)
    if (njop >= 1000000000) return maxHeight; // 1B+ = 50m
    if (njop >= 500000000) return 40.0;       // 500M-1B = 40m
    if (njop >= 100000000) return 35.0;       // 100M-500M = 35m
    if (njop >= 50000000) return 30.0;        // 50M-100M = 30m
    if (njop >= 10000000) return 25.0;        // 10M-50M = 25m
    if (njop >= 5000000) return 20.0;         // 5M-10M = 20m
    if (njop >= 1000000) return 18.0;         // 1M-5M = 18m
    return minHeight; // <1M = minimum height
  }

  // Get height-based color gradient for 3D buildings
  int getHeightBasedColor() {
    final height = calculateExtrusionHeight();

    // Create color gradient from green (short) to red (tall)
    if (height >= 45.0) return 0xFF8B0000; // Dark Red
    if (height >= 35.0) return 0xFFDC143C; // Crimson
    if (height >= 25.0) return 0xFFFF4500; // Orange Red
    if (height >= 20.0) return 0xFFFFA500; // Orange
    if (height >= 15.0) return 0xFFFFD700; // Gold
    return 0xFF32CD32; // Lime Green
  }

  Building copyWith({
    int? id,
    List<List<List<List<double>>>>? coordinates,
    Map<String, dynamic>? properties,
    bool? isSaved,
  }) {
    return Building(
      id: id ?? this.id,
      coordinates: coordinates ?? this.coordinates,
      properties: properties ?? this.properties,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

class BuildingStats {
  final double minNjopTotal;
  final double maxNjopTotal;
  final double minFireHazard;
  final double maxFireHazard;
  final double minFloodHazard;
  final double maxFloodHazard;
  final double minHazardSum;
  final double maxHazardSum;

  BuildingStats({
    required this.minNjopTotal,
    required this.maxNjopTotal,
    required this.minFireHazard,
    required this.maxFireHazard,
    required this.minFloodHazard,
    required this.maxFloodHazard,
    required this.minHazardSum,
    required this.maxHazardSum,
  });

  factory BuildingStats.fromJson(Map<String, dynamic> json) {
    return BuildingStats(
      minNjopTotal: double.parse(json['min_njop_total'].toString()),
      maxNjopTotal: double.parse(json['max_njop_total'].toString()),
      minFireHazard: double.parse(json['min_fire_hazard'].toString()),
      maxFireHazard: double.parse(json['max_fire_hazard'].toString()),
      minFloodHazard: double.parse(json['min_flood_hazard'].toString()),
      maxFloodHazard: double.parse(json['max_flood_hazard'].toString()),
      minHazardSum: double.parse(json['min_hazard_sum'].toString()),
      maxHazardSum: double.parse(json['max_hazard_sum'].toString()),
    );
  }
}

class MapTilesService {
  static final MapTilesService _instance = MapTilesService._internal();
  factory MapTilesService() => _instance;
  MapTilesService._internal();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pix2land-backend.vercel.app',
  );

  // Get tiles from the backend
  Future<List<MapTile>> getTiles() async {
    try {
      AppLogger.api('Fetching tiles from $_baseUrl/tiles');
      final response = await http.get(
        Uri.parse('$_baseUrl/tiles'),
        headers: {'Content-Type': 'application/json'},
      );

      AppLogger.network('Tiles response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;

        final tiles = features.map((feature) {
          final tile = MapTile.fromJson(feature);
          AppLogger.debug('Parsed tile ID: ${tile.id}');
          return tile;
        }).toList();

        AppLogger.api('Successfully fetched ${tiles.length} tiles');
        return tiles;
      } else {
        AppLogger.error('Failed to fetch tiles: ${response.statusCode}', tag: 'API');
        throw Exception('Failed to fetch tiles: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.api('Error fetching tiles', error: e, stackTrace: stackTrace);
      throw Exception('Error fetching tiles: ${e.toString()}');
    }
  }

  // Get buildings from the backend
  Future<List<Building>> getBuildings() async {
    try {
      AppLogger.api('Fetching buildings from $_baseUrl/buildings');
      final response = await http.get(
        Uri.parse('$_baseUrl/buildings'),
        headers: {'Content-Type': 'application/json'},
      );

      AppLogger.network('Buildings response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;

        final buildings = features.map((feature) {
          final building = Building.fromJson(feature);
          AppLogger.debug('Parsed building ID: ${building.id}, NJOP: ${building.formattedNjop}');
          return building;
        }).toList();

        AppLogger.api('Successfully fetched ${buildings.length} buildings');
        return buildings;
      } else {
        AppLogger.error('Failed to fetch buildings: ${response.statusCode}', tag: 'API');
        throw Exception('Failed to fetch buildings: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.api('Error fetching buildings', error: e, stackTrace: stackTrace);
      throw Exception('Error fetching buildings: ${e.toString()}');
    }
  }

  // Get building statistics for color interpolation
  Future<BuildingStats> getBuildingStats() async {
    try {
      AppLogger.api('Fetching building stats from $_baseUrl/buildings/stats');
      final response = await http.get(
        Uri.parse('$_baseUrl/buildings/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      AppLogger.network('Building stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = BuildingStats.fromJson(data);

        AppLogger.api('Building stats - NJOP range: ${stats.minNjopTotal} to ${stats.maxNjopTotal}');
        return stats;
      } else {
        AppLogger.error('Failed to fetch building stats: ${response.statusCode}', tag: 'API');
        throw Exception('Failed to fetch building stats: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.api('Error fetching building stats', error: e, stackTrace: stackTrace);
      throw Exception('Error fetching building stats: ${e.toString()}');
    }
  }

  // Get buildings within a specific area (optional - for future filtering)
  Future<List<Building>> getBuildingsInArea(LatLngBounds bounds) async {
    try {
      // For now, get all buildings and filter them client-side
      // In the future, we could add a backend endpoint with spatial filtering
      final allBuildings = await getBuildings();

      final filteredBuildings = allBuildings.where((building) {
        final buildingBounds = building.getBounds();
        return _boundsIntersect(buildingBounds, bounds);
      }).toList();

      AppLogger.api('Filtered to ${filteredBuildings.length} buildings in specified area');
      return filteredBuildings;
    } catch (e, stackTrace) {
      AppLogger.api('Error filtering buildings by area', error: e, stackTrace: stackTrace);
      throw Exception('Error filtering buildings by area: ${e.toString()}');
    }
  }

  // Get tiles within a specific area (optional - for future filtering)
  Future<List<MapTile>> getTilesInArea(LatLngBounds bounds) async {
    try {
      // For now, get all tiles and filter them client-side
      // In the future, we could add a backend endpoint with spatial filtering
      final allTiles = await getTiles();

      final filteredTiles = allTiles.where((tile) {
        final tileBounds = tile.getBounds();
        return _boundsIntersect(tileBounds, bounds);
      }).toList();

      AppLogger.api('Filtered to ${filteredTiles.length} tiles in specified area');
      return filteredTiles;
    } catch (e, stackTrace) {
      AppLogger.api('Error filtering tiles by area', error: e, stackTrace: stackTrace);
      throw Exception('Error filtering tiles by area: ${e.toString()}');
    }
  }

  // Helper function to check if two bounding boxes intersect
  bool _boundsIntersect(LatLngBounds bounds1, LatLngBounds bounds2) {
    return !(bounds1.southEast.latitude < bounds2.northWest.latitude ||
             bounds1.northWest.latitude > bounds2.southEast.latitude ||
             bounds1.southEast.longitude < bounds2.northWest.longitude ||
             bounds1.northWest.longitude > bounds2.southEast.longitude);
  }
}

class LatLngBounds {
  final LatLng northWest;
  final LatLng southEast;

  LatLngBounds(this.northWest, this.southEast);

  double get north => northWest.latitude;
  double get south => southEast.latitude;
  double get west => northWest.longitude;
  double get east => southEast.longitude;
}