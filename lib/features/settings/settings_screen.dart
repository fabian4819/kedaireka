import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoBackup = false;
  String _mapType = 'Standard';
  String _measurementUnit = 'Metric';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // App Settings Section
          _SectionHeader(title: 'App Settings'),
          _SettingTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Enable push notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
          ),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Enable dark theme',
            trailing: Switch(
              value: _darkModeEnabled,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
                // TODO: Implement theme switching
              },
            ),
          ),

          const Divider(height: 32),

          // Location & Maps Section
          _SectionHeader(title: 'Location & Maps'),
          _SettingTile(
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            subtitle: 'Allow app to access your location',
            trailing: Switch(
              value: _locationEnabled,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _locationEnabled = value;
                });
              },
            ),
          ),
          _SettingTile(
            icon: Icons.map_outlined,
            title: 'Map Type',
            subtitle: _mapType,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showMapTypeDialog();
            },
          ),
          _SettingTile(
            icon: Icons.straighten,
            title: 'Measurement Units',
            subtitle: _measurementUnit,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showMeasurementUnitDialog();
            },
          ),

          const Divider(height: 32),

          // Data & Storage Section
          _SectionHeader(title: 'Data & Storage'),
          _SettingTile(
            icon: Icons.backup_outlined,
            title: 'Auto Backup',
            subtitle: 'Automatically backup projects',
            trailing: Switch(
              value: _autoBackup,
              activeColor: AppTheme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _autoBackup = value;
                });
              },
            ),
          ),
          _SettingTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup Now',
            subtitle: 'Manually backup all data',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showBackupDialog();
            },
          ),
          _SettingTile(
            icon: Icons.storage_outlined,
            title: 'Storage',
            subtitle: 'Manage app storage',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showStorageInfo();
            },
          ),

          const Divider(height: 32),

          // AR Settings Section
          _SectionHeader(title: 'AR Settings'),
          _SettingTile(
            icon: Icons.view_in_ar_outlined,
            title: 'AR Quality',
            subtitle: 'High',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show AR quality options
            },
          ),
          _SettingTile(
            icon: Icons.camera_outlined,
            title: 'Camera Settings',
            subtitle: 'Configure AR camera',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to camera settings
            },
          ),

          const Divider(height: 32),

          // Account Section
          _SectionHeader(title: 'Account'),
          _SettingTile(
            icon: Icons.security_outlined,
            title: 'Privacy',
            subtitle: 'Manage privacy settings',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to privacy settings
            },
          ),
          _SettingTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your password',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to change password
            },
          ),

          const Divider(height: 32),

          // About Section
          _SectionHeader(title: 'About'),
          _SettingTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: AppConstants.appVersion,
            trailing: const SizedBox.shrink(),
          ),
          _SettingTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show terms of service
            },
          ),
          _SettingTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showMapTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Map Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadioOption(
              title: 'Standard',
              value: 'Standard',
              groupValue: _mapType,
              onChanged: (value) {
                setState(() => _mapType = value!);
                Navigator.pop(context);
              },
            ),
            _RadioOption(
              title: 'Satellite',
              value: 'Satellite',
              groupValue: _mapType,
              onChanged: (value) {
                setState(() => _mapType = value!);
                Navigator.pop(context);
              },
            ),
            _RadioOption(
              title: 'Hybrid',
              value: 'Hybrid',
              groupValue: _mapType,
              onChanged: (value) {
                setState(() => _mapType = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMeasurementUnitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Measurement Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadioOption(
              title: 'Metric (m, km)',
              value: 'Metric',
              groupValue: _measurementUnit,
              onChanged: (value) {
                setState(() => _measurementUnit = value!);
                Navigator.pop(context);
              },
            ),
            _RadioOption(
              title: 'Imperial (ft, mi)',
              value: 'Imperial',
              groupValue: _measurementUnit,
              onChanged: (value) {
                setState(() => _measurementUnit = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Data'),
        content: const Text('Do you want to backup all your projects and data now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement backup
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup started...')),
              );
            },
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StorageItem('Projects', '45.2 MB'),
            _StorageItem('Images', '128.5 MB'),
            _StorageItem('Cache', '23.1 MB'),
            const Divider(),
            _StorageItem('Total', '196.8 MB', bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Clear cache
            },
            child: const Text('Clear Cache'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _RadioOption extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      activeColor: AppTheme.primaryColor,
      onChanged: onChanged,
    );
  }
}

class _StorageItem extends StatelessWidget {
  final String label;
  final String size;
  final bool bold;

  const _StorageItem(this.label, this.size, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            size,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
