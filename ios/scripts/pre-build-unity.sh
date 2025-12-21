#!/bin/bash

# Pre-build script to ensure UnityFramework is available

set -e

FRAMEWORK_SOURCE="${SOURCE_ROOT}/Frameworks/UnityFramework.framework"
FRAMEWORK_DEST="${BUILT_PRODUCTS_DIR}/UnityFramework.framework"

echo "🔍 Checking UnityFramework..."

if [ ! -d "$FRAMEWORK_SOURCE" ]; then
    echo "❌ Error: UnityFramework not found at $FRAMEWORK_SOURCE"
    echo "   Run: ./build-unity-once.sh"
    exit 1
fi

echo "📦 Copying UnityFramework to build directory..."
rm -rf "$FRAMEWORK_DEST"
cp -R "$FRAMEWORK_SOURCE" "$FRAMEWORK_DEST"

echo "✅ UnityFramework ready for linking"
