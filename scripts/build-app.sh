#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { echo "build-app.sh requires macOS" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Codex Limit Guard"
PRODUCT="CodexLimitGuard"
BUNDLE_ID="dev.mishkacher.CodexLimitGuard"
VERSION="${VERSION:-0.1.0}"
VERSION="${VERSION#v}"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
CONTENTS="$APP/Contents"

rm -rf "$APP" "$DIST/Codex-Limit-Guard-macOS.zip" "$DIST/AppIcon.iconset" "$DIST/AppIcon-1024.png"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$DIST"

swift build -c release --product "$PRODUCT"
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/$PRODUCT" "$CONTENTS/MacOS/$PRODUCT"
chmod 755 "$CONTENTS/MacOS/$PRODUCT"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$PRODUCT</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAccessibilityUsageDescription</key><string>Codex Limit Guard uses Accessibility only to detect and press task-stop controls in exact Codex and ChatGPT applications.</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Codex Limit Guard contributors</string>
</dict>
</plist>
PLIST

swift "$ROOT/scripts/generate-icon.swift" "$DIST/AppIcon-1024.png"
ICONSET="$DIST/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  set -- $spec
  sips -z "$1" "$1" "$DIST/AppIcon-1024.png" --out "$ICONSET/$2" >/dev/null
 done
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Codex-Limit-Guard-macOS.zip"

printf 'Built: %s\n' "$APP"
printf 'Archive: %s\n' "$DIST/Codex-Limit-Guard-macOS.zip"
