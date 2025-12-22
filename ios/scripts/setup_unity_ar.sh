#!/bin/bash

# =============================================================================
# Unity AR iOS Setup Script for flutter_unity_widget integration
# =============================================================================
# This script sets up the iOS project to integrate with Unity AR build
# from geoclarity-new/Builds/iOS
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"
UNITY_LIBRARY="$IOS_DIR/UnityLibrary"
UNITY_BUILD="/Users/fabian/Code/pix2land/geoclarity-new/Builds/iOS"

echo "🔧 Unity AR iOS Setup Script"
echo "============================"
echo ""

# Check if Unity build exists
if [ ! -d "$UNITY_BUILD" ]; then
    echo "❌ Unity iOS build not found at: $UNITY_BUILD"
    echo "   Please build Unity project for iOS first."
    exit 1
fi

# Create/update symlink to UnityLibrary
echo "📁 Setting up UnityLibrary symlink..."
if [ -L "$UNITY_LIBRARY" ]; then
    echo "   Symlink already exists, updating..."
    rm "$UNITY_LIBRARY"
fi
ln -s "$UNITY_BUILD" "$UNITY_LIBRARY"
echo "   ✅ Symlink created: UnityLibrary -> geoclarity-new/Builds/iOS"

# Run pod install
echo ""
echo "📦 Running pod install..."
cd "$IOS_DIR"
pod install --repo-update

echo ""
echo "✅ iOS setup complete!"
echo ""
echo "📋 MANUAL XCODE SETUP REQUIRED:"
echo "================================"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Right-click Navigator -> Add Files to 'Runner'"
echo "3. Select: ios/UnityLibrary/Unity-iPhone.xcodeproj"
echo "4. Select Unity-iPhone/Data folder -> Target Membership -> UnityFramework"
echo "5. Add UnityFramework.framework to Runner target"
echo "6. Build and run on physical device (simulator not supported for AR)"
echo ""
