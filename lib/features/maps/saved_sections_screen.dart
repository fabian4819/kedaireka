import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:latlong2/latlong.dart';
import '../../core/models/map_section.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';

class SavedSectionsScreen extends StatefulWidget {
  const SavedSectionsScreen({super.key});

  @override
  State<SavedSectionsScreen> createState() => _SavedSectionsScreenState();
}

class _SavedSectionsScreenState extends State<SavedSectionsScreen> {
  List<MapSection> _savedSections = [];

  @override
  void initState() {
    super.initState();
    _loadSavedSections();
  }

  void _loadSavedSections() {
    // TODO: Load from local storage
    // For now, using sample data
    setState(() {
      _savedSections = [
        MapSection(
          id: 'saved_1',
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
          isDownloaded: true,
          localPath: '/storage/sections/section_1',
        ),
        MapSection(
          id: 'saved_2',
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
          isDownloaded: true,
          localPath: '/storage/sections/section_3',
        ),
      ];
    });
  }

  void _viewSectionPreview(MapSection section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SectionPreviewScreen(section: section),
      ),
    );
  }

  void _deleteSection(MapSection section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section'),
        content: Text('Are you sure you want to delete "${section.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _savedSections.removeWhere((s) => s.id == section.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${section.name} deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Map Sections'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _savedSections.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Saved Sections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Download map sections to view them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedSections.length,
              itemBuilder: (context, index) {
                final section = _savedSections[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _viewSectionPreview(section),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      section.category.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                onPressed: () => _deleteSection(section),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            section.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _InfoChip(
                                icon: Icons.area_chart,
                                label: section.formattedArea,
                              ),
                              const SizedBox(width: 8),
                              _InfoChip(
                                icon: Icons.layers,
                                label: '${section.layers.length} layers',
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _viewSectionPreview(section),
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text('Preview'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Section Preview Screen
class _SectionPreviewScreen extends StatelessWidget {
  final MapSection section;

  const _SectionPreviewScreen({required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(section.name),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map Preview using Mapbox
          Expanded(
            flex: 2,
            child: mb.MapWidget(
              styleUri: MapboxConfig.styleUrl,
              cameraOptions: mb.CameraOptions(
                center: mb.Point(
                  coordinates: mb.Position(section.center.longitude, section.center.latitude),
                ),
                zoom: 15.0,
              ),
            ),
          ),

          // Section Details
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Section Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.description,
                      label: 'Description',
                      value: section.description,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.area_chart,
                      label: 'Area',
                      value: section.formattedArea,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.layers,
                      label: 'Layers',
                      value: section.layers.join(', '),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.category,
                      label: 'Category',
                      value: section.category,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.folder,
                      label: 'Local Path',
                      value: section.localPath ?? 'Not available',
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
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
              const SizedBox(height: 4),
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
