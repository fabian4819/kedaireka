import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/map_section.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final MapController _mapController = MapController();

  // Default location (Universitas Gadjah Mada, Yogyakarta)
  static const LatLng _initialPosition = LatLng(-7.771043857941956, 110.37910160750407);
  static const double _initialZoom = 18.0;

  Position? _currentPosition;
  List<Marker> _markers = [];
  List<Polygon> _polygons = [];
  bool _isLoading = true;
  String _mapType = 'osm'; // Options: 'osm', 'satellite', 'esri_topo'

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
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _markers.add(
          Marker(
            point: LatLng(position.latitude, position.longitude),
            width: 80,
            height: 80,
            child: const Column(
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 40),
                Text(
                  'You are here',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
        _isLoading = false;
      });

      _mapController.move(
        LatLng(position.latitude, position.longitude),
        18.0,
      );
    } catch (e) {
      _showLocationError('Error getting location: $e');
    }
  }

  void _showLocationError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    // Check if tap is within any section
    for (var section in _sections) {
      if (_isPointInBounds(point, section.bounds)) {
        _selectSection(section);
        return;
      }
    }

    // If not in any section, add a marker
    setState(() {
      _markers.add(
        Marker(
          point: point,
          width: 80,
          height: 80,
          child: Column(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 40),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Text(
                  'Lat: ${point.latitude.toStringAsFixed(6)}\nLng: ${point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 8),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  bool _isPointInBounds(LatLng point, MapSectionBounds bounds) {
    return point.latitude >= bounds.south &&
           point.latitude <= bounds.north &&
           point.longitude >= bounds.west &&
           point.longitude <= bounds.east;
  }

  void _toggleMapType() {
    setState(() {
      if (_mapType == 'osm') {
        _mapType = 'satellite';
      } else if (_mapType == 'satellite') {
        _mapType = 'esri_topo';
      } else {
        _mapType = 'osm';
      }
    });
  }

  String _getMapTypeName() {
    switch (_mapType) {
      case 'satellite':
        return 'Satellite';
      case 'esri_topo':
        return 'ESRI Topo';
      default:
        return 'Street';
    }
  }

  IconData _getMapTypeIcon() {
    switch (_mapType) {
      case 'satellite':
        return Icons.satellite;
      case 'esri_topo':
        return Icons.terrain;
      default:
        return Icons.map;
    }
  }

  void _clearMarkers() {
    setState(() {
      _markers.clear();
      if (_currentPosition != null) {
        _markers.add(
          Marker(
            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            width: 80,
            height: 80,
            child: const Column(
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 40),
                Text(
                  'You are here',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  void _selectSection(MapSection section) {
    setState(() {
      _selectedSection = section;
    });
    _mapController.move(section.center, 15.0);
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
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialPosition,
                    initialZoom: _initialZoom,
                    onTap: _onMapTapped,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _mapType == 'satellite'
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : _mapType == 'esri_topo'
                              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}'
                              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kedaireka.app',
                    ),
                    PolygonLayer(polygons: [..._polygons, ..._buildSectionPolygons()]),
                    MarkerLayer(markers: _markers),
                  ],
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