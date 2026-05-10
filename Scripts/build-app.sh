#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ASUS Fusion VPN"
APP_VERSION="1.0.6"
APP_BUILD="7"
BUILD_DIR="$ROOT_DIR/.build/apple/Products/Release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_BUILD_DIR="$ROOT_DIR/.build/dmg"
DMG_MOUNT_DIR="/Volumes/$APP_NAME"
DMG_BACKGROUND_DIR="$DMG_BUILD_DIR/background"
DMG_BACKGROUND_PATH="$DMG_BACKGROUND_DIR/dmg-background.png"
RW_DMG_PATH="$DMG_BUILD_DIR/$APP_NAME-rw.dmg"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

cd "$ROOT_DIR"
swift build -c release --arch arm64 --arch x86_64

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
swift "$ROOT_DIR/Scripts/generate-icons.swift" "$RESOURCES_DIR" "$ROOT_DIR/Assets/AppIcon/asus-fusion-vpn-icon-source.png"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>ASUS Fusion VPN</string>
  <key>CFBundleIdentifier</key>
  <string>com.moebis.asus-fusion-vpn</string>
  <key>CFBundleName</key>
  <string>ASUS Fusion VPN</string>
  <key>CFBundleDisplayName</key>
  <string>ASUS Fusion VPN</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>__APP_VERSION__</string>
  <key>CFBundleVersion</key>
  <string>__APP_BUILD__</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST
sed -i '' \
  -e "s/__APP_VERSION__/$APP_VERSION/g" \
  -e "s/__APP_BUILD__/$APP_BUILD/g" \
  "$CONTENTS_DIR/Info.plist"

rm -rf "$DMG_BUILD_DIR"
mkdir -p "$DMG_BUILD_DIR" "$DMG_BACKGROUND_DIR"
swift "$ROOT_DIR/Scripts/generate-dmg-background.swift" \
  "$DMG_BACKGROUND_PATH" \
  "$ROOT_DIR/Assets/AppIcon/asus-fusion-vpn-icon-source.png"

if [ -d "/Volumes/$APP_NAME" ]; then
  hdiutil detach "/Volumes/$APP_NAME" >/dev/null 2>&1 || true
fi

hdiutil create \
  -volname "$APP_NAME" \
  -size 80m \
  -fs HFS+ \
  -ov \
  "$RW_DMG_PATH" >/dev/null
hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  "$RW_DMG_PATH" >/dev/null

cp -R "$APP_DIR" "$DMG_MOUNT_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_MOUNT_DIR/Applications"
mkdir -p "$DMG_MOUNT_DIR/.background"
cp "$DMG_BACKGROUND_PATH" "$DMG_MOUNT_DIR/.background/dmg-background.png"
SetFile -a V "$DMG_MOUNT_DIR/.background"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 1000, 600}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set background picture of viewOptions to file ".background:dmg-background.png"
    set position of item "$APP_NAME.app" of container window to {250, 275}
    set position of item "Applications" of container window to {650, 275}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

cp "$RESOURCES_DIR/AppIcon.icns" "$DMG_MOUNT_DIR/.VolumeIcon.icns"
SetFile -t icns -c icnC "$DMG_MOUNT_DIR/.VolumeIcon.icns"
SetFile -a V "$DMG_MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$DMG_MOUNT_DIR"

sync
hdiutil detach "$DMG_MOUNT_DIR" >/dev/null
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -rf "$DMG_BUILD_DIR"
rm -f "$DIST_DIR/.DS_Store"

echo "Built: $APP_DIR"
echo "Built: $DMG_PATH"
