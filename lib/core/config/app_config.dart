class AppConfig {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pix2land-backend.vercel.app/api/v1',
  );

  static String get baseUrl => _baseUrl;

  // Mapbox Configuration
  static const String mapboxAccessToken = 'pk.eyJ1IjoiZ2VudGlhd2FuIiwiYSI6ImNseDdoZjBsdDByYTUya3BtdmNmd25nMHQifQ.rLQeC_xQRZFBFKI_jzM69Q';
  static const String mapboxStyleUrl = 'mapbox://styles/gentiawan/cmi0jt9z6004t01qxgji18024';
}

class MapboxConfig {
  static const String accessToken = AppConfig.mapboxAccessToken;
  static const String styleUrl = AppConfig.mapboxStyleUrl;

  // Additional Mapbox styles for switching
  static const String satelliteStyle = 'mapbox://styles/mapbox/satellite-v9';
  static const String streetStyle = 'mapbox://styles/mapbox/streets-v12';
  static const String lightStyle = 'mapbox://styles/mapbox/light-v11';
  static const String darkStyle = 'mapbox://styles/mapbox/dark-v11';

  // 3D Building Extrusion Configuration
  static const double defaultExtrusionHeight = 100.0; // meters - increased for visibility
  static const double defaultExtrusionBase = 0.0; // ground level
  static const double defaultExtrusionOpacity = 0.9; // Increased opacity
  static const int defaultBuildingColor = 0xFFFF0000; // Red color in hex

  // Camera settings for optimal 3D viewing
  static const double default3DPitch = 60.0; // degrees - increased for better 3D effect
  static const double default3DZoom = 15.0;   // slightly zoomed out for better 3D perspective
  static const double min3DZoom = 14.0;        // minimum zoom for 3D viewing
  static const double max3DZoom = 18.0;        // maximum zoom for 3D viewing
}

class AuthEndpoints {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pix2land-backend.vercel.app/api/v1',
  );

  static const String baseUrl = _baseUrl;

  static const String register = '$_baseUrl/auth/register';
  static const String login = '$_baseUrl/auth/login';
  static const String google = '$_baseUrl/auth/google';
  static const String logout = '$_baseUrl/auth/logout';
  static const String refreshToken = '$_baseUrl/auth/refresh-token';
  static const String me = '$_baseUrl/auth/me';
  static const String forgotPassword = '$_baseUrl/auth/forgot-password';
  static const String sendVerification = '$_baseUrl/auth/send-verification';
}