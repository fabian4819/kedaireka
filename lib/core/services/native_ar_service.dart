import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'ar_measurement_service_interface.dart';

/// Native AR service implementation using platform channels
/// Communicates with ARKit on iOS and ARCore on Android
class NativeARService implements ARMeasurementServiceInterface {
  static const MethodChannel _channel = MethodChannel('com.kedaireka.geoclarity/ar');

  final StreamController<ARSessionState> _sessionStateController =
      StreamController<ARSessionState>.broadcast();
  final StreamController<ARMeasurementResult> _measurementController =
      StreamController<ARMeasurementResult>.broadcast();

  ARSessionState _currentState = ARSessionState.notInitialized;

  NativeARService() {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSessionStateChanged':
          _handleSessionStateChange(call.arguments as String);
          break;
        case 'onMeasurementUpdate':
          _handleMeasurementUpdate(call.arguments as String);
          break;
        default:
          print('Unknown method from native: ${call.method}');
      }
    });
  }

  void _handleSessionStateChange(String state) {
    print('🔵 AR Session state changed: $state');
    ARSessionState newState;
    
    switch (state) {
      case 'notInitialized':
        newState = ARSessionState.notInitialized;
        break;
      case 'initializing':
        newState = ARSessionState.initializing;
        break;
      case 'ready':
        newState = ARSessionState.ready;
        break;
      case 'running':
        newState = ARSessionState.running;
        break;
      case 'paused':
        newState = ARSessionState.paused;
        break;
      case 'error':
        newState = ARSessionState.error;
        break;
      default:
        newState = ARSessionState.error;
    }
    
    _currentState = newState;
    _sessionStateController.add(newState);
  }

  void _handleMeasurementUpdate(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final result = ARMeasurementResult.fromJson(json);
      _measurementController.add(result);
    } catch (e) {
      print('❌ Error parsing measurement update: $e');
    }
  }

  @override
  ARSessionState get sessionState => _currentState;

  @override
  Stream<ARSessionState> get sessionStateStream => _sessionStateController.stream;

  @override
  Stream<ARMeasurementResult> get measurementStream => _measurementController.stream;

  @override
  Future<bool> isARSupported() async {
    try {
      final bool? result = await _channel.invokeMethod('isARSupported');
      return result ?? false;
    } catch (e) {
      print('❌ Error checking AR support: $e');
      return false;
    }
  }

  @override
  Future<bool> initialize() async {
    try {
      _currentState = ARSessionState.initializing;
      _sessionStateController.add(_currentState);
      
      await _channel.invokeMethod('initialize');
      
      print('✅ AR initialized successfully');
      return true;
    } on PlatformException catch (e) {
      print('❌ Failed to initialize AR: ${e.message}');
      _currentState = ARSessionState.error;
      _sessionStateController.add(_currentState);
      return false;
    } catch (e) {
      print('❌ Unexpected error initializing AR: $e');
      _currentState = ARSessionState.error;
      _sessionStateController.add(_currentState);
      return false;
    }
  }

  @override
  Future<void> startSession() async {
    try {
      await _channel.invokeMethod('startSession');
      print('✅ AR session started');
    } on PlatformException catch (e) {
      print('❌ Failed to start AR session: ${e.message}');
      throw Exception('Failed to start AR session: ${e.message}');
    }
  }

  @override
  Future<void> pauseSession() async {
    try {
      await _channel.invokeMethod('pauseSession');
      print('⏸️ AR session paused');
    } catch (e) {
      print('❌ Error pausing AR session: $e');
    }
  }

  @override
  Future<void> resumeSession() async {
    try {
      await _channel.invokeMethod('resumeSession');
      print('▶️ AR session resumed');
    } catch (e) {
      print('❌ Error resuming AR session: $e');
    }
  }

  @override
  Future<void> stopSession() async {
    try {
      await _channel.invokeMethod('stopSession');
      print('⏹️ AR session stopped');
    } catch (e) {
      print('❌ Error stopping AR session: $e');
    }
  }

  @override
  Future<ARMeasurementPoint?> addPoint() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('addPoint');
      
      if (result != null) {
        return ARMeasurementPoint.fromJson(Map<String, dynamic>.from(result));
      }
      
      return null;
    } on PlatformException catch (e) {
      print('❌ Failed to add point: ${e.message}');
      throw Exception(e.message ?? 'Failed to add point');
    } catch (e) {
      print('❌ Unexpected error adding point: $e');
      return null;
    }
  }

  @override
  Future<bool> removeLastPoint() async {
    try {
      final bool? result = await _channel.invokeMethod('removeLastPoint');
      return result ?? false;
    } on PlatformException catch (e) {
      print('❌ Failed to remove point: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Unexpected error removing point: $e');
      return false;
    }
  }

  @override
  Future<void> clearAllPoints() async {
    try {
      await _channel.invokeMethod('clearAllPoints');
      print('🗑️ All points cleared');
    } catch (e) {
      print('❌ Error clearing points: $e');
    }
  }

  @override
  Future<ARMeasurementResult> getMeasurement() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getMeasurement');
      
      if (result != null) {
        return ARMeasurementResult.fromJson(Map<String, dynamic>.from(result));
      }
      
      return ARMeasurementResult(points: []);
    } catch (e) {
      print('❌ Error getting measurement: $e');
      return ARMeasurementResult(points: []);
    }
  }

  @override
  Future<void> dispose() async {
    await stopSession();
    await _sessionStateController.close();
    await _measurementController.close();
  }
}
