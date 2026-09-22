#!/usr/bin/env python3
"""Ensure Factory has a local task scope before a prompt is handled."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

MAX_INPUT_BYTES = 1_048_576


def _cwd(payload: object) -> str:
    if isinstance(payload, dict):
        for key in ("cwd", "working_directory", "workspace_cwd"):
            value = payload.get(key)
            if isinstance(value, str) and value:
                return value
    return os.getcwd()


def main() -> int:
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        if len(raw) > MAX_INPUT_BYTES:
            return 0
        payload = json.loads(raw) if raw.strip() else {}
        cwd = _cwd(payload)
        if not Path(cwd).is_dir():
            return 0

        runtime = os.environ.get("MIYAGO_RUNTIME", "codex")
        binary = os.environ.get(
            "AGENT_WORKFLOW_BIN",
            str(Path.home() / ".local/bin/agent-workflow"),
        )
        if not os.access(binary, os.X_OK):
            return 0

        subprocess.run(
            [binary, "session-start", "--runtime", runtime, "--cwd", cwd],
            cwd=cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=8,
            check=False,
        )
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError):
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
