import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/models/map_section.dart';

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

  // WMS Sections
  List<MapSection> _sections = [];
  MapSection? _selectedSection;
  bool _showSections = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSections();
  }

  void _loadSections() {
    // Sample WMS sections data - Replace with actual WMS data
    setState(() {
      _sections = [
        MapSection(
          id: 'section_1',
          name: 'UGM Campus Area',
          description: 'Main campus area including faculty buildings and facilities',
          bounds: MapSectionBounds(
            north: -7.768,
            south: -7.775,
            east: 110.383,
            west: 110.375,
          ),
          wmsUrl: 'https://example.com/wms',
          layers: ['cadastral', 'buildings'],
          area: 125000,
          category: 'cadastral',
          lastUpdated: DateTime.now().subtract(const Duration(days: 5)),
        ),
        MapSection(
          id: 'section_2',
          name: 'Northern District',
          description: 'Residential and commercial zones',
          bounds: MapSectionBounds(
            north: -7.761,
            south: -7.768,
            east: 110.383,
            west: 110.375,
          ),
          wmsUrl: 'https://example.com/wms',
          layers: ['land_use', 'roads'],
          area: 98500,
          category: 'land_use',
          lastUpdated: DateTime.now().subtract(const Duration(days: 12)),
        ),
        MapSection(
          id: 'section_3',
          name: 'Southern Green Area',
          description: 'Parks and recreational spaces',
          bounds: MapSectionBounds(
            north: -7.768,
            south: -7.775,
            east: 110.391,
            west: 110.383,
          ),
          wmsUrl: 'https://example.com/wms',
          layers: ['topographic', 'vegetation'],
          area: 76300,
          category: 'topographic',
          lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
        ),
        MapSection(
          id: 'section_4',
          name: 'Eastern Development Zone',
          description: 'Planned development area with infrastructure',
          bounds: MapSectionBounds(
            north: -7.754,
            south: -7.761,
            east: 110.391,
            west: 110.383,
          ),
          wmsUrl: 'https://example.com/wms',
          layers: ['planning', 'infrastructure'],
          area: 142000,
          category: 'planning',
          lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    });
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

  void _onMapTapped(mb.ScreenCoordinate coordinate) {
    // For now, just add a marker at the current position
    if (_currentPosition != null) {
      final latLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      _addMapMarker(latLng);
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

  bool _isPointInBounds(LatLng point, MapSectionBounds bounds) {
    return point.latitude >= bounds.south &&
           point.latitude <= bounds.north &&
           point.longitude >= bounds.west &&
           point.longitude <= bounds.east;
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

  void _selectSection(MapSection section) {
    setState(() {
      _selectedSection = section;
    });
    _showSectionInfo(section);
  }

  void _showSectionInfo(MapSection section) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SectionInfoSheet(
        section: section,
        onDownload: () => _downloadSection(section),
      ),
    );
  }

  void _downloadSection(MapSection section) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${section.name}...'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Navigate to downloads
          },
        ),
      ),
    );
    // TODO: Implement actual download logic
  }

  void _toggleSectionsVisibility() {
    setState(() {
      _showSections = !_showSections;
    });
  }

  List<Polygon> _buildSectionPolygons() {
    if (!_showSections) return [];

    return _sections.map((section) {
      final isSelected = _selectedSection?.id == section.id;
      return Polygon(
        points: [
          LatLng(section.bounds.south, section.bounds.west),
          LatLng(section.bounds.north, section.bounds.west),
          LatLng(section.bounds.north, section.bounds.east),
          LatLng(section.bounds.south, section.bounds.east),
        ],
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.3)
            : Colors.blue.withOpacity(0.15),
        borderColor: isSelected ? AppTheme.primaryColor : Colors.blue,
        borderStrokeWidth: isSelected ? 3 : 2,
        isFilled: true,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geodetic Maps'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showSections ? Icons.layers : Icons.layers_outlined),
            onPressed: _toggleSectionsVisibility,
            tooltip: _showSections ? 'Hide Sections' : 'Show Sections',
          ),
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
              ],
            ),
    );
  }
}

// Section Information Bottom Sheet Widget
class _SectionInfoSheet extends StatelessWidget {
  final MapSection section;
  final VoidCallback onDownload;

  const _SectionInfoSheet({
    required this.section,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
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

          // Section Title
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
                    Icons.map,
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
                        section.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        section.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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

          // Section Details
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
                  icon: Icons.description,
                  label: 'Description',
                  value: section.description,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.area_chart,
                  label: 'Area',
                  value: section.formattedArea,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.layers,
                  label: 'Layers',
                  value: section.layers.join(', '),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.update,
                  label: 'Last Updated',
                  value: _formatDate(section.lastUpdated),
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
                    onPressed: section.isDownloaded ? null : onDownload,
                    icon: Icon(
                      section.isDownloaded ? Icons.check_circle : Icons.download,
                    ),
                    label: Text(
                      section.isDownloaded ? 'Downloaded' : 'Download Section',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: section.isDownloaded
                          ? Colors.grey
                          : AppTheme.primaryColor,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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