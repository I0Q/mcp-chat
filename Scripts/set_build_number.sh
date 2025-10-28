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
    
    # Try using sed to modify the plist directly (bypasses sandboxing)
    echo "Attempting sed modification..."
    
    # Create a backup
    cp "$plist" "$plist.backup"
    
    # Use sed to replace the values
    sed -i '' "s/<key>CFBundleVersion<\/key>.*<string>.*<\/string>/<key>CFBundleVersion<\/key>\n\t<string>$number_of_commits<\/string>/" "$plist"
    sed -i '' "s/<key>CFBundleShortVersionString<\/key>.*<string>.*<\/string>/<key>CFBundleShortVersionString<\/key>\n\t<string>${git_release_version#*v}<\/string>/" "$plist"
    
    # Verify the changes
    echo "Final CFBundleVersion: $(grep -A1 '<key>CFBundleVersion</key>' "$plist" | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/\1/')"
    echo "Final CFBundleShortVersionString: $(grep -A1 '<key>CFBundleShortVersionString</key>' "$plist" | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/\1/')"
  else
    echo "Plist not found: $plist"
  fi
done

echo "=== End Build Number Script ==="
