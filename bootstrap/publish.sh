#!/usr/bin/env bash
set -euo pipefail

DIAGNOSTIC="bootstrap/diagnostic.txt"
: > "$DIAGNOSTIC"
log() { printf '%s\n' "$*" | tee -a "$DIAGNOSTIC"; }
fail() { log "FAIL: $*"; exit 2; }

expected_b64="$(awk -F= '/^base64_sha256=/{print $2}' bootstrap/READY)"
expected_archive="$(awk -F= '/^archive_sha256=/{print $2}' bootstrap/READY)"
expected_chunks="$(awk -F= '/^chunks=/{print $2}' bootstrap/READY)"
actual_chunks="$(find bootstrap -name 'chunk-*' -type f | wc -l | tr -d ' ')"

cat bootstrap/chunk-* > /tmp/project.tar.gz.b64
actual_b64="$(shasum -a 256 /tmp/project.tar.gz.b64 | awk '{print $1}')"
base64_bytes="$(wc -c < /tmp/project.tar.gz.b64 | tr -d ' ')"

log "Chunks: actual=$actual_chunks expected=$expected_chunks"
log "Base64 bytes: $base64_bytes expected=56448"
log "Base64 SHA-256: actual=$actual_b64 expected=$expected_b64"

[[ "$actual_chunks" == "$expected_chunks" ]] || fail "chunk count mismatch"
[[ "$base64_bytes" == "56448" ]] || fail "base64 byte count mismatch"
[[ "$actual_b64" == "$expected_b64" ]] || fail "base64 checksum mismatch"

if ! base64 -D < /tmp/project.tar.gz.b64 > /tmp/codex-limit-guard-project.tar.gz; then
  fail "BSD base64 decoder rejected the payload"
fi
actual_archive="$(shasum -a 256 /tmp/codex-limit-guard-project.tar.gz | awk '{print $1}')"
archive_bytes="$(wc -c < /tmp/codex-limit-guard-project.tar.gz | tr -d ' ')"
log "Archive bytes: $archive_bytes expected=42335"
log "Archive SHA-256: actual=$actual_archive expected=$expected_archive"

[[ "$archive_bytes" == "42335" ]] || fail "archive byte count mismatch"
[[ "$actual_archive" == "$expected_archive" ]] || fail "archive checksum mismatch"
tar -tzf /tmp/codex-limit-guard-project.tar.gz >/dev/null || fail "tar archive validation failed"

tar -xzf /tmp/codex-limit-guard-project.tar.gz -C .
rm -rf bootstrap project.tar.gz.b64
rm -f .github/workflows/bootstrap-project.yml .github/workflows/bootstrap-chunks.yml

echo 'Audited project tree reassembled successfully.'
