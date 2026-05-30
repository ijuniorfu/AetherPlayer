#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
APP_NAME="${APP_NAME:-AetherPlayer}"
SCHEME="AetherPlayer"
DEVELOPER_ID="${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application: ...' identity}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

# Extract team ID from the Developer ID string: "Developer ID Application: Name (TEAMID)"
TEAM_ID="${DEVELOPER_ID##*(}"
TEAM_ID="${TEAM_ID%)}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 1. Universal archive (arm64 + x86_64 via ARCHS_STANDARD / ONLY_ACTIVE_ARCH=NO).
xcodebuild -project AetherPlayer.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" archive ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID"

# 2. Export with Developer ID signing.
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

APP="$EXPORT_DIR/$APP_NAME.app"

# 3. Package into a .dmg.
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG"

# 4. Notarize + staple (skipped if NOTARY_PROFILE unset; local smoke test only).
if [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler staple "$APP"
else
  echo "NOTARY_PROFILE unset: built + signed but NOT notarized (won't pass Gatekeeper elsewhere)."
fi

echo "Output: $DMG"
