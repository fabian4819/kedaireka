import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  // Default location (Universitas Gadjah Mada, Yogyakarta)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-7.771043857941956, 110.37910160750407),
    zoom: 18.0,
  );

  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  bool _isLoading = true;
  MapType _mapType = MapType.hybrid; // Good for geodetic work

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
            markerId: const MarkerId('current_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(
              title: 'Current Location',
              snippet: 'You are here',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
        _isLoading = false;
      });

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 18.0,
          ),
        ),
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

  void _onMapTapped(LatLng point) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(point.toString()),
          position: point,
          infoWindow: InfoWindow(
            title: 'Survey Point',
            snippet: 'Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.hybrid ? MapType.normal : MapType.hybrid;
    });
  }

  void _clearMarkers() {
    setState(() {
      _markers.clear();
      if (_currentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(
              title: 'Current Location',
              snippet: 'You are here',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
            icon: Icon(_mapType == MapType.hybrid ? Icons.map : Icons.satellite),
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
                GoogleMap(
                  mapType: _mapType,
                  initialCameraPosition: _initialPosition,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  markers: _markers,
                  polygons: _polygons,
                  onTap: _onMapTapped,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
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