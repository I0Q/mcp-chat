#!/bin/bash

# Modern versioning using agvtool - no hardcoding!
# This script syncs Xcode version with git tags and commit counts

set -euo pipefail

echo "=== Modern Version Sync Script ==="

# Get git information - use the project root
cd "$SRCROOT"
GIT_DIR=".git"
export GIT_DIR

# Get the latest git tag (e.g., v1.2)
GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0")
echo "Git tag: $GIT_TAG"

# Extract version number from tag (remove 'v' prefix)
MARKETING_VERSION="${GIT_TAG#v}"
echo "Marketing version: $MARKETING_VERSION"

# Get commit count since last tag
COMMIT_COUNT=$(git rev-list --count HEAD ^$(git describe --tags --abbrev=0) 2>/dev/null || echo "0")
echo "Commits since last tag: $COMMIT_COUNT"

# Calculate build number (base + commits since tag)
BASE_BUILD=1000  # Start from 1000 to avoid conflicts
BUILD_NUMBER=$((BASE_BUILD + COMMIT_COUNT))
echo "Build number: $BUILD_NUMBER"

# Use agvtool to set the versions
echo "Setting marketing version to: $MARKETING_VERSION"
xcrun agvtool new-marketing-version "$MARKETING_VERSION"

echo "Setting build number to: $BUILD_NUMBER"
xcrun agvtool new-version -all "$BUILD_NUMBER"

echo "=== Version sync complete ==="
echo "Final version: $MARKETING_VERSION ($BUILD_NUMBER)"
