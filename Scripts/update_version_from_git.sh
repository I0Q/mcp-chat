#!/bin/bash

# Git-based versioning script
# This script updates Xcode build settings based on git tags and commits

set -euo pipefail

echo "=== Git-based Version Update ==="

# Get git information
GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0")
echo "Git tag: $GIT_TAG"

# Extract version number from tag (remove 'v' prefix)
MARKETING_VERSION="${GIT_TAG#v}"
echo "Marketing version: $MARKETING_VERSION"

# Get commit count since last tag
COMMIT_COUNT=$(git rev-list --count HEAD ^$(git describe --tags --abbrev=0) 2>/dev/null || echo "0")
echo "Commits since last tag: $COMMIT_COUNT"

# Calculate build number (base + commits since tag)
BASE_BUILD=1000
BUILD_NUMBER=$((BASE_BUILD + COMMIT_COUNT))
echo "Build number: $BUILD_NUMBER"

# Update the project.pbxproj file
PROJECT_FILE="HelloWorld/HelloWorld.xcodeproj/project.pbxproj"

if [ -f "$PROJECT_FILE" ]; then
    echo "Updating $PROJECT_FILE..."
    
    # Use sed to update MARKETING_VERSION
    sed -i.bak "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $MARKETING_VERSION;/g" "$PROJECT_FILE"
    
    # Use sed to update CURRENT_PROJECT_VERSION
    sed -i.bak "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" "$PROJECT_FILE"
    
    # Clean up backup files
    rm -f "$PROJECT_FILE.bak"
    
    echo "✅ Updated MARKETING_VERSION to: $MARKETING_VERSION"
    echo "✅ Updated CURRENT_PROJECT_VERSION to: $BUILD_NUMBER"
    echo "Final version: $MARKETING_VERSION ($BUILD_NUMBER)"
else
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "=== Git versioning complete ==="
