import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../config/app_config.dart';
import '../utils/logger.dart';
import '../models/backend_user_model.dart';

class BackendAuthService {
  static final BackendAuthService _instance = BackendAuthService._internal();
  factory BackendAuthService() => _instance;
  BackendAuthService._internal();

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _authProviderKey = 'auth_provider';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  BackendUser? _currentUser;
  String? _authProvider;
  BackendUser? get currentUser => _currentUser;
  String? get authProvider => _authProvider;

  // Stream for authentication state changes
  final StreamController<BackendUser?> _authStateController = StreamController<BackendUser?>.broadcast();
  Stream<BackendUser?> get authStateChanges => _authStateController.stream;

  // Initialize service and check for existing session
  Future<void> initialize() async {
    AppLogger.auth('Initializing backend auth service...');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userDataJson = prefs.getString(_userDataKey);

    if (token != null && userDataJson != null) {
      try {
        AppLogger.auth('Found existing session, restoring user data...');
        final userData = jsonDecode(userDataJson);
        _currentUser = BackendUser.fromJson(userData);
        _authProvider = prefs.getString(_authProviderKey) ?? 'email';
        _authStateController.add(_currentUser);
        AppLogger.auth('Backend auth service initialized successfully with user: ${_currentUser?.email}');
        
        // Optionally validate token in background
        _validateTokenInBackground();
      } catch (e, stackTrace) {
        AppLogger.auth('Failed to restore session, clearing tokens', error: e, stackTrace: stackTrace);
        // Session data is corrupted, clear it
        await clearTokens();
      }
    } else {
      AppLogger.auth('No existing session found');
    }
  }

  // Validate token in background without blocking initialization
  Future<void> _validateTokenInBackground() async {
    try {
      final userProfile = await getUserProfile();
      // Update user data if profile has changed
      _currentUser = BackendUser.fromJson(userProfile);
      _authProvider = userProfile['authProvider'] ?? _authProvider;
      _authStateController.add(_currentUser);
      AppLogger.auth('Token validated successfully');
    } catch (e, stackTrace) {
      AppLogger.auth('Background token validation failed, clearing session', error: e, stackTrace: stackTrace);
      // Token is invalid, clear session
      await clearTokens();
    }
  }

  // Register with email/password
  Future<Map<String, dynamic>> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    AppLogger.api('Registering user with email: $email');
    try {
      final response = await http.post(
        Uri.parse(AuthEndpoints.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      AppLogger.network('Registration response status: ${response.statusCode}');
      final data = jsonDecode(response.body);
      AppLogger.network('Registration response body: ${response.body}');

      if (response.statusCode == 201 && data['success']) {
        await _saveTokens(data['data']['tokens']);
        _currentUser = BackendUser.fromJson(data['data']['user']);
        _authProvider = data['data']['user']['authProvider'] ?? 'email';
        _authStateController.add(_currentUser);
        AppLogger.auth('Registration successful for: $email');
        return data;
      } else if (response.statusCode == 429) {
        // Handle rate limiting specifically
        final retryAfter = _getRetryAfterFromHeaders(response.headers);
        final message = data['message'] ?? 'Too many requests. Please try again later.';
        AppLogger.auth('Rate limit hit during registration: $message');
        throw RateLimitException(message, retryAfter: retryAfter);
      } else {
        AppLogger.error('Registration API error: ${data['message'] ?? 'Unknown error'}', tag: 'API');
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e, stackTrace) {
      AppLogger.api('Registration request failed', error: e, stackTrace: stackTrace);
      if (e is RateLimitException) {
        rethrow; // Re-throw rate limit exceptions as-is
      }
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Extract retry-after duration from response headers
  Duration _getRetryAfterFromHeaders(Map<String, String> headers) {
    final retryAfter = headers['retry-after'];
    if (retryAfter != null) {
      try {
        final seconds = int.parse(retryAfter);
        return Duration(seconds: seconds);
      } catch (e) {
        AppLogger.warning('Could not parse retry-after header: $retryAfter');
      }
    }
    return const Duration(minutes: 15); // Default fallback
  }

  // Login with email/password
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    AppLogger.api('Attempting login for email: $email');
    try {
      final response = await http.post(
        Uri.parse(AuthEndpoints.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      AppLogger.network('Login response status: ${response.statusCode}');
      final data = jsonDecode(response.body);
      AppLogger.network('Login response body: ${response.body}');

      if (response.statusCode == 200 && data['success']) {
        await _saveTokens(data['data']['tokens']);
        _currentUser = BackendUser.fromJson(data['data']['user']);
        _authProvider = data['data']['user']['authProvider'] ?? 'email';
        _authStateController.add(_currentUser);
        AppLogger.auth('Login successful for: $email');
        return data;
      } else if (response.statusCode == 429) {
        // Handle rate limiting specifically
        final retryAfter = _getRetryAfterFromHeaders(response.headers);
        final message = data['message'] ?? 'Too many requests. Please try again later.';
        AppLogger.auth('Rate limit hit during login: $message');
        throw RateLimitException(message, retryAfter: retryAfter);
      } else {
        AppLogger.error('Login API error: ${data['message'] ?? 'Unknown error'}', tag: 'API');
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e, stackTrace) {
      AppLogger.api('Login request failed', error: e, stackTrace: stackTrace);
      if (e is RateLimitException) {
        rethrow; // Re-throw rate limit exceptions as-is
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    AppLogger.auth('Starting Google sign-in process');
    try {
      // First get Google credentials
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        AppLogger.auth('Google sign-in cancelled by user');
        throw Exception('Google sign in was cancelled');
      }

      AppLogger.auth('Google user obtained: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        AppLogger.error('Failed to get Google tokens', tag: 'AUTH');
        throw Exception('Failed to get Google tokens');
      }

      // Sign in to Firebase with Google credential to get Firebase ID token
      AppLogger.auth('Signing in to Firebase with Google credential');
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final firebase_auth.UserCredential userCredential = 
          await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      
      // Get Firebase ID token
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        AppLogger.error('Failed to get Firebase ID token', tag: 'AUTH');
        throw Exception('Failed to get Firebase ID token');
      }

      AppLogger.auth('Firebase ID token obtained, sending to backend');

      // Send Firebase ID token to backend
      AppLogger.api('Sending Firebase ID token to backend');
      final response = await http.post(
        Uri.parse(AuthEndpoints.google),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': firebaseIdToken,
        }),
      );

      AppLogger.network('Google sign-in response status: ${response.statusCode}');
      final data = jsonDecode(response.body);
      AppLogger.network('Google sign-in response body: ${response.body}');

      if (response.statusCode == 200 && data['success']) {
        await _saveTokens(data['data']['tokens']);
        _currentUser = BackendUser.fromJson(data['data']['user']);
        _authProvider = data['data']['user']['authProvider'] ?? 'google';
        _authStateController.add(_currentUser);
        AppLogger.auth('Google sign-in successful for: ${googleUser.email}');
        return data;
      } else {
        AppLogger.error('Google sign-in API error: ${data['message'] ?? 'Unknown error'}', tag: 'API');
        throw Exception(data['message'] ?? 'Google sign in failed');
      }
    } catch (e, stackTrace) {
      AppLogger.api('Google sign-in request failed', error: e, stackTrace: stackTrace);
      throw Exception('Google sign in failed: ${e.toString()}');
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(AuthEndpoints.me),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['data']['user'];
      } else {
        throw Exception(data['message'] ?? 'Failed to get user profile');
      }
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Refresh access token
  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse(AuthEndpoints.refreshToken),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _saveTokens(data['data']['tokens']);
        return true;
      } else {
        // Refresh token is invalid, clear all tokens
        await clearTokens();
        return false;
      }
    } catch (e) {
      await clearTokens();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    AppLogger.auth('Sign out requested');
    try {
      final token = await _getAuthToken();
      if (token != null) {
        AppLogger.api('Calling backend logout endpoint');
        final response = await http.post(
          Uri.parse(AuthEndpoints.logout),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        AppLogger.network('Logout response status: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      AppLogger.auth('Backend logout failed, continuing with local logout', error: e, stackTrace: stackTrace);
      // Ignore logout errors
    } finally {
      AppLogger.auth('Clearing local auth data');
      await clearTokens();
      await _googleSignIn.signOut();
      _currentUser = null;
      _authStateController.add(null);
      AppLogger.auth('Sign out completed');
    }
  }

  // Get authentication token for API calls
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Public method to get token for other services
  Future<String?> getAuthToken() async {
    String? token = await _getAuthToken();

    // If token is null, try to refresh
    if (token == null) {
      final refreshed = await refreshToken();
      if (refreshed) {
        token = await _getAuthToken();
      }
    }

    return token;
  }

  // Save tokens and user data to local storage
  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, tokens['accessToken']);
    await prefs.setString(_refreshTokenKey, tokens['refreshToken']);
    
    // Save user data if available
    if (_currentUser != null) {
      final userDataJson = jsonEncode(_currentUser!.toJson());
      await prefs.setString(_userDataKey, userDataJson);
    }
    
    // Save auth provider
    if (_authProvider != null) {
      await prefs.setString(_authProviderKey, _authProvider!);
    }
    
    AppLogger.auth('Saved session data to local storage');
  }

  // Clear all tokens and user data
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_authProviderKey);
    _currentUser = null;
    _authProvider = null;
    _authStateController.add(null);
    AppLogger.auth('Cleared all session data from local storage');
  }

  // Get user properties
  String? get userId => _currentUser?.uid;
  String? get userEmail => _currentUser?.email;
  String? get userDisplayName => _currentUser?.name;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  bool get isEmailVerified => _currentUser?.isEmailVerified ?? false;
  bool get isSignedIn => _currentUser != null;

  // Send password reset email (will need backend endpoint)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse(AuthEndpoints.forgotPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || !data['success']) {
        throw Exception(data['message'] ?? 'Failed to send password reset email');
      }
    } catch (e) {
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }

  // Send email verification (will need backend endpoint)
  Future<void> sendEmailVerification() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(AuthEndpoints.sendVerification),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || !data['success']) {
        throw Exception(data['message'] ?? 'Failed to send verification email');
      }
    } catch (e) {
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  // Check email verification status
  Future<bool> checkEmailVerified() async {
    try {
      final userProfile = await getUserProfile();
      return userProfile['isEmailVerified'] ?? false;
    } catch (e) {
      throw Exception('Failed to check email verification status: ${e.toString()}');
    }
  }

  // Dispose the stream controller
  void dispose() {
    _authStateController.close();
  }
}

// Custom exception for rate limiting
class RateLimitException implements Exception {
  final String message;
  final Duration? retryAfter;

  RateLimitException(this.message, {this.retryAfter});

  @override
  String toString() {
    if (retryAfter != null) {
      return '$message Please try again in ${retryAfter!.inMinutes} minutes.';
    }
    return message;
  }
}