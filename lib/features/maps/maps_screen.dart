import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/map_tiles_service.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late mb.MapboxMap _mapboxMap;

  // Default location centered on tiles/buildings data area (Jakarta)
  static const LatLng _initialPosition = LatLng(-6.2085, 106.8205); // Center of tile/building data
  static const double _initialZoom = 14.0; // Slightly zoomed out for better tile visibility

  Position? _currentPosition;
  bool _isLoading = true;
  bool _isLoadingTiles = false;
  String _currentStyle = 'custom';
  double _currentZoom = _initialZoom;

  // Tiles and Buildings from backend
  List<MapTile> _tiles = [];
  MapTile? _selectedTile;
  bool _showTiles = true;

  // Raw GeoJSON data from backend (bypass coordinate parsing bug)
  Map<String, dynamic> _rawTilesGeoJson = {};

  @override
  void initState() {
    super.initState();
    debugPrint('🗺️ Maps Screen: initState - Starting initialization...');
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Skip location detection to always center on data area
    // await _getCurrentLocation();
    debugPrint('🗺️ Using data-centered map position: lng=${_initialPosition.longitude}, lat=${_initialPosition.latitude}');
    debugPrint('🗺️ Maps Screen: Loading tiles only...');

    // Set initial loading state to false since we're not doing location detection
    setState(() => _isLoading = false);

    await _loadTilesOnly();
    // Don't load buildings on maps screen - only on AR screen
  }

  Future<void> _loadTilesOnly() async {
    setState(() => _isLoadingTiles = true);
    try {
      debugPrint('🗺️ Maps Screen: Loading raw GeoJSON tiles data...');

      // Fetch raw tiles data directly from backend API
      const String _baseUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://pix2land-backend.vercel.app',
      );

      final response = await http.get(
        Uri.parse('$_baseUrl/tiles'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final rawGeoJson = jsonDecode(response.body);
        setState(() {
          _rawTilesGeoJson = rawGeoJson;
          _isLoadingTiles = false;
        });
        debugPrint('🗺️ Maps Screen: Loaded raw GeoJSON with ${rawGeoJson['features'].length} tiles');

        // Still load parsed tiles for UI functionality (but we won't use coordinates for rendering)
        final tiles = await MapTilesService().getTiles();
        _tiles = tiles;
      } else {
        throw Exception('Failed to load tiles: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoadingTiles = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tiles: $e')),
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
        _isLoading = false;
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
      // Use Jakarta location that's close to tiles and buildings data
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
      _isLoading = false;
    });
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _initializeLayers();
  }

  Future<void> _initializeLayers() async {
    try {
      debugPrint('🗺️ Initializing map layers...');
      debugPrint('🗺️ Available tiles: ${_tiles.length}');

      // Add current location marker if available
      if (_currentPosition != null) {
        _addCurrentLocationMarker();
      }

      // Wait for map to be fully loaded before adding layers
      await Future.delayed(const Duration(milliseconds: 1000));

      // Add tiles layer using source-layer system
      if (_tiles.isNotEmpty) {
        debugPrint('🗺️ Tiles are available, adding tiles layer...');
        await _addTilesLayer();
        debugPrint('🗺️ Tiles layer added, now centering map on tile data...');
        // Auto-center map on tile data area
        await _centerMapOnTiles();
        debugPrint('🗺️ Map centering completed');
      } else {
        debugPrint('⚠️ No tiles available to add to map');
      }

      debugPrint('🗺️ Map layers initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing map layers: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _centerMapOnTiles() async {
    try {
      debugPrint('🗺️ Auto-centering map on tile data...');

      // Calculate the center point of all tiles
      double totalLat = 0;
      double totalLng = 0;
      int count = 0;

      for (final tile in _tiles) {
        debugPrint('🗺️ DEBUG: Processing tile ID: ${tile.id}');
        debugPrint('🗺️ DEBUG: Tile coordinates length: ${tile.coordinates.length}');
        if (tile.coordinates.isNotEmpty && tile.coordinates[0].isNotEmpty && tile.coordinates[0][0].isNotEmpty) {
          debugPrint('🗺️ DEBUG: First coordinate point: ${tile.coordinates[0][0][0]}, ${tile.coordinates[0][0][1]}');
        }
        final center = tile.getCenter();
        debugPrint('🗺️ DEBUG: Tile ${tile.id} center: ${center.latitude}, ${center.longitude}');
        totalLat += center.latitude;
        totalLng += center.longitude;
        count++;

        // Only process first 5 tiles to avoid log spam
        if (count >= 5) {
          debugPrint('🗺️ DEBUG: Processing remaining ${_tiles.length - 5} tiles silently...');
          // Calculate the rest without detailed logging
          for (int i = 5; i < _tiles.length; i++) {
            final tile = _tiles[i];
            final center = tile.getCenter();
            totalLat += center.latitude;
            totalLng += center.longitude;
            count++;
          }
          break;
        }
      }

      if (count > 0) {
        final centerLat = totalLat / count;
        final centerLng = totalLng / count;

        debugPrint('🗺️ Calculated tile center: lat=$centerLat, lng=$centerLng');

        // If center is at 0,0 (null island), use fallback coordinates
        final targetLat = centerLat == 0.0 ? _initialPosition.latitude : centerLat;
        final targetLng = centerLng == 0.0 ? _initialPosition.longitude : centerLng;

        debugPrint('🗺️ Target center: lat=$targetLat, lng=$targetLng');
        debugPrint('🗺️ Fallback position: lat=${_initialPosition.latitude}, lng=${_initialPosition.longitude}');

        // Center the map on the tile data
        final cameraOptions = mb.CameraOptions(
          center: mb.Point(
            coordinates: mb.Position(targetLng, targetLat),
          ),
          zoom: _initialZoom,
          pitch: 45.0,
        );

        await _mapboxMap.setCamera(cameraOptions);
        debugPrint('🗺️ Map centered on tile data successfully');
      } else {
        debugPrint('⚠️ No tiles to center on');
      }
    } catch (e) {
      debugPrint('❌ Error centering map on tiles: $e');
    }
  }

  // Helper method to convert tiles to GeoJSON
  Map<String, dynamic> _tilesToGeoJson() {
    final features = _tiles.map((tile) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': tile.coordinates,
      },
      'properties': {
        'id': tile.id,
        ...tile.properties,
        'isSaved': tile.isSaved,
      }
    }).toList();

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  void _checkTileSelection(LatLng point) {
    debugPrint('🗺️ Checking tile selection at: ${point.latitude}, ${point.longitude}');

    // Check if we have raw GeoJSON data to use for more accurate selection
    if (_rawTilesGeoJson.isNotEmpty) {
      final features = _rawTilesGeoJson['features'] as List<dynamic>;
      for (final feature in features) {
        if (_isPointInGeoJSONFeature(point, feature)) {
          // Find the corresponding tile object
          final tileId = feature['properties']['id'] as int;
          final tile = _tiles.firstWhere(
            (t) => t.id == tileId,
            orElse: () => MapTile(
              id: tileId,
              coordinates: [],
              properties: feature['properties'] as Map<String, dynamic>? ?? {},
            ),
          );

          setState(() {
            _selectedTile = tile;
          });
          debugPrint('🗺️ Selected tile ID: ${tile.id}');
          _showTileInfo(tile);
          return;
        }
      }
    } else {
      // Fallback to using parsed tile data
      for (final tile in _tiles) {
        final bounds = tile.getBounds();
        if (_isPointInBounds(point, bounds)) {
          setState(() {
            _selectedTile = tile;
          });
          _showTileInfo(tile);
          break;
        }
      }
    }

    debugPrint('🗺️ No tile selected at this position');
  }

  // Check if a point is within a GeoJSON polygon feature
  bool _isPointInGeoJSONFeature(LatLng point, dynamic feature) {
    try {
      final geometry = feature['geometry'];
      if (geometry['type'] == 'Polygon') {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        if (coordinates.isNotEmpty) {
          final ring = coordinates[0] as List<dynamic>;
          return _isPointInPolygonRing(point, ring);
        }
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

  Future<void> _addTilesLayer() async {
    try {
      debugPrint('🗺️ Adding tiles layer using raw GeoJSON data...');

      if (_rawTilesGeoJson.isEmpty) {
        debugPrint('❌ No raw GeoJSON data available');
        return;
      }

      debugPrint('🗺️ Using raw GeoJSON with ${_rawTilesGeoJson['features'].length} tiles');

      // Add source for tiles using raw GeoJSON data (bypasses coordinate parsing bug)
      final tileSource = mb.GeoJsonSource(
        id: "tiles-source",
        data: jsonEncode(_rawTilesGeoJson),
      );
      debugPrint('🗺️ Adding raw GeoJSON source...');
      await _mapboxMap.style.addSource(tileSource);
      debugPrint('🗺️ Raw GeoJSON source added successfully');

      // Add outline layer for better contrast
      final tileOutlineLayer = mb.LineLayer(
        id: "tiles-outline-layer",
        sourceId: "tiles-source",
        lineOpacity: 1.0,
        lineColor: Colors.black.value,
        lineWidth: 3.0, // Thick black outline for maximum contrast
      );
      debugPrint('🗺️ Adding outline layer for contrast...');
      await _mapboxMap.style.addLayer(tileOutlineLayer);
      debugPrint('🗺️ Outline layer added successfully');

      // Add layer for tiles using FillLayer with high visibility for testing
      final tileLayer = mb.FillLayer(
        id: "tiles-layer",
        sourceId: "tiles-source",
        fillOpacity: 0.8, // Make tiles very visible
        fillColor: Colors.red.value, // Use bright red color for high contrast
        // Remove outline to simplify
      );
      debugPrint('🗺️ Adding fill layer with high visibility...');
      await _mapboxMap.style.addLayer(tileLayer);
      debugPrint('🗺️ Fill layer added successfully');

      // TODO: Implement click listener for tile selection
      // Click functionality requires proper Mapbox Mapbox Maps Flutter SDK implementation
      debugPrint('🗺️ TODO: Add tile click listener');

      debugPrint('✅ Tiles layer added successfully using raw GeoJSON data!');
    } catch (e) {
      debugPrint('❌ Error adding tiles layer: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _addCurrentLocationMarker() async {
    // TODO: Implement point annotation for current location marker
    // For now, we'll skip this as it's not essential for the tiles display
    if (_currentPosition != null) {
      debugPrint('📍 Current location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedTile = null;
    });
  }

  void _showTileInfo(MapTile tile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TileInfoSheet(
        tile: tile,
        onSave: () => _saveTile(tile),
      ),
    );
  }

  void _saveTile(MapTile tile) {
    // TODO: Implement save functionality
    setState(() {
      tile.isSaved = true;
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tile ${tile.id} saved successfully!')),
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
  }

  Future<void> _toggleTiles() async {
    setState(() {
      _showTiles = !_showTiles;
    });

    try {
      // For now, just log the toggle - we'll implement visibility after getting basic layer working
      debugPrint('🗺️ Tiles visibility toggled to: $_showTiles');
    } catch (e) {
      debugPrint('❌ Error toggling tiles layer: $e');
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
        // Use light-v11 style like the working JavaScript example
        return 'mapbox://styles/mapbox/light-v11';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Map'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showTiles ? Icons.grid_on : Icons.grid_off),
            onPressed: _toggleTiles,
            tooltip: _showTiles ? 'Hide Tiles' : 'Show Tiles',
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
            onPressed: _loadTilesOnly,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading || _isLoadingTiles
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map data...'),
                ],
              ),
            )
          : Stack(
              children: [
                mb.MapWidget(
                  key: ValueKey('mapbox_map_$_currentStyle'),
                  onMapCreated: _onMapCreated,
                  styleUri: _getStyleUri(),
                  onTapListener: (context) {
                    final point = context.point;
                    debugPrint('🗺️ Map clicked at: ${point.coordinates.lat}, ${point.coordinates.lng}');
                    _checkTileSelection(LatLng(point.coordinates.lat.toDouble(), point.coordinates.lng.toDouble()));
                  },
                  cameraOptions: mb.CameraOptions(
                    center: mb.Point(
                      coordinates: mb.Position(
                        _initialPosition.longitude,
                        _initialPosition.latitude,
                      ),
                    ),
                    zoom: _initialZoom,
                    pitch: 45.0,
                  ),
                ),

                // Loading indicator for tiles
                if (_isLoadingTiles)
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
                          Text('Loading tiles...', style: TextStyle(color: Colors.white)),
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
                          'Maps Screen:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Displaying ${_tiles.length} tiles from backend API',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• Toggle tiles visibility with grid icon',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '• Change map style with layers icon',
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

// Tile Information Modal Widget
class _TileInfoSheet extends StatelessWidget {
  final MapTile tile;
  final VoidCallback onSave;

  const _TileInfoSheet({
    required this.tile,
    required this.onSave,
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

          // Tile Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.grid_on,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tile #${tile.id}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tile.isSaved ? 'Saved' : 'Available',
                        style: TextStyle(
                          fontSize: 12,
                          color: tile.isSaved ? Colors.green : Colors.grey[600],
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
                    onPressed: tile.isSaved ? null : onSave,
                    icon: Icon(
                      tile.isSaved ? Icons.check_circle : Icons.save,
                    ),
                    label: Text(
                      tile.isSaved ? 'Saved' : 'Save Tile',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tile.isSaved ? Colors.grey : AppTheme.primaryColor,
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
        Icon(icon, size: 18, color: AppTheme.primaryColor),
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