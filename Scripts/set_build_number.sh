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
    
    # Try using defaults first (works better with sandboxing)
    defaults write "$plist" CFBundleVersion "$number_of_commits" 2>/dev/null || echo "defaults write failed for CFBundleVersion"
    defaults write "$plist" CFBundleShortVersionString "${git_release_version#*v}" 2>/dev/null || echo "defaults write failed for CFBundleShortVersionString"
    
    # Fallback to PlistBuddy if defaults fails
    if ! defaults read "$plist" CFBundleVersion >/dev/null 2>&1; then
      echo "Falling back to PlistBuddy for CFBundleVersion"
      /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $number_of_commits" "$plist" 2>/dev/null || echo "PlistBuddy also failed for CFBundleVersion"
    fi
    
    if ! defaults read "$plist" CFBundleShortVersionString >/dev/null 2>&1; then
      echo "Falling back to PlistBuddy for CFBundleShortVersionString"
      /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${git_release_version#*v}" "$plist" 2>/dev/null || echo "PlistBuddy also failed for CFBundleShortVersionString"
    fi
    
    # Verify the values were set
    echo "Final CFBundleVersion: $(defaults read "$plist" CFBundleVersion 2>/dev/null || echo 'NOT SET')"
    echo "Final CFBundleShortVersionString: $(defaults read "$plist" CFBundleShortVersionString 2>/dev/null || echo 'NOT SET')"
  else
    echo "Plist not found: $plist"
  fi
done

echo "=== End Build Number Script ==="
