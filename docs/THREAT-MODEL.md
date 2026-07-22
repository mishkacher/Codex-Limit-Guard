# Threat model

## Protected assets

- Remaining Codex quota.
- Unsaved work inside Codex/ChatGPT.
- Telegram bot token.
- User privacy and local conversation content.
- Integrity of unrelated applications and processes.

## Trust boundaries

| Boundary | Trust assumption | Mitigation |
|---|---|---|
| Codex App Server stdout | Structured but version-evolving local data | Strict parsing, ignored unrelated messages, reconnect backoff, freshness window |
| Accessibility tree | User-authorized, UI-version dependent | Exact target app identity, limited role/value inspection, bounded traversal |
| Process termination | High-impact local action | Configurable hard stop, exact bundle matching, graceful terminate before force |
| Telegram API | External network service | Opt-in only, token in Keychain, request timeout, no prompt content |
| Event log | Local persistent data | Secret redaction, metadata-only events, bounded in-memory history |

## Abuse and failure scenarios

### Accessibility permission missing

Risk: an active task may look idle.

Mitigation: idle-close and soft-stop actions fail closed. The guard logs that permission is required rather than terminating at the 15–12% levels.

### UI selector drift

Risk: Codex renames or restructures its Stop button.

Mitigation: a bounded search over button/control roles, localized action words, Escape fallback, diagnostic event, and optional hard stop only at the lowest threshold.

### Unrelated process termination

Risk: a broad process-name match could terminate another app.

Mitigation: known bundle identifiers are preferred. Name fallback is accepted only when the bundle identifier is absent and the exact bundle filename is `ChatGPT.app` or `Codex.app`.

### Stale quota data

Risk: a disconnected monitor might act on an old low percentage.

Mitigation: snapshots older than the greater of 120 seconds or three polling intervals never trigger new policy actions.

### Repeated action loop

Risk: polling could press Stop or terminate repeatedly.

Mitigation: action-specific cooldowns and state-machine transition deduplication.

### Secret disclosure

Risk: Telegram token appears in logs or support bundles.

Mitigation: Keychain-only storage and regex-based redaction of Telegram tokens, bearer tokens, and OpenAI-like secrets before persistence.

## Out of scope

- Protecting against a malicious local administrator.
- Preventing a user from manually disabling or quitting the guard.
- Atomic prevention of a new task between UI observation intervals.
- Guaranteeing compatibility with undocumented future Codex UI changes.
- Apple code-signing or notarization until a trusted signing identity is available.
