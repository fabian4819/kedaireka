class AppConstants {
  static const String appName = 'Pix2Land';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Geodetic AR Application for Land and Building Mapping';

  // Navigation Routes
  static const String splashRoute = '/';
  static const String authRoute = '/auth';
  static const String emailVerificationRoute = '/email-verification';
  static const String homeRoute = '/home';
  static const String mapsRoute = '/maps';
  static const String arRoute = '/ar';
  static const String videocallRoute = '/videocall';
  static const String buildingsRoute = '/buildings';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String projectsCollection = 'projects';
  static const String measurementsCollection = 'measurements';

  // Storage Paths
  static const String projectImagesPath = 'projects/images';
  static const String userAvatarsPath = 'users/avatars';

  // Permissions
  static const List<String> requiredPermissions = [
    'camera',
    'location',
    'storage',
    'microphone',
  ];

  // AR Constants
  static const double defaultARScale = 1.0;
  static const double minARDistance = 0.5; // meters
  static const double maxARDistance = 100.0; // meters

  // Map Constants
  static const double defaultZoom = 15.0;
  static const double defaultLatitude = -6.2088;
  static const double defaultLongitude = 106.8456; // Jakarta, Indonesia
}