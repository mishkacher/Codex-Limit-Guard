#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

rounds=(
  requirements architecture thresholds boundaries notification-lifecycle
  parser app-server connection-ownership grace-task new-task-block
  accessibility-trust process-targeting emergency-stop throttling stale-data
  secrets ui-consistency macos-compatibility packaging final-regression
)

for index in "${!rounds[@]}"; do
  number=$((index + 1))
  printf '\n[%02d/20] %s\n' "$number" "${rounds[$index]}"
  ./scripts/audit.sh --skip-tests
  if [[ "$number" -eq 1 || "$number" -eq 20 ]]; then
    swift test >/dev/null
  elif [[ "$number" -eq 6 ]]; then
    swift test --filter RateLimitParserTests >/dev/null
  elif [[ "$number" -eq 10 ]]; then
    swift test --filter GuardPolicyTests >/dev/null
  elif [[ "$number" -eq 16 ]]; then
    swift test --filter RedactorTests >/dev/null
  fi
done

printf '\nTwenty focused audit passes completed successfully.\n'
