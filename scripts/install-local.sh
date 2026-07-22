#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build-app.sh"

DESTINATION="${DESTINATION:-$HOME/Applications}"
mkdir -p "$DESTINATION"
rm -rf "$DESTINATION/Codex Limit Guard.app"
/usr/bin/ditto "$ROOT/dist/Codex Limit Guard.app" "$DESTINATION/Codex Limit Guard.app"
open "$DESTINATION/Codex Limit Guard.app"
printf 'Installed to %s\n' "$DESTINATION/Codex Limit Guard.app"
