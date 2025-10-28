#!/bin/bash

# Git-based versioning script
# Updates Xcode build settings with current git branch + hash + commit count
# Run this BEFORE building in Xcode

set -euo pipefail

echo "=== Git Version Update ==="

# Get git information
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_HASH=$(git rev-parse --short HEAD)
COMMIT_COUNT=$(git rev-list --count HEAD)

# Create version from branch name and hash
MARKETING_VERSION="${GIT_BRANCH}-${GIT_HASH}"
BUILD_NUMBER=$COMMIT_COUNT

echo "Branch: $GIT_BRANCH"
echo "Hash: $GIT_HASH"
echo "Version: $MARKETING_VERSION"
echo "Build: $BUILD_NUMBER"

# Update project.pbxproj
PROJECT_FILE="HelloWorld.xcodeproj/project.pbxproj"

if [ -f "$PROJECT_FILE" ]; then
    # Create backup
    cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
    
    # Update MARKETING_VERSION
    sed -i.tmp "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $MARKETING_VERSION;/g" "$PROJECT_FILE"
    
    # Update CURRENT_PROJECT_VERSION
    sed -i.tmp "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" "$PROJECT_FILE"
    
    # Clean up
    rm -f "$PROJECT_FILE.tmp"
    
    echo "✅ Updated project file"
    echo "✅ Version: $MARKETING_VERSION ($BUILD_NUMBER)"
else
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "=== Complete ==="
echo "Now build in Xcode to see the updated version!"