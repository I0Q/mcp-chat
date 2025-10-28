# Git-based Versioning

This project uses git-based versioning that automatically updates the app version based on the current git branch and commit hash.

## How it works

- **Version**: `{branch-name}-{commit-hash}` (e.g., `multi-mcp-89ddc9d`)
- **Build Number**: Total commit count
- **Updates**: Run the script before building

## Usage

```bash
# Update version before building
bash Scripts/update_version_from_git.sh

# Then build in Xcode
# App will show: Version multi-mcp-89ddc9d (220)
```

## For team members

1. Clone the repository
2. Run `bash Scripts/update_version_from_git.sh` before building
3. Build in Xcode
4. Version automatically reflects current git state

## Files

- `Scripts/update_version_from_git.sh` - Main versioning script
- `HelloWorld/HelloWorld.xcodeproj/project.pbxproj` - Updated by script
- `HelloWorld/HelloWorld/SettingsView.swift` - Displays version from Bundle.main
