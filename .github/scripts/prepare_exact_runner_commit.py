#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path.cwd()
WORKFLOWS = ROOT / ".github/workflows"
SELF = Path(__file__)
NORMALIZER = WORKFLOWS / "normalize-runner-selectors.yml"
LEGACY_POLICY = WORKFLOWS / "docker-runner-policy.yml"
CI_WORKFLOW = WORKFLOWS / "ci.yml"
JOB_RE = re.compile(r"^  [A-Za-z0-9_.-]+:\s*(?:#.*)?$")
RUNS_ON_RE = re.compile(r"^(?P<indent>\s*)runs-on:\s*(?P<value>.*)$")


def choose_selector(block: str, current: str) -> str:
    lowered = f"{block}\n{current}".lower()
    if any(token in lowered for token in ("macos", "xcodebuild", "sw_vers", "osascript", "codesign", "plutil", "darwin")):
        return "[self-hosted, macOS, ARM64]"
    if any(token in lowered for token in ("container:", "services:", "docker", "docker compose", "docker-compose", "podman")):
        return "[self-hosted, docker]"
    if "backtest" in lowered or "backtester" in lowered:
        return "[self-hosted, backtester]"
    return "[self-hosted, fast]"


def remove_ci_migration_step() -> None:
    text = CI_WORKFLOW.read_text(encoding="utf-8")
    marker = "      - name: Prepare exact runner selector commit\n"
    if marker not in text:
        return
    start = text.index(marker)
    end = text.index("      - uses: swift-actions/setup-swift@v2\n", start)
    CI_WORKFLOW.write_text(text[:start] + text[end:], encoding="utf-8")


def normalize_workflow(path: Path) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    output: list[str] = []
    index = 0
    while index < len(lines):
        if not JOB_RE.match(lines[index]):
            output.append(lines[index])
            index += 1
            continue
        end = index + 1
        while end < len(lines) and not JOB_RE.match(lines[end]):
            if lines[end] and not lines[end].startswith((" ", "#")):
                break
            end += 1
        block = lines[index:end]
        block_text = "\n".join(block)
        cursor = 0
        while cursor < len(block):
            match = RUNS_ON_RE.match(block[cursor])
            if match is None:
                output.append(block[cursor])
                cursor += 1
                continue
            indent = match.group("indent")
            value = match.group("value").strip()
            next_index = cursor + 1
            if not value:
                values: list[str] = []
                while next_index < len(block):
                    line = block[next_index]
                    line_indent = len(line) - len(line.lstrip())
                    if line.strip() and line_indent <= len(indent):
                        break
                    if line.strip().startswith("-"):
                        values.append(line.strip())
                    next_index += 1
                value = " ".join(values)
            output.append(f"{indent}runs-on: {choose_selector(block_text, value)}")
            cursor = next_index
        index = end
    path.write_text("\n".join(output) + "\n", encoding="utf-8")


def write_policy_files() -> Path:
    checker = ROOT / ".github/scripts/check_runner_selectors.py"
    checker.parent.mkdir(parents=True, exist_ok=True)
    checker.write_text(
        """#!/usr/bin/env python3
from __future__ import annotations
import re
import sys
from pathlib import Path
ALLOWED = {
    "[self-hosted, fast]",
    "[self-hosted, docker]",
    "[self-hosted, backtester]",
    "[self-hosted, macOS, ARM64]",
}
RUNS_ON = re.compile(r"^\\s+runs-on:\\s*(?P<value>.*?)\\s*(?:#.*)?$")
errors = []
for path in sorted(Path(".github/workflows").glob("*.y*ml")):
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = RUNS_ON.match(line)
        if match and match.group("value") not in ALLOWED:
            errors.append(f"{path}:{number}: forbidden runs-on selector {match.group('value')!r}")
if errors:
    print("Only four exact self-hosted runner selectors are allowed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)
print("Runner selector policy passed.")
""",
        encoding="utf-8",
    )
    (WORKFLOWS / "self-hosted-runner-policy.yml").write_text(
        """name: Self-hosted runner selector policy
on:
  pull_request:
    paths: ['.github/workflows/**', '.github/scripts/check_runner_selectors.py', '.github/RUNNER_LABELS.md']
  push:
    paths: ['.github/workflows/**', '.github/scripts/check_runner_selectors.py', '.github/RUNNER_LABELS.md']
  workflow_dispatch:
permissions:
  contents: read
jobs:
  enforce:
    runs-on: [self-hosted, fast]
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - run: python3 .github/scripts/check_runner_selectors.py
""",
        encoding="utf-8",
    )
    (ROOT / ".github/RUNNER_LABELS.md").write_text(
        """# Canonical runner selectors

Every GitHub Actions job must use exactly one selector:

```yaml
runs-on: [self-hosted, fast]
runs-on: [self-hosted, docker]
runs-on: [self-hosted, backtester]
runs-on: [self-hosted, macOS, ARM64]
```

All other selectors are forbidden.
""",
        encoding="utf-8",
    )
    return checker


def api(path: str, payload: dict[str, object]) -> dict[str, object]:
    token = os.environ["GH_TOKEN"]
    repository = os.environ["GH_REPOSITORY"]
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/git/{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def create_detached_commit() -> str:
    parent = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    base_tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], text=True).strip()
    records = subprocess.check_output(["git", "diff", "--name-status", "HEAD"], text=True).splitlines()
    entries: list[dict[str, object]] = []
    for record in records:
        status, path = record.split("\t", 1)
        if status == "D":
            entries.append({"path": path, "mode": "100644", "type": "blob", "sha": None})
            continue
        file_path = Path(path)
        blob = api("blobs", {"content": base64.b64encode(file_path.read_bytes()).decode("ascii"), "encoding": "base64"})
        mode_output = subprocess.check_output(["git", "ls-files", "-s", "--", path], text=True).strip()
        mode = mode_output.split()[0] if mode_output else "100644"
        entries.append({"path": path, "mode": mode, "type": "blob", "sha": blob["sha"]})
    tree = api("trees", {"base_tree": base_tree, "tree": entries})
    commit = api("commits", {"message": "ci: enforce four exact self-hosted runner selectors", "tree": tree["sha"], "parents": [parent]})
    print(json.dumps({"parent": parent, "files": records}, indent=2))
    return str(commit["sha"])


def main() -> int:
    remove_ci_migration_step()
    for workflow in sorted(WORKFLOWS.glob("*.y*ml")):
        if workflow not in {NORMALIZER, LEGACY_POLICY}:
            normalize_workflow(workflow)
    checker = write_policy_files()
    for temporary in (NORMALIZER, LEGACY_POLICY, SELF):
        if temporary.exists():
            temporary.unlink()
    subprocess.run(["python3", str(checker)], check=True)
    subprocess.run(["git", "diff", "--check"], check=True)
    print(f"PREPARED_COMMIT_SHA={create_detached_commit()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
