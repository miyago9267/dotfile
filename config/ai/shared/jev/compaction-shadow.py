#!/usr/bin/env python3
"""Observe compaction candidates without changing or sending context."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

MAX_INPUT_BYTES = 2 * 1024 * 1024


def _size(value: object) -> int:
    try:
        return len(json.dumps(value, ensure_ascii=False).encode("utf-8"))
    except (TypeError, ValueError):
        return 0


def main() -> int:
    if os.environ.get("JEV_COMPACTION_SHADOW", "1") == "0":
        return 0
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        if not raw or len(raw) > MAX_INPUT_BYTES:
            return 0
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            return 0

        event = str(payload.get("hook_event_name") or payload.get("event") or "unknown")
        tool = str(payload.get("tool_name") or payload.get("toolName") or payload.get("tool") or "")
        output = payload.get("tool_response", payload.get("output", payload.get("result")))
        record = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "event": event,
            "tool": tool[:120],
            "input_bytes": len(raw),
            "output_bytes": _size(output),
            "mode": "shadow",
            "proposed_policy": {
                "keep_first": 4,
                "keep_recent": 8,
                "drop_stale": False,
            },
        }
        log_path = Path(
            os.environ.get(
                "JEV_COMPACTION_SHADOW_LOG",
                str(Path.home() / ".local/state/miyago/jev/compaction-shadow.jsonl"),
            )
        )
        log_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
        os.chmod(log_path, 0o600)
    except (OSError, ValueError, json.JSONDecodeError):
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
