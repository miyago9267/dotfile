#!/usr/bin/env python3
"""Create a private, query-free RoutePlan for substantial Codex prompts."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

MAX_INPUT_BYTES = 1_048_576
ROUTE_MARKERS = re.compile(
    r"(以前|過去|類似|專案|架構|設定|路徑|命令|下一步|經驗|context|routing|symlink|repo|project)",
    re.IGNORECASE,
)


def main() -> int:
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        if len(raw) > MAX_INPUT_BYTES:
            return 0
        payload = json.loads(raw)
        if not isinstance(payload, dict) or payload.get("hook_event_name") != "UserPromptSubmit":
            return 0
        prompt = next(
            (payload.get(key) for key in ("prompt", "user_prompt", "user_message") if isinstance(payload.get(key), str)),
            "",
        )
        if not prompt or ROUTE_MARKERS.search(prompt) is None:
            return 0
        workspace_root = Path(os.environ.get("MIYAGO_AGENT_WORKSPACE_ROOT", str(Path.home() / "Project/AI/agent-workspace")))
        binary = os.environ.get("MIYAGO_CONTEXT_HARNESS_BIN", str(Path.home() / ".local/bin/miyago-context-harness"))
        if not (workspace_root / "routing.yaml").is_file() or not os.access(binary, os.X_OK):
            return 0
        route_root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "miyago-agent/routes"
        route_root.mkdir(parents=True, exist_ok=True)
        output = route_root / f"route-{time.time_ns()}.yaml"
        result = subprocess.run(
            [binary, "route", "--workspace-root", str(workspace_root), "--cwd", os.getcwd(), "--query", prompt, "--output", str(output)],
            cwd=workspace_root,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
        if result.returncode == 0 and output.is_file():
            print(
                json.dumps(
                    {
                        "hookSpecificOutput": {
                            "hookEventName": "UserPromptSubmit",
                            "additionalContext": (
                                "Context routing produced a bounded RoutePlan. "
                                f"Read this route plan before broad retrieval: {output}"
                            ),
                        }
                    },
                    separators=(",", ":"),
                )
            )
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError):
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
