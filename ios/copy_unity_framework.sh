#!/bin/bash
# Copy UnityFramework.framework to app bundle

set -e

UNITY_FRAMEWORK_PATH="${BUILT_PRODUCTS_DIR}/UnityFramework.framework"
TARGET_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/UnityFramework.framework"

if [ -d "$UNITY_FRAMEWORK_PATH" ]; then
    echo "Copying UnityFramework from $UNITY_FRAMEWORK_PATH"
    mkdir -p "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    cp -Rf "$UNITY_FRAMEWORK_PATH" "$TARGET_PATH"
    
    # Code sign the framework
    if [ "${CODE_SIGNING_REQUIRED}" = "YES" ]; then
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements --timestamp=none "$TARGET_PATH"
    fi
    
    echo "✅ UnityFramework copied and signed"
else
    echo "⚠️ UnityFramework.framework not found at $UNITY_FRAMEWORK_PATH"
    echo "Make sure Unity-iPhone target builds UnityFramework first"
fi
