# Architecture

## Goals

Codex Limit Guard monitors quota without changing how the user launches or uses Codex. Policy logic must remain deterministic, testable, and independent from SwiftUI or macOS process APIs.

## Components

### `CodexLimitGuardCore`

A platform-independent Swift library containing:

- quota-window models;
- JSONL/JSON-RPC message construction;
- multi-bucket rate-limit parsing;
- threshold validation;
- the stateful hybrid protection policy;
- secret redaction.

The core has no AppKit, SwiftUI, Security, ServiceManagement, or UserNotifications dependency and is tested on Linux and macOS.

### `CodexLimitGuardMac`

The macOS executable contains narrow adapters:

- `CodexAppServerClient` — owns a separate `codex app-server` process over local stdio;
- `AccessibilityController` — observes and presses task-control elements in exact target GUI apps;
- `NotificationService` and `TelegramNotifier` — outbound alerts;
- `KeychainStore` — Telegram token persistence;
- `EventLogger` — local redacted JSONL history;
- `LaunchAtLoginController` — `SMAppService` integration;
- SwiftUI dashboard, menu bar, settings, and about views.

## Data flow

1. The client launches `codex app-server` and completes its initialization handshake.
2. It requests `account/rateLimits/read` and consumes `account/rateLimits/updated` notifications.
3. The parser normalizes all returned buckets and windows, then selects the minimum remaining percentage.
4. The Accessibility adapter reports whether an exact target app exists and whether a Stop-like task control is visible.
5. The policy core combines fresh quota telemetry with GUI activity and emits declarative actions.
6. `AppModel` throttles actions, checks user settings, and invokes the appropriate adapter.

## Why a separate App Server cannot stop the user's existing turn

Turn interruption is connection-scoped: an App Server can interrupt turns that it owns. Codex Limit Guard deliberately opens a separate connection only for telemetry, so an active turn in the normal Codex/ChatGPT application is controlled through the GUI Accessibility adapter instead.

## Policy invariants

- `hard ≤ soft ≤ block < recovery ≤ warning`;
- no action is emitted without a fresh quota snapshot;
- only one active task at the initial 15% boundary receives grace;
- after grace completes, a newly detected task is soft-stopped;
- hard stop is optional and exact-target only;
- recovery uses hysteresis so the task block is released before the warning clears;
- notification state resets after a healthy recovery.

## Concurrency

- App Server I/O and timers run on a dedicated serial dispatch queue.
- UI state and action execution run on the main actor.
- Telegram uses Swift concurrency.
- Event-file writes use a dedicated serial queue.

## Packaging

Swift Package Manager builds the executable. `scripts/build-app.sh` wraps the release binary in a conventional `.app` bundle, creates a generated icon, adds `Info.plist`, ad-hoc signs the bundle, and produces a ZIP artifact.
