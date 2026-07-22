#!/usr/bin/env bash
set -euo pipefail

expected_b64="$(awk -F= '/^base64_sha256=/{print $2}' bootstrap/READY)"
expected_archive="$(awk -F= '/^archive_sha256=/{print $2}' bootstrap/READY)"
expected_chunks="$(awk -F= '/^chunks=/{print $2}' bootstrap/READY)"
actual_chunks="$(find bootstrap -name 'chunk-*' -type f | wc -l | tr -d ' ')"

cat bootstrap/chunk-* > /tmp/project.tar.gz.b64
actual_b64="$(shasum -a 256 /tmp/project.tar.gz.b64 | awk '{print $1}')"

printf 'Chunks: actual=%s expected=%s\n' "$actual_chunks" "$expected_chunks"
printf 'Base64 bytes: %s\n' "$(wc -c < /tmp/project.tar.gz.b64 | tr -d ' ')"
printf 'Base64 SHA-256: actual=%s expected=%s\n' "$actual_b64" "$expected_b64"

test "$actual_chunks" = "$expected_chunks"
test "$actual_b64" = "$expected_b64"

base64 -D < /tmp/project.tar.gz.b64 > /tmp/codex-limit-guard-project.tar.gz
actual_archive="$(shasum -a 256 /tmp/codex-limit-guard-project.tar.gz | awk '{print $1}')"
printf 'Archive bytes: %s\n' "$(wc -c < /tmp/codex-limit-guard-project.tar.gz | tr -d ' ')"
printf 'Archive SHA-256: actual=%s expected=%s\n' "$actual_archive" "$expected_archive"
test "$actual_archive" = "$expected_archive"

tar -tzf /tmp/codex-limit-guard-project.tar.gz >/dev/null
tar -xzf /tmp/codex-limit-guard-project.tar.gz -C .
rm -rf bootstrap project.tar.gz.b64
rm -f .github/workflows/bootstrap-project.yml .github/workflows/bootstrap-chunks.yml

echo 'Audited project tree reassembled successfully.'
