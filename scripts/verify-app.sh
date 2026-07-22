#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/Codex Limit Guard.app"
ZIP="$ROOT/dist/Codex-Limit-Guard-macOS.zip"

[[ -x "$APP/Contents/MacOS/CodexLimitGuard" ]] || { echo "Missing executable" >&2; exit 1; }
[[ -f "$APP/Contents/Info.plist" ]] || { echo "Missing Info.plist" >&2; exit 1; }
[[ -f "$APP/Contents/Resources/AppIcon.icns" ]] || { echo "Missing app icon" >&2; exit 1; }
[[ -s "$ZIP" ]] || { echo "Missing ZIP artifact" >&2; exit 1; }

/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/ditto -x -k "$ZIP" "$(mktemp -d)"

echo "App bundle verification passed."
