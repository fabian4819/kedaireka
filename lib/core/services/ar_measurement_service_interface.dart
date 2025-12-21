import 'dart:async';

/// Abstract interface for AR measurement service
/// Implemented separately for iOS (ARKit) and Android (ARCore)
abstract class ARMeasurementPoint {
  final double x;
  final double y;
  final double z;
  final int id;

  ARMeasurementPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'id': id,
      };

  factory ARMeasurementPoint.fromJson(Map<String, dynamic> json) {
    return _ARMeasurementPointImpl(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      id: json['id'] as int,
    );
  }
}

class _ARMeasurementPointImpl extends ARMeasurementPoint {
  _ARMeasurementPointImpl({
    required super.x,
    required super.y,
    required super.z,
    required super.id,
  });
}

/// Result of AR measurement
class ARMeasurementResult {
  final List<ARMeasurementPoint> points;
  final double? area; // in square meters
  final double? perimeter; // in meters
  final List<double>? distances; // distances between consecutive points

  ARMeasurementResult({
    required this.points,
    this.area,
    this.perimeter,
    this.distances,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'area': area,
        'perimeter': perimeter,
        'distances': distances,
      };

  factory ARMeasurementResult.fromJson(Map<String, dynamic> json) {
    return ARMeasurementResult(
      points: (json['points'] as List)
          .map((p) => ARMeasurementPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      area: json['area'] as double?,
      perimeter: json['perimeter'] as double?,
      distances: (json['distances'] as List?)?.map((d) => (d as num).toDouble()).toList(),
    );
  }
}

/// AR Session state
enum ARSessionState {
  notInitialized,
  initializing,
  ready,
  running,
  paused,
  error,
}

/// Abstract interface that both iOS and Android implementations must follow
abstract class ARMeasurementServiceInterface {
  /// Current session state
  ARSessionState get sessionState;

  /// Stream of session state changes
  Stream<ARSessionState> get sessionStateStream;

  /// Stream of measurement updates
  Stream<ARMeasurementResult> get measurementStream;

  /// Initialize AR session (request permissions, check device support)
  Future<bool> initialize();

  /// Start AR session
  Future<void> startSession();

  /// Pause AR session
  Future<void> pauseSession();

  /// Resume AR session
  Future<void> resumeSession();

  /// Stop AR session
  Future<void> stopSession();

  /// Add a measurement point at current center of screen
  Future<ARMeasurementPoint?> addPoint();

  /// Remove last added point
  Future<bool> removeLastPoint();

  /// Clear all points
  Future<void> clearAllPoints();

  /// Get current measurement result
  Future<ARMeasurementResult> getMeasurement();

  /// Check if AR is supported on this device
  Future<bool> isARSupported();

  /// Dispose resources
  Future<void> dispose();
}
