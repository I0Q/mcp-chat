#!/bin/bash

# Git-based versioning script
# This script updates Xcode build settings based on git tags and commits
# Run this BEFORE building in Xcode

set -euo pipefail

echo "=== Git-based Version Update ==="

# Get git information
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Git branch: $GIT_BRANCH"

GIT_HASH=$(git rev-parse --short HEAD)
echo "Git hash: $GIT_HASH"

# Create version from branch name and hash
MARKETING_VERSION="${GIT_BRANCH}-${GIT_HASH}"
echo "Marketing version: $MARKETING_VERSION"

# Get total commit count for build number
COMMIT_COUNT=$(git rev-list --count HEAD)
echo "Total commits: $COMMIT_COUNT"

BUILD_NUMBER=$COMMIT_COUNT
echo "Build number: $BUILD_NUMBER"

# Update the project.pbxproj file directly
PROJECT_FILE="HelloWorld/HelloWorld.xcodeproj/project.pbxproj"

if [ -f "$PROJECT_FILE" ]; then
    echo "Updating $PROJECT_FILE..."
    
    # Create backup
    cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
    
    # Use sed to update MARKETING_VERSION
    sed -i.tmp "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $MARKETING_VERSION;/g" "$PROJECT_FILE"
    
    # Use sed to update CURRENT_PROJECT_VERSION
    sed -i.tmp "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" "$PROJECT_FILE"
    
    # Clean up temp files
    rm -f "$PROJECT_FILE.tmp"
    
    echo "✅ Updated MARKETING_VERSION to: $MARKETING_VERSION"
    echo "✅ Updated CURRENT_PROJECT_VERSION to: $BUILD_NUMBER"
    echo "Final version: $MARKETING_VERSION ($BUILD_NUMBER)"
else
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "=== Git versioning complete ==="
echo "Now build in Xcode to see the updated version!"