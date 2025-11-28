import Flutter
import UIKit

// MARK: - Unity Player Manager (Embedded)
protocol UnityPlayerManagerDelegate: AnyObject {
    func unityDidSendMessage(_ message: String)
}

class UnityPlayerManager: NSObject {

    // MARK: - Singleton
    static let shared = UnityPlayerManager()

    // MARK: - Properties
    weak var delegate: UnityPlayerManagerDelegate?
    private var isUnityLoaded = false

    // MARK: - Initialization
    private override init() {
        super.init()
        setupUnityFramework()
    }

    // MARK: - Unity Framework Setup
    private func setupUnityFramework() {
        // Try to load UnityFramework from the app bundle
        if let bundlePath = Bundle.main.path(forResource: "UnityFramework", ofType: "framework"),
           let bundle = Bundle(path: bundlePath) {
            bundle.load()
            print("✅ UnityFramework loaded successfully")
        } else {
            print("⚠️ UnityFramework not found, using placeholder implementation")
        }
    }

    // MARK: - Unity Lifecycle Methods

    /// Launch Unity AR view
    func launchUnity() {
        guard !isUnityLoaded else {
            print("⚠️ Unity is already loaded")
            return
        }

        DispatchQueue.main.async {
            self.isUnityLoaded = true
            self.showUnityPlaceholder()
            print("✅ Unity AR view launched (placeholder)")
        }
    }

    /// Close Unity view
    func closeUnity() {
        guard isUnityLoaded else {
            return
        }

        DispatchQueue.main.async {
            self.isUnityLoaded = false
            print("✅ Unity AR view closed")
        }
    }

    /// Send message to Unity GameObject
    func sendToUnity(gameObject: String, method: String, message: String) {
        guard isUnityLoaded else {
            print("⚠️ Unity not loaded, cannot send message")
            return
        }

        print("📤 Sent to Unity - GameObject: \(gameObject), Method: \(method), Message: \(message)")
    }

    /// Pause Unity
    func pauseUnity() {
        print("⏸️ Unity paused")
    }

    /// Resume Unity
    func resumeUnity() {
        print("▶️ Unity resumed")
    }

    /// Check if Unity is loaded
    func getUnityLoadedStatus() -> Bool {
        return isUnityLoaded
    }

    // MARK: - Cleanup
    func dispose() {
        closeUnity()
        print("🧹 UnityPlayerManager disposed")
    }

    // MARK: - Private Methods
    private func showUnityPlaceholder() {
        // Show placeholder alert for now
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        let alert = UIAlertController(
            title: "AR Integration",
            message: "Unity Framework needs to be built. Please follow the setup instructions in iOS_AR_Integration_README.md",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        rootViewController.present(alert, animated: true)
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate, UnityPlayerManagerDelegate {

  // MARK: - Properties
  private var unityChannel: FlutterMethodChannel?
  private var unityManager: UnityPlayerManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Initialize Unity integration
    setupUnityChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Unity Setup
  private func setupUnityChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("❌ Could not get FlutterViewController")
      return
    }

    let channelName = "com.kedaireka.geoclarity/unity"
    unityChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    // Initialize Unity Manager
    unityManager = UnityPlayerManager.shared
    unityManager?.delegate = self

    // Set up method call handler
    unityChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call: call, result: result)
    }

    print("✅ Unity method channel set up")
  }

  // MARK: - Method Call Handler
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let manager = unityManager else {
      result(FlutterError(code: "UNITY_ERROR", message: "Unity Manager not initialized", details: nil))
      return
    }

    switch call.method {
    case "launchUnity":
      checkCameraPermissionAndLaunch()
      result(nil)

    case "closeUnity":
      manager.closeUnity()
      result(nil)

    case "sendToUnity":
      guard let args = call.arguments as? [String: Any],
            let gameObject = args["gameObject"] as? String,
            let method = args["method"] as? String,
            let message = args["message"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments for sendToUnity", details: nil))
        return
      }
      manager.sendToUnity(gameObject: gameObject, method: method, message: message)
      result(nil)

    case "pauseUnity":
      manager.pauseUnity()
      result(nil)

    case "resumeUnity":
      manager.resumeUnity()
      result(nil)

    case "isUnityLoaded":
      result(manager.getUnityLoadedStatus())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Camera Permission
  private func checkCameraPermissionAndLaunch() {
    let status = AVCaptureDevice.authorizationStatus(for: .video)

    switch status {
    case .authorized:
      unityManager?.launchUnity()

    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          if granted {
            self?.unityManager?.launchUnity()
          } else {
            print("❌ Camera permission denied")
          }
        }
      }

    case .denied, .restricted:
      print("❌ Camera permission denied or restricted")
      // Optionally show alert to user to enable in Settings

    @unknown default:
      print("❌ Unknown camera permission status")
    }
  }

  // MARK: - App Lifecycle
  override func applicationWillResignActive(_ application: UIApplication) {
    unityManager?.pauseUnity()
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    unityManager?.resumeUnity()
    super.applicationDidBecomeActive(application)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    unityManager?.dispose()
    super.applicationWillTerminate(application)
  }

  // MARK: - UnityPlayerManagerDelegate
  func unityDidSendMessage(_ message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.unityChannel?.invokeMethod("onUnityMessage", arguments: message)
    }
  }
}

// MARK: - AVFoundation Import for Camera Permission
import AVFoundation
