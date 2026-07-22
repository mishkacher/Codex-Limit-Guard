# Contributing

Thank you for helping improve Codex Limit Guard.

## Development setup

```bash
git clone https://github.com/mishkacher/Codex-Limit-Guard.git
cd Codex-Limit-Guard
swift test
./scripts/audit.sh
```

The core package builds and tests on Linux and macOS. The SwiftUI application and packaging flow require macOS 13 or newer.

## Design rules

1. Keep quota parsing and policy decisions in `CodexLimitGuardCore`.
2. Keep macOS APIs behind narrow adapters in `CodexLimitGuardMac`.
3. Never broaden process matching with substring-based process killing.
4. Fail closed when Accessibility state is unknown.
5. Never log tokens, authorization headers, prompt text, or conversation content.
6. Add a regression test for every policy or parser fix.
7. Preserve macOS 13 compatibility unless a major release explicitly changes it.

## Pull requests

- Use a focused branch and a clear description.
- Run `swift test` and `./scripts/audit.sh`.
- Update documentation for behavior or security-boundary changes.
- Explain any change to thresholds, bundle identifiers, Accessibility selectors, or termination behavior.
- Keep the PR draft until CI is green.

## Commit style

Use concise imperative commits, for example:

- `Harden accessibility target matching`
- `Add multi-bucket parser regression tests`
- `Document release trust model`
