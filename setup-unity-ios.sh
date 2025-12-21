#!/bin/bash

# Flutter Unity Widget Integration Script for iOS
# This script integrates Unity export with Flutter using flutter_unity_widget plugin

set -e  # Exit on error

echo "🚀 Flutter Unity Widget Integration Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FLUTTER_PROJECT_DIR="$SCRIPT_DIR"
UNITY_EXPORT_IOS="$FLUTTER_PROJECT_DIR/UnityProject/iOS"
IOS_DIR="$FLUTTER_PROJECT_DIR/ios"

echo "📁 Checking paths..."
echo "   Flutter Project: $FLUTTER_PROJECT_DIR"
echo "   Unity iOS Export: $UNITY_EXPORT_IOS"
echo "   iOS Directory: $IOS_DIR"
echo ""

# Step 1: Check if Unity export exists
if [ ! -d "$UNITY_EXPORT_IOS" ]; then
    echo -e "${RED}❌ Unity iOS export not found at: $UNITY_EXPORT_IOS${NC}"
    echo ""
    echo "Please export Unity project first:"
    echo "1. Open geoclarity-new in Unity"
    echo "2. File → Build Settings → iOS"
    echo "3. Click 'Build'"
    echo "4. Save to: geoclarity-new/Builds/iOS-Flutter"
    echo "5. Then run: cp -r ../geoclarity-new/Builds/iOS-Flutter/* UnityProject/iOS/"
    exit 1
fi

echo -e "${GREEN}✅ Unity export found${NC}"

# Step 2: Check if UnityFramework directory exists
if [ ! -d "$UNITY_EXPORT_IOS/UnityFramework" ]; then
    echo -e "${RED}❌ UnityFramework directory not found in Unity export${NC}"
    echo "   Expected: $UNITY_EXPORT_IOS/UnityFramework"
    exit 1
fi

echo -e "${GREEN}✅ UnityFramework directory found${NC}"

# Step 3: Create or update symlink
echo ""
echo "🔗 Creating symlink..."

if [ -L "$IOS_DIR/UnityExport" ]; then
    echo "   Removing old symlink..."
    rm "$IOS_DIR/UnityExport"
fi

if [ -e "$IOS_DIR/UnityExport" ]; then
    echo -e "${YELLOW}⚠️  UnityExport exists but is not a symlink. Backing up...${NC}"
    mv "$IOS_DIR/UnityExport" "$IOS_DIR/UnityExport.backup"
fi

ln -s ../UnityProject/iOS "$IOS_DIR/UnityExport"
echo -e "${GREEN}✅ Symlink created: ios/UnityExport → UnityProject/iOS${NC}"

# Step 4: Update Info.plist if needed
echo ""
echo "📝 Checking Info.plist..."

INFO_PLIST="$IOS_DIR/Runner/Info.plist"

if ! grep -q "NSCameraUsageDescription" "$INFO_PLIST"; then
    echo -e "${YELLOW}⚠️  Adding camera permission to Info.plist${NC}"
    # This would need to be done manually or with PlistBuddy
    echo "   Please add to Info.plist manually:"
    echo "   <key>NSCameraUsageDescription</key>"
    echo "   <string>This app needs camera access for AR land measurement</string>"
else
    echo -e "${GREEN}✅ Camera permission already exists${NC}"
fi

# Step 5: Clean Flutter build
echo ""
echo "🧹 Cleaning Flutter build..."
cd "$FLUTTER_PROJECT_DIR"
flutter clean > /dev/null 2>&1
echo -e "${GREEN}✅ Flutter clean completed${NC}"

# Step 6: Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get
echo -e "${GREEN}✅ Dependencies installed${NC}"

# Step 7: Build iOS
echo ""
echo "🔨 Building iOS..."
echo "   This may take a few minutes..."
echo ""

flutter build ios --release --no-codesign

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ Integration Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open Xcode: open ios/Runner.xcworkspace"
    echo "2. Select your development team"
    echo "3. Connect your iPhone"
    echo "4. Run: flutter run -d <device-id>"
    echo ""
else
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Open Xcode: open ios/Runner.xcworkspace"
    echo "2. Try to build in Xcode to see detailed errors"
    echo "3. Check if UnityFramework is properly linked"
    echo ""
    exit 1
fi
