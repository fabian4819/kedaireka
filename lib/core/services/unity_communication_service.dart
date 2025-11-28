import 'dart:async';
import 'dart:convert';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';

/// Service for bidirectional communication between Flutter and Unity
class UnityCommunicationService {
  final UnityWidgetController _controller;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  UnityCommunicationService(this._controller) {
    _setupMessageListener();
  }

  /// Stream of messages received from Unity
  Stream<Map<String, dynamic>> get onUnityMessage => _messageController.stream;

  void _setupMessageListener() {
    // Listen to messages from Unity
    // Note: The actual implementation depends on flutter_unity_widget version
    // Messages from Unity will come through the controller's message callback
  }

  /// Initialize AR session with GPS location
  Future<void> initializeARWithLocation(
    double latitude,
    double longitude,
    double altitude,
    double accuracy,
  ) async {
    final data = {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
    };

    await _sendToUnity(
      'FlutterUnityBridge',
      'InitializeARWithLocation',
      jsonEncode(data),
    );
  }

  /// Update GPS position during AR session
  Future<void> updateGPSPosition(
    double latitude,
    double longitude,
    double altitude,
    double accuracy,
  ) async {
    final data = {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
    };

    await _sendToUnity(
      'FlutterUnityBridge',
      'UpdateGPSPosition',
      jsonEncode(data),
    );
  }

  /// Start a new measurement session
  Future<void> startMeasurement(String measurementType) async {
    await _sendToUnity(
      'FlutterUnityBridge',
      'StartMeasurement',
      measurementType,
    );
  }

  /// Add a measurement point at current location
  Future<void> addMeasurementPoint() async {
    await _sendToUnity(
      'FlutterUnityBridge',
      'AddMeasurementPoint',
      '',
    );
  }

  /// Complete the current measurement
  Future<void> completeMeasurement() async {
    await _sendToUnity(
      'FlutterUnityBridge',
      'CompleteMeasurement',
      '',
    );
  }

  /// Reset the AR session
  Future<void> resetARSession() async {
    await _sendToUnity(
      'FlutterUnityBridge',
      'ResetARSession',
      '',
    );
  }

  /// Send message to Unity
  ///
  /// Parameters:
  /// - gameObjectName: Name of the GameObject in Unity scene
  /// - methodName: Name of the method to call on the GameObject
  /// - message: String message/data to send
  Future<void> _sendToUnity(
    String gameObjectName,
    String methodName,
    String message,
  ) async {
    try {
      _controller.postMessage(
        gameObjectName,
        methodName,
        message,
      );
    } catch (e) {
      print('Error sending message to Unity: $e');
      _messageController.add({
        'type': 'error',
        'data': 'Failed to send message to Unity: $e',
      });
    }
  }

  /// Pause Unity
  void pause() {
    _controller.pause();
  }

  /// Resume Unity
  void resume() {
    _controller.resume();
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
