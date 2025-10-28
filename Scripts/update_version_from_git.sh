#!/bin/bash

# Git-based versioning script
# This script updates Xcode build settings based on git tags and commits

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

# Create a version plist file that the app can read
VERSION_PLIST="$TARGET_BUILD_DIR/version.plist"

echo "Creating $VERSION_PLIST..."

cat > "$VERSION_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>version</key>
    <string>$MARKETING_VERSION</string>
    <key>buildNumber</key>
    <string>$BUILD_NUMBER</string>
    <key>branch</key>
    <string>$GIT_BRANCH</string>
    <key>hash</key>
    <string>$GIT_HASH</string>
</dict>
</plist>
EOF

echo "✅ Created version.plist with:"
echo "   Version: $MARKETING_VERSION"
echo "   Build: $BUILD_NUMBER"
echo "   Branch: $GIT_BRANCH"
echo "   Hash: $GIT_HASH"

# Copy the plist to the app bundle
if [ -d "$CODESIGNING_FOLDER_PATH" ]; then
    cp "$VERSION_PLIST" "$CODESIGNING_FOLDER_PATH/"
    echo "✅ Copied version.plist to app bundle"
else
    echo "⚠️  App bundle not found, plist will be copied later"
fi

echo "=== Git versioning complete ==="