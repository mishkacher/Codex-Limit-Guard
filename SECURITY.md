# Security policy

## Supported versions

Security fixes are applied to the latest release and the default branch.

## Reporting a vulnerability

Please do not publish exploitable details in a public issue. Use GitHub's **Report a vulnerability** flow under the repository Security tab. Include:

- affected version and macOS version;
- exact reproduction steps;
- impact and expected behavior;
- whether the issue can terminate an unintended process, expose secrets, or bypass a threshold;
- a minimal proof of concept when safe.

## Security boundaries

Codex Limit Guard:

- reads Codex rate-limit metadata from a local App Server process;
- stores only the optional Telegram bot token in macOS Keychain;
- stores non-secret preferences in `UserDefaults`;
- writes local event logs after secret redaction;
- requests Accessibility permission to inspect task-control buttons in exact target apps;
- never executes shell text received from Codex or Telegram;
- does not collect analytics or telemetry.

Emergency termination is intentionally scoped to known OpenAI Codex/ChatGPT bundle identifiers or exact app bundle names when no identifier is available. Reports that broaden this target set are treated as high severity.

## Release integrity

Release workflows publish a SHA-256 checksum. Community binaries are currently ad-hoc signed rather than Apple-notarized; source builds remain the highest-trust installation path.
