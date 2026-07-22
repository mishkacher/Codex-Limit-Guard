#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SKIP_TESTS=false
[[ "${1:-}" == "--skip-tests" ]] && SKIP_TESTS=true

fail() { printf 'AUDIT FAILED: %s\n' "$*" >&2; exit 1; }
pass() { printf '✓ %s\n' "$*"; }

if ! $SKIP_TESTS; then
  swift test >/dev/null
  pass "Swift core tests"
fi

if grep -RInE 'try!|fatalError\(|TODO:|FIXME:' Sources Tests --include='*.swift'; then
  fail "Unsafe or unfinished Swift marker found"
fi
pass "No force-try, fatalError, TODO, or FIXME markers"

if grep -RInE '(killall|pkill|/usr/bin/kill|Process\.arguments.*kill)' Sources scripts --exclude='audit.sh'; then
  fail "Broad process-kill primitive found"
fi
pass "No broad process-kill primitive"

grep -q 'account/rateLimits/read' Sources/CodexLimitGuardCore/JSONRPC.swift || fail "Missing rate-limit read method"
grep -q 'rateLimitsByLimitId' Sources/CodexLimitGuardCore/RateLimitParser.swift || fail "Missing multi-bucket parser"
pass "Codex rate-limit protocol assertions"

grep -q 'guard isTrusted else { return 0 }' Sources/CodexLimitGuardMac/AccessibilityController.swift || fail "Idle-close fail-safe missing"
grep -q 'exactBundleIdentifiers' Sources/CodexLimitGuardMac/AccessibilityController.swift || fail "Exact bundle targeting missing"
grep -q 'bundleIdentifier == nil' Sources/CodexLimitGuardMac/AccessibilityController.swift || fail "Safe name fallback invariant missing"
pass "Accessibility and exact-target safety assertions"

grep -q 'isSnapshotFresh' Sources/CodexLimitGuardMac/AppModel.swift || fail "Snapshot freshness guard missing"
grep -q 'ActionThrottleKey' Sources/CodexLimitGuardMac/AppModel.swift || fail "Action throttling missing"
pass "Freshness and action-throttling assertions"

grep -q 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' Sources/CodexLimitGuardMac/KeychainStore.swift || fail "Keychain accessibility class missing"
grep -q 'SecretRedactor' Sources/CodexLimitGuardMac/EventLogger.swift || fail "Log redaction missing"
pass "Secret-storage and log-redaction assertions"

for required in README.md SECURITY.md CONTRIBUTING.md LICENSE docs/ARCHITECTURE.md docs/THREAT-MODEL.md docs/AUDIT-LOG.md; do
  [[ -s "$required" ]] || fail "Required project file is missing: $required"
done
pass "Public project documentation"

swift package dump-package >/dev/null
pass "Swift package manifest"

printf '\nAll static audit checks passed.\n'
