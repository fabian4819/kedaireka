import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import '../../core/services/map_tiles_service.dart' as map_service;
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/bloc/auth_state.dart';
import '../../core/services/map_tiles_service.dart';
import '../../core/services/storage_service.dart';

// Helper widget for info rows to avoid scoping issues
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '$label:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 100,
              ),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Profile Picture
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: state.user.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      state.user.photoURL!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: AppTheme.primaryColor,
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppTheme.primaryColor,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // User Name
                        Text(
                          state.user.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // User Email
                        Text(
                          state.user.email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Profile Stats
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          icon: Icons.folder,
                          label: 'Projects',
                          value: '12',
                          color: AppTheme.primaryColor,
                        ),
                        _StatCard(
                          icon: Icons.grid_on,
                          label: 'Tiles Saved',
                          value: '8',
                          color: AppTheme.accentColor,
                        ),
                        _StatCard(
                          icon: Icons.location_city,
                          label: 'Buildings',
                          value: '15',
                          color: AppTheme.successColor,
                        ),
                      ],
                    ),
                  ),

                  // Saved Items Section
                  SavedItemsSection(),

                  // Profile Options
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ProfileOption(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: () {
                            // TODO: Navigate to edit profile
                          },
                        ),
                        const Divider(height: 1),
                        _ProfileOption(
                          icon: Icons.location_city_outlined,
                          title: 'Buildings Map',
                          onTap: () {
                            context.go(AppConstants.buildingsRoute);
                          },
                        ),
                        const Divider(height: 1),
                        _ProfileOption(
                          icon: Icons.map_outlined,
                          title: 'Saved Map Sections',
                          onTap: () {
                            context.push('/saved-sections');
                          },
                        ),
                        const Divider(height: 1),
                        _ProfileOption(
                          icon: Icons.location_city_outlined,
                          title: 'Saved Buildings',
                          onTap: () {
                            context.go(AppConstants.buildingsRoute);
                          },
                        ),
                        const Divider(height: 1),
                        _ProfileOption(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          onTap: () {
                            // TODO: Navigate to notifications
                          },
                        ),
                        const Divider(height: 1),
                        _ProfileOption(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: () {
                            // TODO: Navigate to help
                          },
                        ),
                        const Divider(height: 1),
                        _ProfileOption(
                          icon: Icons.info_outline,
                          title: 'About',
                          onTap: () {
                            _showAboutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showLogoutDialog(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }


  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Pix2Land'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pix2Land - Geodetic AR Application',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Version ${AppConstants.appVersion}'),
            const SizedBox(height: 16),
            const Text(
              'Advanced land and building mapping using AR technology and geodetic precision.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// Saved Items Section Widget
class SavedItemsSection extends StatefulWidget {
  const SavedItemsSection({super.key});

  @override
  State<SavedItemsSection> createState() => _SavedItemsSectionState();
}

class _SavedItemsSectionState extends State<SavedItemsSection> {
  List<MapTile> _savedTiles = [];
  List<Building> _savedBuildings = [];
  bool _isLoading = false;

  // Raw GeoJSON data for tiles (like maps screen)
  Map<String, dynamic> _rawTilesGeoJson = {};

  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }

  // Show tile preview modal
  void _showTilePreview(BuildContext context, MapTile tile) {
    // Find the raw feature data for this tile
    dynamic rawFeature;
    if (_rawTilesGeoJson.isNotEmpty) {
      final features = _rawTilesGeoJson['features'] as List<dynamic>;
      rawFeature = features.firstWhere(
        (feature) => feature['properties']['id'] == tile.id,
        orElse: () => null,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
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

            // Tile Header
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
                          'Saved Tile',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mapbox Preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: mb.MapWidget(
                    onMapCreated: (mb.MapboxMap mapboxMap) {
                      // Add tile highlight layer using raw feature data
                      _addTileHighlight(mapboxMap, rawFeature);
                    },
                    styleUri: 'mapbox://styles/mapbox/light-v11',
                    cameraOptions: mb.CameraOptions(
                      center: mb.Point(
                        coordinates: mb.Position(
                          _getTileCenter(rawFeature)?.longitude ?? 106.8,
                          _getTileCenter(rawFeature)?.latitude ?? -6.2,
                        ),
                      ),
                      zoom: 16.0, // Optimal zoom level for tile visibility
                      pitch: 0.0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/maps?tileId=${tile.id}');
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
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
      ),
    );
  }

  // Get tile center from raw feature data
  LatLng? _getTileCenter(dynamic rawFeature) {
    try {
      if (rawFeature == null || rawFeature['geometry'] == null) {
        return null;
      }

      final coordinates = rawFeature['geometry']['coordinates'];
      if (coordinates is List && coordinates.isNotEmpty) {
        final firstRing = coordinates[0] as List;
        if (firstRing.isNotEmpty) {
          double totalLat = 0;
          double totalLng = 0;
          int count = 0;

          for (final point in firstRing) {
            if (point is List && point.length >= 2) {
              totalLng += (point[0] as num).toDouble(); // longitude
              totalLat += (point[1] as num).toDouble(); // latitude
              count++;
            }
          }

          if (count > 0) {
            return LatLng(totalLat / count, totalLng / count);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting tile center: $e');
      return null;
    }
  }

  // Add tile highlight to map
  void _addTileHighlight(mb.MapboxMap mapboxMap, dynamic rawFeature) {
    try {
      if (rawFeature == null || rawFeature['geometry'] == null) {
        debugPrint('No valid feature data for tile highlight');
        return;
      }

      // Create a GeoJSON source for the tile using raw feature data
      final tileGeoJson = {
        "type": "FeatureCollection",
        "features": [rawFeature]
      };

      debugPrint('🗺️ Adding tile highlight for feature: ${rawFeature['properties']['id']}');

      // Add source
      final source = mb.GeoJsonSource(
        id: "tile-highlight-source",
        data: jsonEncode(tileGeoJson),
      );
      mapboxMap.style.addSource(source);

      // Add fill layer - more prominent at higher zoom
      final fillLayer = mb.FillLayer(
        id: "tile-highlight-fill",
        sourceId: "tile-highlight-source",
        fillOpacity: 0.4, // Increased opacity for better visibility
        fillColor: AppTheme.primaryColor.value,
      );
      mapboxMap.style.addLayer(fillLayer);

      // Add outline layer - thicker at higher zoom
      final outlineLayer = mb.LineLayer(
        id: "tile-highlight-outline",
        sourceId: "tile-highlight-source",
        lineOpacity: 1.0,
        lineColor: AppTheme.primaryColor.value,
        lineWidth: 3.0, // Thicker line for better visibility at zoom 18
      );
      mapboxMap.style.addLayer(outlineLayer);

      debugPrint('✅ Tile highlight added successfully');
    } catch (e) {
      debugPrint('❌ Error adding tile highlight: $e');
    }
  }

  // Show building preview modal
  void _showBuildingPreview(BuildContext context, Building building) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
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
                            'Saved Building',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Financial Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.attach_money,
                      label: 'NJOP Value',
                      value: building.formattedNjop,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hazard Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.local_fire_department,
                      label: 'Fire Hazard',
                      value: building.fireHazard?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.flood,
                      label: 'Flood Hazard',
                      value: building.floodHazard?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.warning,
                      label: 'Total Hazard',
                      value: building.hazardSum?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Location Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.my_location,
                      label: 'Latitude',
                      value: building.getCenter().latitude.toStringAsFixed(6),
                    ),
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.my_location,
                      label: 'Longitude',
                      value: building.getCenter().longitude.toStringAsFixed(6),
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
                        onPressed: () => Navigator.pop(context),
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
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/ar?buildingId=${building.id}');
                        },
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('View in AR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
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
        ),
      ),
    );
  }

  // Helper methods for location details
  String _getBoundsString(map_service.LatLngBounds bounds) {
    return '${bounds.south.toStringAsFixed(4)}, ${bounds.west.toStringAsFixed(4)} → ${bounds.north.toStringAsFixed(4)}, ${bounds.east.toStringAsFixed(4)}';
  }

  String _calculateAreaDescription(map_service.LatLngBounds bounds) {
    final latDiff = bounds.north - bounds.south;
    final lngDiff = bounds.east - bounds.west;

    if (latDiff < 0.001 && lngDiff < 0.001) {
      return 'Very Small (< 0.001°²)';
    } else if (latDiff < 0.01 && lngDiff < 0.01) {
      return 'Small (~${(latDiff * lngDiff * 1000).toStringAsFixed(1)} units²)';
    } else if (latDiff < 0.1 && lngDiff < 0.1) {
      return 'Medium (~${(latDiff * lngDiff * 100).toStringAsFixed(1)} units²)';
    } else {
      return 'Large (~${(latDiff * lngDiff).toStringAsFixed(2)} units²)';
    }
  }

  void _showSavedBuildings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
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

              // Header
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Buildings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'View and manage your saved buildings',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Saved Buildings List
              Expanded(
                child: _savedBuildings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved buildings yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Save buildings from the Buildings Map to see them here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.go(AppConstants.buildingsRoute);
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Browse Buildings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _savedBuildings.length,
                        itemBuilder: (context, index) {
                          final building = _savedBuildings[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _showBuildingPreview(context, building),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.location_city,
                                        color: AppTheme.accentColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Building #${building.id}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'NJOP Value: ${building.formattedNjop}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              if (building.fireHazard != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Fire: ${building.fireHazard!.toStringAsFixed(1)}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.orange,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              if (building.floodHazard != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Flood: ${building.floodHazard!.toStringAsFixed(1)}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.blue,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Saved',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSavedItems() async {
    setState(() => _isLoading = true);
    try {
      // Load raw tiles GeoJSON data first
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
        });
        print('✅ Loaded raw tiles GeoJSON with ${rawGeoJson['features'].length} tiles');
      }

      // Get actual tiles and buildings from API
      final results = await Future.wait([
        MapTilesService().getTiles(),
        MapTilesService().getBuildings(),
      ]);
      final tiles = results[0] as List<MapTile>;
      final buildings = results[1] as List<Building>;

      // Get saved items from storage service
      final savedTiles = await StorageService().getSavedTiles(tiles);
      final savedBuildings = await StorageService().getSavedBuildings(buildings);

      setState(() {
        _savedTiles = savedTiles;
        _savedBuildings = savedBuildings;
        _isLoading = false;
      });

      print('✅ Loaded ${savedTiles.length} saved tiles and ${savedBuildings.length} saved buildings from storage');
    } catch (e) {
      print('❌ Error loading saved items: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading saved items...'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Saved Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full saved items page
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),

        // Saved Tiles Preview
        if (_savedTiles.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Saved Tiles',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _savedTiles.length,
              itemBuilder: (context, index) {
                final tile = _savedTiles[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: _SavedTileCard(
                    tile: tile,
                    onTap: () => _showTilePreview(context, tile),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Saved Buildings Preview
        if (_savedBuildings.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Saved Buildings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _savedBuildings.length,
              itemBuilder: (context, index) {
                final building = _savedBuildings[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: _SavedBuildingCard(
                    building: building,
                    onTap: () => _showBuildingPreview(context, building),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_savedTiles.isEmpty && _savedBuildings.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No saved items yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start exploring and save tiles and buildings from the map',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to maps
                    context.go('/maps');
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Explore Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// Saved Tile Card Widget
class _SavedTileCard extends StatelessWidget {
  final MapTile tile;
  final VoidCallback onTap;

  const _SavedTileCard({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tile Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.grid_on,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              // Tile Info
              Text(
                'Tile #${tile.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Spacer(),
              // Saved Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Saved',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Saved Building Card Widget
class _SavedBuildingCard extends StatelessWidget {
  final Building building;
  final VoidCallback onTap;

  const _SavedBuildingCard({required this.building, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Building Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_city,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              // Building Info
              Text(
                'Building #${building.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'NJOP: ${building.formattedNjop}',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                'Fire: ${building.fireHazard?.toStringAsFixed(1) ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Saved Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Saved',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}