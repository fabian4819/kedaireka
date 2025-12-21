#!/bin/bash

# Build Unity Framework Once - Solution untuk error berulang
# Run script ini SEKALI sebelum flutter run

set -e

echo "🔨 Building UnityFramework for iOS..."
echo ""

UNITY_PROJECT="/Users/fabian/Code/pix2land/kedaireka/UnityProject/iOS/Unity-iPhone.xcodeproj"
OUTPUT_DIR="/Users/fabian/Code/pix2land/kedaireka/ios/Frameworks"

# Check Unity project exists
if [ ! -d "$UNITY_PROJECT" ]; then
    echo "❌ Error: Unity project not found!"
    echo "   Expected: $UNITY_PROJECT"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "📦 Building UnityFramework (Debug)..."
xcodebuild \
    -project "$UNITY_PROJECT" \
    -scheme UnityFramework \
    -sdk iphoneos \
    -configuration Debug \
    -derivedDataPath "./build/unity-ios" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    build | grep -E "Build succeeded|error:|warning:" || true

BUILT_FRAMEWORK="./build/unity-ios/Build/Products/Debug-iphoneos/UnityFramework.framework"

if [ -d "$BUILT_FRAMEWORK" ]; then
    echo ""
    echo "✅ Copying framework to iOS/Frameworks..."
    rm -rf "$OUTPUT_DIR/UnityFramework.framework"
    cp -R "$BUILT_FRAMEWORK" "$OUTPUT_DIR/"
    
    echo "✅ UnityFramework build complete!"
    echo ""
    echo "📱 Now you can run: flutter run"
    echo ""
    echo "💡 Tip: Hanya perlu build ulang jika:"
    echo "   - Ada perubahan di Unity project"
    echo "   - Setelah 'flutter clean'"
else
    echo ""
    echo "❌ Error: Framework build failed!"
    echo "   Looking for: $BUILT_FRAMEWORK"
    exit 1
fi
