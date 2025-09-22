import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
        // Back button will be automatically added by Flutter
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit project
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share project
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.architecture,
                          color: AppTheme.primaryColor,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sample Project',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Land Measurement Project',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow('Area', '1.2 hectares'),
                    _InfoRow('Location', 'Jakarta, Indonesia'),
                    _InfoRow('Created', '2024-01-15'),
                    _InfoRow('Status', 'Completed'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Measurements Section
            const Text(
              'Measurements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.straighten, color: AppTheme.accentColor),
                    title: const Text('Perimeter'),
                    subtitle: const Text('Total boundary length'),
                    trailing: const Text('450.5 m'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.crop_free, color: AppTheme.successColor),
                    title: const Text('Area'),
                    subtitle: const Text('Total land area'),
                    trailing: const Text('12,000 m²'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.height, color: AppTheme.secondaryColor),
                    title: const Text('Elevation'),
                    subtitle: const Text('Average elevation'),
                    trailing: const Text('125.3 m'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions Section
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Export to PDF
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: View on AR
                    },
                    icon: const Icon(Icons.view_in_ar),
                    label: const Text('View in AR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}