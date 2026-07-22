# Changelog

All notable changes are documented here. The project follows Semantic Versioning.

## [Unreleased]

### Added

- Native SwiftUI dashboard and menu-bar interface.
- Codex App Server JSONL client with reconnect backoff.
- Multi-bucket rate-limit parser and deterministic hybrid-stop policy.
- macOS and Telegram notifications.
- Keychain secret storage and redacted local event logging.
- Accessibility soft-stop, exact-target idle close, and scoped emergency stop.
- Launch-at-login support.
- CI, release packaging, documentation, security model, and 20-pass audit record.

### Security

- Fail-safe behavior when Accessibility permission is absent.
- Stale quota snapshots cannot trigger new stop actions.
- Action throttling prevents repeated stop/terminate loops.
- No broad process-name substring matching.
