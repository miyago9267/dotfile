#!/usr/bin/env python3
"""Capture only explicit, low-sensitivity Codex preferences at prompt time."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

MAX_INPUT_BYTES = 1_048_576
MAX_SUMMARY_CHARS = 600
PREFERENCE_MARKERS = re.compile(
    r"(?:記住|請保留|我習慣|我的偏好|以後|之後|不要再|不要把|固定|偏好)",
    re.IGNORECASE,
)
SECRET_PATTERNS = (
    re.compile(r"(?i)(?:api[_ -]?key|token|secret|password|passwd|private[_ -]?key)\s*[:=：]\s*\S+"),
    re.compile(r"(?i)bearer\s+[A-Za-z0-9._-]+"),
    re.compile(r"-----BEGIN [^-]+-----.*?-----END [^-]+-----", re.DOTALL),
)


def _redact(value: str) -> str:
    redacted = value
    for pattern in SECRET_PATTERNS:
        redacted = pattern.sub("[REDACTED]", redacted)
    return re.sub(r"\s+", " ", redacted).strip()[:MAX_SUMMARY_CHARS]


def _prompt(payload: dict[str, object]) -> str:
    for key in ("prompt", "user_prompt", "user_message"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return ""


def main() -> int:
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        if len(raw) > MAX_INPUT_BYTES:
            return 0
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            return 0
        if payload.get("hook_event_name") != "UserPromptSubmit":
            return 0
        prompt = _prompt(payload)
        if not prompt or PREFERENCE_MARKERS.search(prompt) is None:
            return 0

        workspace_root = Path(
            os.environ.get(
                "MIYAGO_AGENT_WORKSPACE_ROOT",
                str(Path.home() / "Project/AI/agent-workspace"),
            )
        )
        binary = os.environ.get(
            "MIYAGO_CONTEXT_HARNESS_BIN",
            str(Path.home() / ".local/bin/miyago-context-harness"),
        )
        if not (workspace_root / "routing.yaml").is_file() or not os.access(binary, os.X_OK):
            return 0

        summary = _redact(prompt)
        if not summary:
            return 0
        command = [
            binary,
            "observe",
            "--workspace-root",
            str(workspace_root),
            "--task",
            "personal-experience-autocapture",
            "--kind",
            "explicit_preference",
            "--runtime",
            "codex",
            "--scope",
            str(workspace_root),
            "--scope",
            str(
                Path(
                    os.environ.get(
                        "MIYAGO_DOTFILE_ROOT",
                        str(Path.home() / "dotfile"),
                    )
                )
            ),
            "--source",
            "runtime_hook",
            "--summary",
            summary,
        ]
        environment = os.environ.copy()
        subprocess.run(
            command,
            cwd=workspace_root,
            env=environment,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError):
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
