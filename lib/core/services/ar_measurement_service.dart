import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

/// AR Measurement Service using ARCore/ARKit
/// Provides land measurement capabilities through native AR
class ARMeasurementService {
  ArCoreController? _arCoreController;
  final List<vector.Vector3> _measurementPoints = [];
  final StreamController<ARMeasurementUpdate> _updateController =
      StreamController<ARMeasurementUpdate>.broadcast();

  Stream<ARMeasurementUpdate> get updates => _updateController.stream;
  List<vector.Vector3> get points => List.unmodifiable(_measurementPoints);
  bool get isInitialized => _arCoreController != null;

  /// Initialize AR session
  Future<void> initialize(ArCoreController controller) async {
    _arCoreController = controller;
    _measurementPoints.clear();
    
    debugPrint('✅ AR Measurement Service initialized');
    _updateController.add(ARMeasurementUpdate(
      type: ARUpdateType.initialized,
      message: 'AR session ready',
    ));
  }

  /// Add measurement point at tap location
  Future<void> addPoint(vector.Vector3 position) async {
    if (_arCoreController == null) {
      throw Exception('AR not initialized');
    }

    _measurementPoints.add(position);
    
    // Add visual marker
    await _addMarker(position, _measurementPoints.length);
    
    // Draw line if we have 2+ points
    if (_measurementPoints.length > 1) {
      await _drawLine(
        _measurementPoints[_measurementPoints.length - 2],
        _measurementPoints.last,
      );
    }

    // Calculate measurements
    final measurements = _calculateMeasurements();
    
    debugPrint('📍 Point ${_measurementPoints.length} added: $position');
    _updateController.add(ARMeasurementUpdate(
      type: ARUpdateType.pointAdded,
      message: 'Point ${_measurementPoints.length} added',
      pointCount: _measurementPoints.length,
      area: measurements['area'],
      perimeter: measurements['perimeter'],
    ));
  }

  /// Add visual marker sphere at point location
  Future<void> _addMarker(vector.Vector3 position, int index) async {
    final material = ArCoreMaterial(
      color: Colors.red,
      metallic: 0.8,
    );

    final sphere = ArCoreSphere(
      materials: [material],
      radius: 0.05, // 5cm sphere
    );

    final node = ArCoreNode(
      shape: sphere,
      position: position,
      name: 'point_$index',
    );

    await _arCoreController!.addArCoreNode(node);
  }

  /// Draw line between two points
  Future<void> _drawLine(vector.Vector3 start, vector.Vector3 end) async {
    final material = ArCoreMaterial(
      color: Colors.blue,
      metallic: 0.5,
    );

    // Calculate midpoint and dimensions
    final midpoint = vector.Vector3(
      (start.x + end.x) / 2,
      (start.y + end.y) / 2,
      (start.z + end.z) / 2,
    );

    final distance = (end - start).length;
    final direction = (end - start).normalized();

    // Create cylinder as line
    final cylinder = ArCoreCylinder(
      materials: [material],
      radius: 0.01, // 1cm thick line
      height: distance,
    );

    // Calculate rotation to align cylinder with line direction
    final upVector = vector.Vector3(0, 1, 0);
    final rotationAxis = upVector.cross(direction).normalized();
    final angle = math.acos(upVector.dot(direction));
    final rotation = vector.Vector4(rotationAxis.x, rotationAxis.y, rotationAxis.z, angle);

    final node = ArCoreNode(
      shape: cylinder,
      position: midpoint,
      rotation: rotation,
      name: 'line_${_measurementPoints.length - 1}',
    );

    await _arCoreController!.addArCoreNode(node);
  }

  /// Calculate area and perimeter from points
  Map<String, double> _calculateMeasurements() {
    if (_measurementPoints.length < 3) {
      return {'area': 0.0, 'perimeter': 0.0};
    }

    // Calculate perimeter
    double perimeter = 0.0;
    for (int i = 0; i < _measurementPoints.length; i++) {
      final current = _measurementPoints[i];
      final next = _measurementPoints[(i + 1) % _measurementPoints.length];
      perimeter += (next - current).length;
    }

    // Calculate area using Shoelace formula (2D projection on ground plane)
    double area = 0.0;
    for (int i = 0; i < _measurementPoints.length; i++) {
      final current = _measurementPoints[i];
      final next = _measurementPoints[(i + 1) % _measurementPoints.length];
      area += (current.x * next.z - next.x * current.z);
    }
    area = area.abs() / 2.0;

    return {
      'area': area,
      'perimeter': perimeter,
    };
  }

  /// Clear all measurement points
  Future<void> clearMeasurements() async {
    _measurementPoints.clear();
    
    // Remove all AR nodes
    if (_arCoreController != null) {
      // ARCore doesn't have direct removeAll, need to recreate session
      debugPrint('🗑️ Clearing measurements');
    }

    _updateController.add(ARMeasurementUpdate(
      type: ARUpdateType.cleared,
      message: 'Measurements cleared',
    ));
  }

  /// Complete measurement and get results
  Map<String, dynamic> completeMeasurement() {
    final measurements = _calculateMeasurements();
    
    _updateController.add(ARMeasurementUpdate(
      type: ARUpdateType.completed,
      message: 'Measurement completed',
      pointCount: _measurementPoints.length,
      area: measurements['area'],
      perimeter: measurements['perimeter'],
    ));

    return {
      'points': _measurementPoints.length,
      'area': measurements['area'],
      'perimeter': measurements['perimeter'],
      'coordinates': _measurementPoints.map((p) => {
        'x': p.x,
        'y': p.y,
        'z': p.z,
      }).toList(),
    };
  }

  /// Dispose resources
  void dispose() {
    _arCoreController?.dispose();
    _updateController.close();
    _measurementPoints.clear();
    debugPrint('🔴 AR Measurement Service disposed');
  }
}

/// AR Update Types
enum ARUpdateType {
  initialized,
  pointAdded,
  cleared,
  completed,
  error,
}

/// AR Measurement Update
class ARMeasurementUpdate {
  final ARUpdateType type;
  final String message;
  final int? pointCount;
  final double? area;
  final double? perimeter;

  ARMeasurementUpdate({
    required this.type,
    required this.message,
    this.pointCount,
    this.area,
    this.perimeter,
  });
}
