import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';

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
  bool _isSatelliteView = false; // Toggle between street and satellite view

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

  void _toggleMapType() {
    setState(() {
      _isSatelliteView = !_isSatelliteView;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geodetic Maps'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_isSatelliteView ? Icons.map : Icons.satellite),
            onPressed: _toggleMapType,
            tooltip: 'Toggle Map Type',
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
                      urlTemplate: _isSatelliteView
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kedaireka.app',
                    ),
                    MarkerLayer(markers: _markers),
                    PolygonLayer(polygons: _polygons),
                  ],
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