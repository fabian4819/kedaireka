import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Service for communicating with Unity through platform channels
class UnityChannelService {
  static const MethodChannel _channel = MethodChannel('com.kedaireka.geoclarity/unity');

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of messages received from Unity
  Stream<Map<String, dynamic>> get onUnityMessage => _messageController.stream;

  UnityChannelService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle incoming method calls from Unity (Android)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUnityMessage':
        final String jsonMessage = call.arguments as String;
        try {
          final Map<String, dynamic> message = jsonDecode(jsonMessage);
          _messageController.add(message);
        } catch (e) {
          print('Error parsing Unity message: $e');
        }
        break;
      default:
        print('Unknown method from Unity: ${call.method}');
    }
  }

  /// Launch Unity AR view
  Future<void> launchUnity() async {
    try {
      await _channel.invokeMethod('launchUnity');
    } on PlatformException catch (e) {
      print('Failed to launch Unity: ${e.message}');
      rethrow;
    }
  }

  /// Close Unity AR view
  Future<void> closeUnity() async {
    try {
      await _channel.invokeMethod('closeUnity');
    } on PlatformException catch (e) {
      print('Failed to close Unity: ${e.message}');
    }
  }

  /// Send message to Unity
  Future<void> sendToUnity(String gameObjectName, String methodName, String message) async {
    try {
      await _channel.invokeMethod('sendToUnity', {
        'gameObject': gameObjectName,
        'method': methodName,
        'message': message,
      });
    } on PlatformException catch (e) {
      print('Failed to send to Unity: ${e.message}');
    }
  }

  /// Initialize AR session with GPS location
  Future<void> initializeARWithLocation(
    double latitude,
    double longitude,
    double altitude,
    double accuracy,
  ) async {
    final data = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
    });

    await sendToUnity('FlutterUnityBridge', 'InitializeARWithLocation', data);
  }

  /// Update GPS position during AR session
  Future<void> updateGPSPosition(
    double latitude,
    double longitude,
    double altitude,
    double accuracy,
  ) async {
    final data = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
    });

    await sendToUnity('FlutterUnityBridge', 'UpdateGPSPosition', data);
  }

  /// Start a new measurement session
  Future<void> startMeasurement(String measurementType) async {
    await sendToUnity('FlutterUnityBridge', 'StartMeasurement', measurementType);
  }

  /// Add a measurement point at current location
  Future<void> addMeasurementPoint() async {
    await sendToUnity('FlutterUnityBridge', 'AddMeasurementPoint', '');
  }

  /// Complete the current measurement
  Future<void> completeMeasurement() async {
    await sendToUnity('FlutterUnityBridge', 'CompleteMeasurement', '');
  }

  /// Reset the AR session
  Future<void> resetARSession() async {
    await sendToUnity('FlutterUnityBridge', 'ResetARSession', '');
  }

  /// Pause Unity
  Future<void> pauseUnity() async {
    try {
      await _channel.invokeMethod('pauseUnity');
    } on PlatformException catch (e) {
      print('Failed to pause Unity: ${e.message}');
    }
  }

  /// Resume Unity
  Future<void> resumeUnity() async {
    try {
      await _channel.invokeMethod('resumeUnity');
    } on PlatformException catch (e) {
      print('Failed to resume Unity: ${e.message}');
    }
  }

  /// Check if Unity is loaded
  Future<bool> isUnityLoaded() async {
    try {
      final bool? loaded = await _channel.invokeMethod<bool>('isUnityLoaded');
      return loaded ?? false;
    } on PlatformException catch (e) {
      print('Failed to check Unity status: ${e.message}');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
  }
}

/// Data models for Unity communication

class LocationData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
      };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        altitude: json['altitude'] as double,
        accuracy: json['accuracy'] as double,
      );
}

class MeasurementResult {
  final double area;
  final double perimeter;
  final int pointCount;
  final DateTime timestamp;

  MeasurementResult({
    required this.area,
    required this.perimeter,
    required this.pointCount,
    required this.timestamp,
  });

  factory MeasurementResult.fromJson(Map<String, dynamic> json) =>
      MeasurementResult(
        area: (json['area'] as num).toDouble(),
        perimeter: (json['perimeter'] as num).toDouble(),
        pointCount: json['pointCount'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'area': area,
        'perimeter': perimeter,
        'pointCount': pointCount,
        'timestamp': timestamp.toIso8601String(),
      };
}

class UnityMessage {
  final String type;
  final String data;
  final DateTime timestamp;

  UnityMessage({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  factory UnityMessage.fromJson(Map<String, dynamic> json) => UnityMessage(
        type: json['type'] as String,
        data: json['data'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}
