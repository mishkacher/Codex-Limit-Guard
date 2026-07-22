#!/bin/bash
set -euo pipefail
rm -rf "$HOME/Applications/Codex Limit Guard.app"
rm -rf "$HOME/Library/Application Support/Codex Limit Guard"
defaults delete dev.mishkacher.CodexLimitGuard 2>/dev/null || true
printf 'Codex Limit Guard app and local logs were removed. Keychain items can be removed from Keychain Access.\n'
