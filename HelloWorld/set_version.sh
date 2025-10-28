#!/bin/bash

# Get current git branch name
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

# Remove special characters that might cause issues
BRANCH_NAME=$(echo "$BRANCH_NAME" | sed 's/[^a-zA-Z0-9._-]//g')

# Set the version as a build setting
echo "GIT_BRANCH_VERSION = $BRANCH_NAME" > "${SRCROOT}/version.xcconfig"

echo "Set GIT_BRANCH_VERSION to: $BRANCH_NAME"
