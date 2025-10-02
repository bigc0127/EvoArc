#!/bin/bash

# Post-Archive Fix Script for EvoArc
# This script adds the missing Info.plist to iOS archives

# Usage: ./fix-archive.sh <path-to-archive>

ARCHIVE_PATH="$1"

if [ -z "$ARCHIVE_PATH" ]; then
    echo "Usage: $0 <path-to-archive>"
    echo "Example: $0 ~/Library/Developer/Xcode/Archives/2025-09-30/EvoArc.xcarchive"
    exit 1
fi

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "Error: Archive not found at $ARCHIVE_PATH"
    exit 1
fi

# Check if Info.plist already exists
if [ -f "$ARCHIVE_PATH/Info.plist" ]; then
    echo "Info.plist already exists in archive"
    exit 0
fi

# Get bundle identifier from app
APP_PATH="$ARCHIVE_PATH/Products/Applications/EvoArc.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Info.plist" 2>/dev/null)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Info.plist" 2>/dev/null)

if [ -z "$BUNDLE_ID" ]; then
    echo "Error: Could not read bundle identifier from app"
    exit 1
fi

echo "Creating archive Info.plist..."
echo "Bundle ID: $BUNDLE_ID"
echo "Version: $VERSION"
echo "Build: $BUILD"

# Create Info.plist
cat > "$ARCHIVE_PATH/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ApplicationProperties</key>
	<dict>
		<key>ApplicationPath</key>
		<string>Applications/EvoArc.app</string>
		<key>CFBundleIdentifier</key>
		<string>$BUNDLE_ID</string>
		<key>CFBundleShortVersionString</key>
		<string>$VERSION</string>
		<key>CFBundleVersion</key>
		<string>$BUILD</string>
		<key>SigningIdentity</key>
		<string>Apple Development</string>
		<key>Team</key>
		<string>69LLXLJW63</string>
	</dict>
	<key>ArchiveVersion</key>
	<integer>2</integer>
	<key>CreationDate</key>
	<date>$(date -u +"%Y-%m-%dT%H:%M:%SZ")</date>
	<key>Name</key>
	<string>EvoArc</string>
	<key>SchemeName</key>
	<string>EvoArc</string>
</dict>
</plist>
EOF

echo "✅ Archive Info.plist created successfully!"
echo "Archive is now ready for distribution"
