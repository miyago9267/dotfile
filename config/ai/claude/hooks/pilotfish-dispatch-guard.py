#!/usr/bin/env python3
"""Pilotfish dispatch guard：main session 該派 subagent 時，擋掉直接改檔。

同一支 script 處理 UserPromptSubmit（寫 guard state）與 PreToolUse（判斷放行或 deny）。
PILOTFISH_GUARD=enforce（預設）| shadow（只記 log）| off。任何例外一律 fail-open。
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared/jev"))
from pilotfish_route import (  # noqa: E402
    ID_RE,
    MAX_INPUT_BYTES,
    MAX_LOG_BYTES,
    ROLE_TEXT,
    _open_private,
    _state_dir,
)

EDIT_TOOLS = {"Edit", "Write", "NotebookEdit", "MultiEdit"}
DISPATCH_TOOLS = {"Agent", "Workflow"}
DIRECT_RE = re.compile(r"(?<![\w#])#direct(?![\w-])")
ROLE_AGENT = {"judgment": "executor", "mechanical": "mech-executor"}

R1 = (
    "Pilotfish routing：這一輪 Jev 判定為 {role_text} 工作，main session 不直接改檔。"
    "請用 Agent 派出對應 role（brief 寫清楚 scope、stop condition、output cap），"
    "main 只負責整合與驗收；派出後，本輪 main 的編輯會自動放行。"
    "若確實只是 1–2 行的小修，請 Miyago 在 prompt 加上 #direct。"
)
R2 = (
    "Pilotfish routing：main session 這一輪已經直接改了 {n} 個檔案，而且沒有派任何 agent。"
    "多檔修改請交給 `executor`（需要判斷）或 `mech-executor`（規格完整的機械性修改）；"
    "派出後，本輪 main 的編輯會自動放行。"
    "若 Miyago 要你直接做，請他在 prompt 加上 #direct。"
)


def _sub_dir(home: Path, name: str) -> Path | None:
    """~/.local/state/miyago/jev/<name>，0700、非 symlink、本人擁有。"""
    state = _state_dir(home)
    if state is None:
        return None
    path = state / name
    try:
        path.mkdir(mode=0o700, exist_ok=True)
        info = path.stat()
    except OSError:
        return None
    if path.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o077:
        return None
    return path


def read_json(home: Path, sub: str, sid: str) -> dict[str, Any]:
    d = _sub_dir(home, sub)
    if d is None:
        return {}
    fd = _open_private(d / f"{sid}.json", os.O_RDONLY)
    if fd is None:
        return {}
    try:
        data = json.loads(os.read(fd, 64 * 1024))
    except ValueError:
        return {}
    finally:
        os.close(fd)
    return data if isinstance(data, dict) else {}


def write_json(home: Path, sub: str, sid: str, obj: dict[str, Any]) -> None:
    d = _sub_dir(home, sub)
    if d is None:
        return
    fd = _open_private(d / f"{sid}.json", os.O_WRONLY | os.O_CREAT | os.O_TRUNC)
    if fd is None:
        return
    try:
        os.write(fd, json.dumps(obj).encode())
    finally:
        os.close(fd)


def log(home: Path, record: dict[str, Any]) -> None:
    state = _state_dir(home)
    if state is None:
        return
    path = state / "pilotfish-guard.jsonl"
    try:
        if path.exists() and path.stat().st_size > MAX_LOG_BYTES:
            return
        fd = _open_private(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT)
        if fd is None:
            return
        try:
            line = {"ts": datetime.now(timezone.utc).isoformat(), **record}
            os.write(fd, (json.dumps(line, separators=(",", ":")) + "\n").encode())
        finally:
            os.close(fd)
    except OSError:
        return


def exempt(path: str, env: dict[str, str]) -> bool:
    if "/.claude/projects/" in path or "/.ai/" in path:
        return True
    roots = ["/tmp/", "/private/tmp/"]
    tmpdir = env.get("TMPDIR", "")
    if tmpdir:
        roots.append(tmpdir.rstrip("/") + "/")
    return any(path.startswith(r) for r in roots)


def deny(reason: str) -> str:
    return json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }
    )


def run(payload: dict[str, Any], env: dict[str, str]) -> str | None:
    mode = env.get("PILOTFISH_GUARD", "enforce")
    if mode == "off" or payload.get("agent_id"):
        return None
    sid, pid = payload.get("session_id"), payload.get("prompt_id")
    if not (isinstance(sid, str) and isinstance(pid, str) and ID_RE.match(sid) and ID_RE.match(pid)):
        return None
    home = Path(env.get("HOME") or os.path.expanduser("~"))
    event = payload.get("hook_event_name")

    if event == "UserPromptSubmit":
        prompt = payload.get("prompt")
        direct = isinstance(prompt, str) and bool(DIRECT_RE.search(prompt))
        write_json(home, "guard", sid, {"prompt_id": pid, "direct": direct, "dispatched": False, "edited": []})
        log(home, {"event": event, "decision": "state", "direct": direct})
        return None
    if event != "PreToolUse":
        return None

    tool = payload.get("tool_name")
    if tool not in DISPATCH_TOOLS | EDIT_TOOLS:
        return None
    state = read_json(home, "guard", sid)
    if state.get("prompt_id") != pid:
        state = {"prompt_id": pid, "direct": False, "dispatched": False, "edited": []}
    edited = state.get("edited") if isinstance(state.get("edited"), list) else []
    state["edited"] = edited
    rec: dict[str, Any] = {"event": event, "tool": tool}

    if tool in DISPATCH_TOOLS:
        state["dispatched"] = True
        write_json(home, "guard", sid, state)
        log(home, {**rec, "decision": "allow", "rule": "dispatch"})
        return None

    tin = payload.get("tool_input")
    tin = tin if isinstance(tin, dict) else {}
    path = tin.get("file_path") or tin.get("notebook_path")
    if not isinstance(path, str) or not path:
        return None
    rec["file"] = os.path.basename(path)
    if exempt(path, env):
        log(home, {**rec, "decision": "allow", "rule": "exempt"})
        return None

    reason = rule = role = None
    if state.get("direct") or state.get("dispatched"):
        rule = "direct" if state.get("direct") else "dispatched"
    else:
        turn = read_json(home, "turns", sid)
        role = turn.get("role") if turn.get("prompt_id") == pid else None
        if role in ROLE_AGENT:
            rule, reason = "R1", R1.format(role_text=ROLE_TEXT[role])
        elif path not in edited and len(edited) >= int(env.get("PILOTFISH_GUARD_MAX_FILES", "2")):
            rule, reason = "R2", R2.format(n=len(edited))
    if reason:
        decision = "deny" if mode == "enforce" else "would_deny"
        log(home, {**rec, "decision": decision, "rule": rule, "role": role})
        return deny(reason) if mode == "enforce" else None
    if path not in edited:
        edited.append(path)
    write_json(home, "guard", sid, state)
    log(home, {**rec, "decision": "allow", "rule": rule or "count", "role": role})
    return None


def main() -> int:
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        if not raw or len(raw) > MAX_INPUT_BYTES:
            return 0
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            return 0
        out = run(payload, dict(os.environ))
        if out:
            sys.stdout.write(out)
            sys.stdout.flush()
    except BaseException:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
