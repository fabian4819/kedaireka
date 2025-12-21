#!/bin/bash

# Quick setup script untuk UnityBridge
# Run this after adding UnityBridge.cs to Unity project and re-exporting

set -e

echo "🚀 Starting UnityBridge setup..."

# Check if UnityBridge.cs exists in Unity export
if [ ! -f "UnityProject/iOS/Classes/UnityBridge.h" ]; then
    echo "❌ Error: UnityBridge not found in Unity export!"
    echo "📝 Please follow these steps:"
    echo "   1. Copy UnityBridge.cs to geoclarity-new/Assets/Scripts/"
    echo "   2. Add UnityBridge GameObject to AR scene in Unity"
    echo "   3. Re-export Unity project (File → Build Settings → Build)"
    echo "   4. Run this script again"
    exit 1
fi

echo "✅ UnityBridge found in Unity export"

# Clean Flutter
echo "🧹 Cleaning Flutter project..."
flutter clean

# Clean iOS
echo "🧹 Cleaning iOS dependencies..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Install pods
echo "📦 Installing CocoaPods..."
cd ios
pod install
cd ..

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎯 Next steps:"
echo "   1. Open Xcode: open ios/Runner.xcworkspace"
echo "   2. Product → Clean Build Folder (Cmd+Shift+K)"
echo "   3. Product → Build (Cmd+B)"
echo ""
echo "   Or run directly:"
echo "   flutter run -d 00008110-0010692C0CF9A01E"
echo ""
