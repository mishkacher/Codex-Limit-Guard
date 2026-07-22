# Twenty-pass optimization and audit log

This is a focused engineering review record for the initial public foundation. It is not a claim of independent third-party certification. Each pass reviewed a distinct risk surface; findings were corrected before the final regression run.

| Pass | Focus | Finding / optimization | Result |
|---:|---|---|---|
| 1 | Product requirements | Confirmed independent monitoring, no wrapper launch requirement, public-project scope | Architecture fixed around a separate telemetry connection |
| 2 | Repository architecture | Initial script prototype was unsuitable for a public native product | Rebuilt as Swift core + macOS SwiftUI executable |
| 3 | Threshold invariants | Recovery at 18% initially conflicted conceptually with warning at 20% | Block and warning hysteresis separated; invariant documented |
| 4 | Boundary behavior | Verified exact 20/15/12/10 percent transitions | Added deterministic boundary tests |
| 5 | Warning lifecycle | Warning state did not re-arm after full healthy recovery | Notification state now clears above warning threshold; regression test added |
| 6 | Multi-bucket parsing | Legacy and named buckets could duplicate the same window | Normalization and de-duplication added |
| 7 | App Server lifecycle | Unexpected process exits needed bounded reconnect behavior | Serial client, cleanup, and exponential backoff added |
| 8 | Connection ownership | A separate App Server cannot directly interrupt another connection's turn | External stop isolated behind Accessibility adapter |
| 9 | Grace-task policy | Need to allow one task already active at the 15% boundary | Explicit grace state and completion transition added |
| 10 | New-task enforcement | A new task after grace could bypass a simple idle-close rule | Armed block detects and soft-stops subsequent active work |
| 11 | Missing Accessibility trust | Unknown active state could be misclassified as idle | 15–12% actions now fail closed without permission |
| 12 | Process targeting | Name-only matching could affect an unrelated process | Exact bundle IDs; exact bundle filename fallback only when ID is absent |
| 13 | Emergency termination | Immediate force-kill was unnecessarily destructive | Graceful terminate first, force after delay if still running |
| 14 | Repeated actions | Two-second activity polling could repeat stop actions and logs | Per-action cooldowns added |
| 15 | Stale telemetry | Old low quota could trigger actions after disconnect | Freshness gate added before policy evaluation |
| 16 | Secret handling | Telegram configuration needed persistence without plaintext preferences | Keychain storage and secret-redacted logs added |
| 17 | UI state consistency | Settings view could instantiate a second settings object | All views now bind to the canonical `AppModel.settings` instance |
| 18 | macOS compatibility | Some UI and notification APIs required macOS 14 or special entitlements | Replaced with macOS 13-compatible, entitlement-free alternatives |
| 19 | Packaging and supply chain | Public project needed reproducible app bundle and checksums | Build, install, audit, CI, and release scripts added |
| 20 | Final regression | Re-ran tests, safety assertions, native compilation, docs, and packaging | Passed on macOS CI; verified native `.app` bundle uploaded as an artifact |

## Current automated coverage

- rate-limit response and notification parsing;
- multi-bucket ordering and percentage clamping;
- JSONL handshake/message framing;
- threshold validation;
- warning, block, soft-stop, hard-stop, grace, recovery, and re-arm behavior;
- bearer and Telegram token redaction.

## Validation evidence

The final macOS gate compiles the SwiftUI/AppKit target with Swift 5.10, runs all package tests, executes the static safety audit, ad-hoc signs the application, verifies its bundle structure, and uploads the resulting ZIP. The production CI repeats this on pull requests and `main`, with an additional Linux core-test job under Swift 6.

## Residual risks

- Accessibility selectors can drift after a Codex UI update.
- Community release artifacts are not notarized until a signing identity is configured.
- New-task prevention is best effort between observations, not a kernel-level or API-level lock.
- A real-device smoke test is still required whenever Codex or ChatGPT materially changes its Accessibility tree.
