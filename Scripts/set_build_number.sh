#!/bin/bash

git=$(sh /etc/profile; which git)
number_of_commits=$("$git" rev-list HEAD --count)
git_release_version=$("$git" describe --tags --always --abbrev=0)

echo "=== Build Number Script Debug ==="
echo "Script running from: $(pwd)"
echo "Git version: $git_release_version"
echo "Build number: $number_of_commits"
echo "Setting MARKETING_VERSION to: ${git_release_version#*v}"
echo "Setting CURRENT_PROJECT_VERSION to: $number_of_commits"

# Export the values as environment variables that Xcode will use
export MARKETING_VERSION="${git_release_version#*v}"
export CURRENT_PROJECT_VERSION="$number_of_commits"

# Also try to write them to a file that we can source later
echo "MARKETING_VERSION=${git_release_version#*v}" > "$TARGET_TEMP_DIR/version_info"
echo "CURRENT_PROJECT_VERSION=$number_of_commits" >> "$TARGET_TEMP_DIR/version_info"

echo "=== End Build Number Script ==="
