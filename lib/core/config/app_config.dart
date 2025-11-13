class AppConfig {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static String get baseUrl => _baseUrl;
}

class AuthEndpoints {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
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