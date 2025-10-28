#!/bin/bash

git=$(sh /etc/profile; which git)
number_of_commits=$("$git" rev-list HEAD --count)
git_release_version=$("$git" describe --tags --always --abbrev=0)

target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"

echo "=== Build Number Script Debug ==="
echo "Script running from: $(pwd)"
echo "Git version: $git_release_version"
echo "Build number: $number_of_commits"
echo "Target plist: $target_plist"
echo "DSYM plist: $dsym_plist"
echo "TARGET_BUILD_DIR: $TARGET_BUILD_DIR"
echo "INFOPLIST_PATH: $INFOPLIST_PATH"
echo "SRCROOT: $SRCROOT"

for plist in "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    echo "Found plist: $plist"
    echo "Setting CFBundleVersion to: $number_of_commits"
    echo "Setting CFBundleShortVersionString to: ${git_release_version#*v}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $number_of_commits" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${git_release_version#*v}" "$plist"
  else
    echo "Plist not found: $plist"
  fi
done

echo "=== End Build Number Script ==="
