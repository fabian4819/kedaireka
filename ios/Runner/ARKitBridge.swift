import Foundation
import UIKit
import ARKit
import SceneKit

/// ARKit bridge for AR measurement functionality
/// Handles AR session, point placement, and measurement calculations
class ARKitBridge: NSObject {
    
    // MARK: - Properties
    
    private var arView: ARSCNView?
    private var arSession: ARSession?
    private var measurementPoints: [MeasurementPoint] = []
    private var pointNodes: [SCNNode] = []
    private var lineNodes: [SCNNode] = []
    private var nextPointId = 1
    
    private var sessionStateCallback: ((String) -> Void)?
    private var measurementUpdateCallback: ((String) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        print("🟢 ARKitBridge initialized")
    }
    
    // MARK: - Session Management
    
    /// Check if ARKit is supported on this device
    func isARSupported() -> Bool {
        return ARWorldTrackingConfiguration.isSupported
    }
    
    /// Initialize AR session
    func initialize(completion: @escaping (Bool, String?) -> Void) {
        print("🟢 ARKitBridge: Initializing AR session...")
        
        guard isARSupported() else {
            completion(false, "ARKit is not supported on this device")
            return
        }
        
        // Check camera authorization
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .authorized:
            setupARView()
            completion(true, nil)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupARView()
                        completion(true, nil)
                    } else {
                        completion(false, "Camera permission denied")
                    }
                }
            }
            
        case .denied, .restricted:
            completion(false, "Camera permission denied. Please enable in Settings.")
            
        @unknown default:
            completion(false, "Unknown camera authorization status")
        }
    }
    
    private func setupARView() {
        print("🟢 ARKitBridge: Setting up ARSCNView...")
        
        arView = ARSCNView(frame: UIScreen.main.bounds)
        arView?.delegate = self
        arView?.session.delegate = self
        arView?.automaticallyUpdatesLighting = true
        arView?.autoenablesDefaultLighting = true
        
        arSession = arView?.session
        
        print("🟢 ARKitBridge: ARSCNView setup complete")
        notifySessionState("ready")
    }
    
    /// Start AR session
    func startSession(completion: @escaping (Bool, String?) -> Void) {
        print("🟢 ARKitBridge: Starting AR session...")
        
        guard let arView = arView else {
            completion(false, "AR view not initialized")
            return
        }
        
        // Add AR view to window
        DispatchQueue.main.async { [weak self] in
            guard let window = UIApplication.shared.windows.first else {
                completion(false, "No window found")
                return
            }
            
            window.addSubview(arView)
            arView.frame = window.bounds
            
            // Configure AR session
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.environmentTexturing = .automatic
            
            if #available(iOS 13.0, *) {
                configuration.frameSemantics = .sceneDepth
            }
            
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            print("🟢 ARKitBridge: AR session started")
            self?.notifySessionState("running")
            completion(true, nil)
        }
    }
    
    /// Pause AR session
    func pauseSession() {
        print("🟢 ARKitBridge: Pausing AR session...")
        arSession?.pause()
        notifySessionState("paused")
    }
    
    /// Resume AR session
    func resumeSession() {
        print("🟢 ARKitBridge: Resuming AR session...")
        
        guard let arView = arView else {
            print("⚠️ ARKitBridge: Cannot resume, AR view not initialized")
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        notifySessionState("running")
    }
    
    /// Stop AR session
    func stopSession() {
        print("🟢 ARKitBridge: Stopping AR session...")
        
        arSession?.pause()
        arView?.removeFromSuperview()
        clearAllPoints()
        
        notifySessionState("notInitialized")
    }
    
    // MARK: - Point Management
    
    /// Add measurement point at screen center
    func addPoint(completion: @escaping ([String: Any]?, String?) -> Void) {
        print("🟢 ARKitBridge: Adding measurement point...")
        
        guard let arView = arView else {
            completion(nil, "AR view not initialized")
            return
        }
        
        // Get screen center
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Perform hit test
        let hitTestResults = arView.hitTest(screenCenter, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .featurePoint])
        
        guard let hitResult = hitTestResults.first else {
            completion(nil, "No surface detected. Move your device to scan the area.")
            return
        }
        
        // Extract position from hit result
        let position = hitResult.worldTransform.columns.3
        let point = MeasurementPoint(
            id: nextPointId,
            x: Double(position.x),
            y: Double(position.y),
            z: Double(position.z)
        )
        
        nextPointId += 1
        measurementPoints.append(point)
        
        // Add visual marker
        addMarkerNode(at: SCNVector3(position.x, position.y, position.z))
        
        // Draw line if there's a previous point
        if measurementPoints.count > 1 {
            let previousPoint = measurementPoints[measurementPoints.count - 2]
            drawLine(from: previousPoint.vector, to: point.vector)
        }
        
        print("🟢 ARKitBridge: Point added at (\(point.x), \(point.y), \(point.z))")
        
        // Notify measurement update
        notifyMeasurementUpdate()
        
        completion(point.toDict(), nil)
    }
    
    /// Remove last added point
    func removeLastPoint(completion: @escaping (Bool, String?) -> Void) {
        print("🟢 ARKitBridge: Removing last point...")
        
        guard !measurementPoints.isEmpty else {
            completion(false, "No points to remove")
            return
        }
        
        measurementPoints.removeLast()
        
        // Remove visual marker
        if let lastNode = pointNodes.last {
            lastNode.removeFromParentNode()
            pointNodes.removeLast()
        }
        
        // Remove last line
        if let lastLine = lineNodes.last {
            lastLine.removeFromParentNode()
            lineNodes.removeLast()
        }
        
        notifyMeasurementUpdate()
        completion(true, nil)
    }
    
    /// Clear all points
    func clearAllPoints() {
        print("🟢 ARKitBridge: Clearing all points...")
        
        measurementPoints.removeAll()
        
        // Remove all visual elements
        pointNodes.forEach { $0.removeFromParentNode() }
        pointNodes.removeAll()
        
        lineNodes.forEach { $0.removeFromParentNode() }
        lineNodes.removeAll()
        
        nextPointId = 1
        notifyMeasurementUpdate()
    }
    
    // MARK: - Measurement Calculations
    
    /// Get current measurement result
    func getMeasurement() -> [String: Any] {
        let result = calculateMeasurements()
        
        return [
            "points": measurementPoints.map { $0.toDict() },
            "area": result.area ?? NSNull(),
            "perimeter": result.perimeter ?? NSNull(),
            "distances": result.distances ?? NSNull()
        ]
    }
    
    private func calculateMeasurements() -> (area: Double?, perimeter: Double?, distances: [Double]?) {
        guard measurementPoints.count >= 2 else {
            return (nil, nil, nil)
        }
        
        var distances: [Double] = []
        var perimeter: Double = 0
        
        // Calculate distances between consecutive points
        for i in 0..<measurementPoints.count - 1 {
            let distance = measurementPoints[i].distance(to: measurementPoints[i + 1])
            distances.append(distance)
            perimeter += distance
        }
        
        // Calculate area if we have at least 3 points (using Shoelace formula)
        var area: Double? = nil
        if measurementPoints.count >= 3 {
            var sum: Double = 0
            
            for i in 0..<measurementPoints.count {
                let current = measurementPoints[i]
                let next = measurementPoints[(i + 1) % measurementPoints.count]
                sum += (current.x * next.z - next.x * current.z)
            }
            
            area = abs(sum) / 2.0
            
            // Close the perimeter
            let closingDistance = measurementPoints.last!.distance(to: measurementPoints.first!)
            perimeter += closingDistance
        }
        
        return (area, perimeter, distances.isEmpty ? nil : distances)
    }
    
    // MARK: - Visual Elements
    
    private func addMarkerNode(at position: SCNVector3) {
        guard let arView = arView else { return }
        
        // Create sphere geometry
        let sphere = SCNSphere(radius: 0.02) // 2cm radius
        sphere.firstMaterial?.diffuse.contents = UIColor.systemBlue
        sphere.firstMaterial?.specular.contents = UIColor.white
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        arView.scene.rootNode.addChildNode(node)
        pointNodes.append(node)
        
        print("🟢 ARKitBridge: Marker added at position \(position)")
    }
    
    private func drawLine(from start: SCNVector3, to end: SCNVector3) {
        guard let arView = arView else { return }
        
        let distance = start.distance(to: end)
        
        // Create cylinder for line
        let cylinder = SCNCylinder(radius: 0.002, height: CGFloat(distance)) // 2mm thick
        cylinder.firstMaterial?.diffuse.contents = UIColor.systemGreen
        
        let node = SCNNode(geometry: cylinder)
        
        // Position at midpoint
        let midpoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        node.position = midpoint
        
        // Rotate to align with line direction
        let direction = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        node.look(at: end, up: arView.scene.rootNode.worldUp, localFront: node.worldUp)
        
        arView.scene.rootNode.addChildNode(node)
        lineNodes.append(node)
        
        print("🟢 ARKitBridge: Line drawn from \(start) to \(end), distance: \(distance)m")
    }
    
    // MARK: - Callbacks
    
    func setSessionStateCallback(_ callback: @escaping (String) -> Void) {
        self.sessionStateCallback = callback
    }
    
    func setMeasurementUpdateCallback(_ callback: @escaping (String) -> Void) {
        self.measurementUpdateCallback = callback
    }
    
    private func notifySessionState(_ state: String) {
        sessionStateCallback?(state)
    }
    
    private func notifyMeasurementUpdate() {
        let result = getMeasurement()
        if let jsonData = try? JSONSerialization.data(withJSONObject: result),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            measurementUpdateCallback?(jsonString)
        }
    }
    
    // MARK: - Cleanup
    
    func dispose() {
        print("🟢 ARKitBridge: Disposing...")
        stopSession()
        arView = nil
        arSession = nil
    }
}

// MARK: - ARSCNViewDelegate

extension ARKitBridge: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Handle plane detection if needed
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle plane updates if needed
    }
}

// MARK: - ARSessionDelegate

extension ARKitBridge: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ ARKitBridge: Session failed with error: \(error.localizedDescription)")
        notifySessionState("error")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ ARKitBridge: Session interrupted")
        notifySessionState("paused")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("🟢 ARKitBridge: Session interruption ended")
        notifySessionState("running")
    }
}

// MARK: - Helper Classes

private struct MeasurementPoint {
    let id: Int
    let x: Double
    let y: Double
    let z: Double
    
    var vector: SCNVector3 {
        return SCNVector3(Float(x), Float(y), Float(z))
    }
    
    func distance(to other: MeasurementPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
    
    func toDict() -> [String: Any] {
        return [
            "id": id,
            "x": x,
            "y": y,
            "z": z
        ]
    }
}

// MARK: - SCNVector3 Extensions

private extension SCNVector3 {
    func distance(to other: SCNVector3) -> Float {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}
