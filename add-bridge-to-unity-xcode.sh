#!/bin/bash

# Script to add UnityToFlutterBridge files to Unity-iPhone.xcodeproj
# This provides the sendToFlutter implementation that Unity IL2CPP expects

PROJECT_DIR="/Users/fabian/Code/pix2land/kedaireka/UnityProject/iOS"
PROJECT_FILE="$PROJECT_DIR/Unity-iPhone.xcodeproj/project.pbxproj"

echo "🔧 Adding UnityToFlutterBridge to Unity-iPhone.xcodeproj..."

# Backup original
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Generate UUIDs for the files
BRIDGE_H_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')
BRIDGE_M_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')
BUILDFILE_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')

echo "Generated UUIDs:"
echo "  Header: $BRIDGE_H_UUID"
echo "  Source: $BRIDGE_M_UUID"
echo "  BuildFile: $BUILDFILE_UUID"

# Find the PBXFileReference section and add our files
perl -i -pe "
    if (/\/\* Begin PBXBuildFile section \*\//) {
        print;
        print \"\t\t$BUILDFILE_UUID /* UnityToFlutterBridge.m in Sources */ = {isa = PBXBuildFile; fileRef = $BRIDGE_M_UUID /* UnityToFlutterBridge.m */; };\n\";
        \$_ = '';
    }
" "$PROJECT_FILE"

perl -i -pe "
    if (/\/\* Begin PBXFileReference section \*\//) {
        print;
        print \"\t\t$BRIDGE_H_UUID /* UnityToFlutterBridge.h */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.h; path = UnityToFlutterBridge.h; sourceTree = \\\"<group>\\\"; };\n\";
        print \"\t\t$BRIDGE_M_UUID /* UnityToFlutterBridge.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = UnityToFlutterBridge.m; sourceTree = \\\"<group>\\\"; };\n\";
        \$_ = '';
    }
" "$PROJECT_FILE"

# Find the Libraries group and add references
perl -i -pe "
    if (/5044A88C241F18FA005F2391 \/\* Libraries \*\/ = {/) {
        \$in_libraries = 1;
    }
    if (\$in_libraries && /children = \(/) {
        \$in_children = 1;
    }
    if (\$in_children && /\);/) {
        print \"\t\t\t\t$BRIDGE_H_UUID /* UnityToFlutterBridge.h */,\n\";
        print \"\t\t\t\t$BRIDGE_M_UUID /* UnityToFlutterBridge.m */,\n\";
        \$in_children = 0;
        \$in_libraries = 0;
    }
" "$PROJECT_FILE"

# Find UnityFramework Sources build phase and add .m file
perl -i -pe "
    if (/\/\* Sources \*\/ = {/) {
        \$in_sources = 1;
    }
    if (\$in_sources && /files = \(/) {
        \$in_files = 1;
    }
    if (\$in_sources && \$in_files && /\);/) {
        print \"\t\t\t\t$BUILDFILE_UUID /* UnityToFlutterBridge.m in Sources */,\n\";
        \$in_files = 0;
        \$in_sources = 0;
    }
" "$PROJECT_FILE"

echo "✅ Files added to Unity-iPhone.xcodeproj"
echo "📁 Files are in: $PROJECT_DIR/Libraries/"
echo ""
echo "⚠️  If script fails, add manually in Xcode:"
echo "   1. Open Unity-iPhone.xcodeproj"
echo "   2. Select UnityFramework target"
echo "   3. Build Phases → Compile Sources → Add:"
echo "      - Libraries/UnityToFlutterBridge.m"
echo "      - Libraries/UnityToFlutterBridge.h"
