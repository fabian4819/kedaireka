# iOS AR Integration Guide for Pix2Land

This guide explains how to integrate Unity AR functionality into your Flutter iOS app for cross-platform AR measurement capabilities.

## Overview

The integration uses Unity Framework embedded within the Flutter iOS app, providing the same AR features available on Android through a unified communication channel.

## Architecture

```
Flutter App (iOS)
├── UnityChannelService (cross-platform)
├── Method Channel: com.kedaireka.geoclarity/unity
├── UnityPlayerManager (iOS native)
├── UnityFramework (embedded Unity)
└── AR Features
    ├── ARKit integration
    ├── GPS positioning
    └── Measurement tools
```

## Current Status

✅ **Implemented:**
- iOS Unity Player Manager (Swift)
- Method Channel communication bridge
- Camera and location permissions
- Unity Framework integration setup
- Cross-platform UnityChannelService
- Build scripts and setup

⚠️ **Requires Manual Steps:**
- Build UnityFramework from Unity iOS project
- Link the compiled framework to Flutter iOS project

## Setup Instructions

### 1. Build Unity Framework

First, build your Unity project for iOS:

```bash
# Navigate to your Flutter project
cd /Users/fabian/Code/pix2land/kedaireka

# Run the Unity framework build script
./ios/build_unity_framework.sh
```

### 2. Build UnityFramework in Xcode

1. Open Unity project in Unity Editor:
   ```
   /Users/fabian/Code/pix2land/geoclarity-new
   ```

2. Go to `File > Build Settings`

3. Select iOS platform and click `Switch Platform`

4. Click `Build` and save to `Builds/iOS` folder

5. Open the generated Xcode project:
   ```
   /Users/fabian/Code/pix2land/geoclarity-new/Builds/iOS/Unity-iPhone.xcodeproj
   ```

6. In Xcode:
   - Select "UnityFramework" scheme
   - Build for iOS (⌘+B)
   - Find the built framework at:
     ```
     ~/Library/Developer/Xcode/DerivedData/Unity-iPhone-*/Build/Products/Debug-iphoneos/UnityFramework.framework
     ```

7. Copy the built UnityFramework.framework to:
   ```
   /Users/fabian/Code/pix2land/kedaireka/ios/Frameworks/UnityFramework.framework
   ```

### 3. Configure Flutter iOS Project

1. Add the framework to your Xcode project:
   - Open `ios/Runner.xcworkspace`
   - Drag UnityFramework.framework to "Frameworks, Libraries, and Embedded Content"
   - Set "Embed" to "Do Not Embed" (it's already embedded by our code)

2. Update your Podfile if needed:
   ```ruby
   # Already configured in your Podfile
   target 'Runner' do
     use_frameworks!
     flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
   end
   ```

3. Install dependencies:
   ```bash
   cd ios
   pod install
   ```

### 4. Build and Run Flutter App

```bash
# From Flutter project root
flutter pub get
flutter build ios --debug
flutter run
```

## Usage

### Launch AR Interface

The AR interface is accessible through the Flutter app's navigation:

```dart
// Navigate to AR screen (already in your app)
context.go('/ar');

// Or launch Unity directly
final unityService = UnityChannelService();
await unityService.launchUnity();
```

### AR Functionality

The integration supports these AR features:

1. **GPS-based AR positioning**
   - High-precision location tracking
   - AR coordinate system alignment

2. **Measurement tools**
   - Area measurement
   - Perimeter calculation
   - Point collection

3. **Real-time communication**
   - Unity ↔ Flutter message passing
   - Status updates and progress tracking

### Method Channel API

```dart
// Launch Unity AR view
await _channel.invokeMethod('launchUnity');

// Send messages to Unity
await _channel.invokeMethod('sendToUnity', {
  'gameObject': 'FlutterUnityBridge',
  'method': 'StartMeasurement',
  'message': 'area',
});

// Receive messages from Unity
_channel.setMethodCallHandler((call) async {
  if (call.method == 'onUnityMessage') {
    final message = call.arguments as String;
    // Handle Unity message
  }
});
```

## Permissions

The integration requires these iOS permissions (already configured in Info.plist):

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to provide AR measurement and geospatial features</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show your current location on the map and provide accurate AR measurements</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
  <string>armv7</string>
  <string>metal</string>
</array>
```

## Files Created/Modified

### iOS Native Files

1. **`ios/Runner/UnityPlayerManager.swift`**
   - Main Unity framework management
   - Unity lifecycle handling
   - Message passing bridge

2. **`ios/Runner/UnityViewController.swift`**
   - Unity view controller for fullscreen AR
   - Navigation and UI integration

3. **`ios/Runner/AppDelegate.swift`**
   - Method channel setup
   - Camera permission handling
   - Unity integration initialization

4. **`ios/Frameworks/`**
   - UnityFramework.h (interface definition)
   - UnityFramework.swift (placeholder implementation)
   - Privacy and manifest files

### Flutter Integration

- **`lib/core/services/unity_channel_service.dart`** (already cross-platform)
- **`lib/features/ar/ar_screen.dart`** (already using UnityChannelService)
- **`ios/Info.plist`** (updated permissions)

## Troubleshooting

### Common Issues

1. **UnityFramework not found:**
   ```
   Error: UnityFramework not found at path
   ```
   **Solution:** Run the build script and build the framework in Xcode first.

2. **Camera permission denied:**
   ```
   Error: Camera permission is required for AR
   ```
   **Solution:** Grant camera permission in Settings or reinstall the app.

3. **AR session not initializing:**
   ```
   Status: AR Error: ARKit not available
   ```
   **Solution:** Test on a physical device that supports ARKit.

4. **Build errors:**
   ```
   Framework not found UnityFramework
   ```
   **Solution:** Add the built framework to Xcode project settings.

### Debug Mode

The integration includes debug logging. Check Xcode console for Unity-related logs:

```swift
// Sample logs you'll see:
✅ UnityFramework initialized successfully
✅ Unity AR view launched
📤 Sent to Unity - GameObject: FlutterUnityBridge, Method: StartMeasurement
```

### Testing

1. **On Simulator:** Limited AR functionality (no camera/ARKit)
2. **On Physical Device:** Full AR functionality
3. **Requirements:** iOS device with ARKit support (iPhone 6s+)

## Next Steps

### Production Deployment

1. **Build release version of UnityFramework:**
   - Use Release configuration in Xcode
   - Optimize for App Store

2. **App Store submission:**
   - Ensure all permissions are properly described
   - Test on multiple device types
   - Validate ARKit compatibility

3. **Performance optimization:**
   - Optimize Unity build size
   - Test memory usage
   - Profile AR performance

### Feature Extensions

The current integration supports:
- ✅ Basic AR measurement
- ✅ GPS positioning
- ✅ Unity communication
- 🔄 Cross-platform compatibility

Future enhancements could include:
- 🎯 Building visualization in AR
- 🗺️ Map integration with AR overlay
- 📐 Advanced measurement tools
- 👥 Collaborative AR sessions

## Support

For issues with the integration:

1. Check Xcode console logs for Unity-related errors
2. Verify UnityFramework is properly built and linked
3. Test on a physical ARKit-compatible device
4. Ensure all permissions are granted

The Unity AR integration is now ready for testing on iOS devices! 🚀