#!/usr/bin/env python3
"""Opt-in UserPromptSubmit hook: Jev suggests a Pilotfish first role, advisory only.

Only clean, short, low-risk prompts are sent. Anything risky, pasted, or still
identifying after redaction is skipped locally. Output is a fixed template; Jev
text, scores, and prompt fragments never reach the model context.
"""

from __future__ import annotations

import json
import os
import pwd
import re
import ssl
import stat
import sys
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

ENDPOINT = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"
MAX_INPUT_BYTES = 256 * 1024
MAX_PROMPT_BYTES = 1024
MAX_PROMPT_LINES = 5
MAX_RESPONSE_BYTES = 64 * 1024
SOCKET_TIMEOUT_SECONDS = 1.0
DEADLINE_SECONDS = 1.5
THRESHOLD = 0.8
MIN_LEAD = 0.2
BREAKER_FAILURES = 3
BREAKER_SECONDS = 600
MAX_LOG_BYTES = 1024 * 1024

ROLE_TEXT = {
    "parent_local": "main session directly",
    "mechanical": "`mech-executor`",
    "exploration": "`scout`",
    "judgment": "`executor`",
}
DIRECTIVE = (
    "Pilotfish Jev advisory (not approval; AGENTS.md gates and dispatch brake win): "
    "suggested first role = {role}."
)
PLAN_SUFFIX = " Consider explore_then_plan before any write."


def _question(question: str, true: str, false: str) -> dict[str, Any]:
    return {
        "type": "noul",
        "instructions": {"question": question},
        "criteria": {"true": true, "false": false},
    }


QUESTIONS = {
    "parent_local": _question(
        "Is `request` one clear, bounded action the main session can do directly without delegating?",
        "A single small edit, command, or answer with an obvious target.",
        "It needs searching, several steps, or delegated work.",
    ),
    "mechanical": _question(
        "Is `request` routine, fully specified, low-judgment work such as a pattern edit or bulk rename?",
        "The change is repetitive and fully described; no design choice is needed.",
        "It needs design decisions, investigation, or interpretation.",
    ),
    "exploration": _question(
        "Is `request` mainly read-only searching or locating code, files, or facts?",
        "The main outcome is finding or summarizing where or how something is.",
        "The main outcome is a change, a decision, or a design.",
    ),
    "judgment": _question(
        "Does `request` need bounded implementation with ordinary engineering judgment, such as a feature or bug fix?",
        "It is an implementation task that needs local design decisions.",
        "It is a lookup, a trivial edit, or purely mechanical work.",
    ),
    "needs_plan": _question(
        "Is `request` broad, cross-module, high-impact, or costly to reverse, so it needs a plan before writing?",
        "It spans modules or systems, changes behavior widely, or is hard to undo.",
        "It is local, bounded, and easy to undo.",
    ),
}

_B = r"(?<![A-Za-z0-9])"
_E = r"(?![A-Za-z0-9])"
RISK_RE = re.compile(
    r"\w*auth\w*|"
    + _B
    + r"(?:token\w*|keys?|api[_-]?key|passw(?:or)?d\w*|pwd|secret\w*|credential\w*|"
    r"rotate|crypto\w*|permission\w*|login|logout|sso|ssh|jwt|2fa|mfa|otp|cert\w*|tls|ssl|"
    r"cookie\w*|pii|gdpr|customer\w*|"
    r"drop|delete\w*|remove\w*|erase\w*|wipe|purge|destroy\w*|overwrite\w*|truncate|"
    r"kill\w*|shutdown|reboot|rm|force|sudo|chmod|chown|"
    r"prod|production|deploy\w*|release\w*|publish\w*|push\w*|merge\w*|rebase|"
    r"rollback|revert|reset|migrat\w*|schema\w*|payment\w*|billing|invoice\w*|pay)"
    + _E
    + r"|\.env|權限|密碼|密鑰|私鑰|金鑰|憑證|認證|登入|登出|刪|移除|清空|清除|銷毀|覆蓋|"
    r"重置|回滾|回退|合併|推送|關機|重開|殺掉|部署|發布|發佈|遷移|上線|正式環境|資料庫|"
    r"付款|付錢|支付|金流|帳單|帳號|個資|隱私|客戶",
    re.IGNORECASE,
)
FENCE_RE = re.compile(r"```|~~~")

REDACTIONS = [
    (re.compile(r"`[^`\n]*`"), "[CODE]"),
    (re.compile(r"-----BEGIN [A-Z ]*-----.*?(?:-----END [A-Z ]*-----|\Z)", re.S), "[REDACTED]"),
    (re.compile(r"(?i)\b(?:bearer|basic)\s+\S+"), "[REDACTED]"),
    (re.compile(r"[A-Za-z][A-Za-z0-9+.-]*://\S+"), "[URL]"),
    (re.compile(r"\S+@[A-Za-z0-9.-]+:\S+"), "[URL]"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "[EMAIL]"),
    (
        re.compile(
            _B
            + r"(?:sk-[A-Za-z0-9_-]{8,}|sk_(?:live|test)_[A-Za-z0-9]{8,}|AKIA[0-9A-Z]{16}|"
            r"AIza[0-9A-Za-z_-]{30,}|gh[pousr]_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|"
            r"glpat-[A-Za-z0-9_-]{8,}|xox[abprs]-[A-Za-z0-9-]{8,})"
        ),
        "[REDACTED]",
    ),
    (re.compile(r"(?<![0-9.])\d{1,3}(?:\.\d{1,3}){3}(?![0-9.])"), "[IP]"),
    (
        re.compile(
            r"(?<![A-Za-z0-9_-])(?:[A-Za-z0-9-]+\.)+"
            r"(?:com|net|org|io|ai|dev|local|internal|lan|tw|jp|cn|co|app|cloud|sh|me|xyz|corp|intra)"
            r"(?![A-Za-z0-9-])",
            re.IGNORECASE,
        ),
        "[HOST]",
    ),
    (re.compile(r"(?<![A-Za-z0-9])(?:~|\.{1,2})?/[A-Za-z0-9._~-]\S*"), "[PATH]"),
    (re.compile(r"[A-Za-z]:\\\S*"), "[PATH]"),
    (re.compile(r"\"[^\"\n]{1,500}\"|'[^'\n]{1,500}'"), "[QUOTED]"),
    (re.compile(_B + r"[A-Za-z0-9+/=_-]{24,}" + _E), "[REDACTED]"),
    (re.compile(_B + r"[0-9a-f]{7,40}" + _E, re.IGNORECASE), "[HASH]"),
]
RESIDUAL_RE = re.compile(
    r"[`{}@\\]|://|(?<![0-9.])\d{1,3}(?:\.\d{1,3}){3}(?![0-9.])|"
    r"(?<![A-Za-z0-9])(?:~|\.{1,2})?/[A-Za-z0-9._~-]|" + _B + r"[A-Za-z0-9+/=_-]{24,}"
)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def redact(prompt: str) -> str:
    text = prompt
    for pattern, replacement in REDACTIONS:
        text = pattern.sub(replacement, text)
    return re.sub(r"[\t ]+", " ", text).strip()


def screen(prompt: str) -> str | None:
    """Return a skip reason, or None when the prompt may be sent after redaction."""
    if RISK_RE.search(prompt):
        return "skipped_risk"
    if (
        FENCE_RE.search(prompt)
        or prompt.count("\n") >= MAX_PROMPT_LINES
        or len(prompt.encode("utf-8")) > MAX_PROMPT_BYTES
    ):
        return "skipped_paste"
    return None


def resolve_endpoint(env: dict[str, str], home: str, real_home: str) -> str:
    """Honor the loopback test endpoint only when HOME is a different directory."""
    override = env.get("PILOTFISH_JEV_TEST_ENDPOINT", "")
    if not override:
        return ENDPOINT
    try:
        current, real = os.stat(home), os.stat(real_home)
        if (current.st_dev, current.st_ino) == (real.st_dev, real.st_ino):
            return ENDPOINT
        parts = urlsplit(override)
    except (OSError, ValueError):
        return ENDPOINT
    if parts.scheme == "http" and parts.hostname == "127.0.0.1":
        return override
    return ""


def _endpoint_allowed(endpoint: str) -> bool:
    parts = urlsplit(endpoint)
    if endpoint == ENDPOINT:
        return parts.scheme == "https" and parts.hostname == "api.typesafe.ai"
    return parts.scheme == "http" and parts.hostname == "127.0.0.1"


def _no_symlink_below(path: Path, home: Path) -> bool:
    """True when no component from path up to (not including) home is a symlink."""
    try:
        path.relative_to(home)
    except ValueError:
        return False
    cursor = path
    while cursor != home:
        if cursor.is_symlink():
            return False
        cursor = cursor.parent
    return True


def _private_dir(path: Path, home: Path) -> bool:
    try:
        if not _no_symlink_below(path, home):
            return False
        info = path.stat()
        return stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid() and not info.st_mode & 0o022
    except OSError:
        return False


def read_key(home: Path) -> str | None:
    path = home / ".config/typesafe/api_key"
    if not _private_dir(path.parent, home):
        return None
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    except OSError:
        return None
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            return None
        if stat.S_IMODE(info.st_mode) & 0o077:
            return None
        key = os.read(fd, 4096).decode("utf-8", errors="ignore").strip()
    finally:
        os.close(fd)
    return key if key and "\n" not in key else None


def _state_dir(home: Path) -> Path | None:
    path = home / ".local/state/miyago/jev"
    try:
        if not _no_symlink_below(path.parent, home):
            return None
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
    except OSError:
        return None
    if path.is_symlink():
        return None
    try:
        info = path.stat()
    except OSError:
        return None
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
        return None
    return path


def _open_private(path: Path, flags: int) -> int | None:
    try:
        fd = os.open(path, flags | getattr(os, "O_NOFOLLOW", 0), 0o600)
    except OSError:
        return None
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        os.close(fd)
        return None
    os.fchmod(fd, 0o600)
    return fd


def append_log(home: Path, record: dict[str, Any]) -> None:
    state = _state_dir(home)
    if state is None:
        return
    path = state / "pilotfish-route.jsonl"
    try:
        if path.exists() and path.stat().st_size > MAX_LOG_BYTES:
            return
        fd = _open_private(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT)
        if fd is None:
            return
        try:
            os.write(fd, (json.dumps(record, separators=(",", ":")) + "\n").encode())
        finally:
            os.close(fd)
    except OSError:
        return


def _breaker_path(home: Path) -> Path | None:
    state = _state_dir(home)
    return None if state is None else state / "pilotfish-route.breaker.json"


def breaker_open(home: Path) -> bool:
    path = _breaker_path(home)
    if path is None:
        return True
    fd = _open_private(path, os.O_RDONLY | os.O_CREAT)
    if fd is None:
        return True
    try:
        data = json.loads(os.read(fd, 4096) or b"{}")
        return float(data.get("until", 0)) > time.time()
    except (OSError, ValueError, AttributeError, TypeError):
        return False
    finally:
        os.close(fd)


def record_result(home: Path, ok: bool) -> None:
    path = _breaker_path(home)
    if path is None:
        return
    fd = _open_private(path, os.O_RDWR | os.O_CREAT)
    if fd is None:
        return
    try:
        try:
            data = json.loads(os.read(fd, 4096) or b"{}")
            fails = int(data.get("fails", 0))
        except (ValueError, AttributeError, TypeError):
            fails = 0
        fails = 0 if ok else fails + 1
        state: dict[str, Any] = {"fails": fails}
        if fails >= BREAKER_FAILURES:
            state = {"fails": 0, "until": time.time() + BREAKER_SECONDS}
        os.lseek(fd, 0, os.SEEK_SET)
        os.ftruncate(fd, 0)
        os.write(fd, json.dumps(state).encode())
    except OSError:
        return
    finally:
        os.close(fd)


def _score(answers: object, name: str) -> float | None:
    if not isinstance(answers, dict):
        return None
    answer = answers.get(name)
    if not isinstance(answer, dict) or answer.get("type") != "noul":
        return None
    value = answer.get("noul")
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    return value if 0.0 <= value <= 1.0 else None


def _post(endpoint: str, key: str, text: str) -> dict[str, float] | None:
    body = json.dumps(
        {
            "model": MODEL,
            "state": {"source": "one Claude Code user request", "request": text},
            "questions": QUESTIONS,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=ssl.create_default_context()),
        NoRedirect(),
    )
    try:
        with opener.open(request, timeout=SOCKET_TIMEOUT_SECONDS) as response:
            if response.status != 200 or response.geturl() != endpoint:
                return None
            raw = response.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            return None
        result = json.loads(raw)
    except urllib.error.HTTPError as failure:
        failure.close()
        return None
    except BaseException:
        return None
    if not isinstance(result, dict):
        return None
    model = result.get("model")
    if not isinstance(model, str) or not model.startswith("jev-"):
        return None
    answers = result.get("answers")
    scores = {name: _score(answers, name) for name in QUESTIONS}
    if any(value is None for value in scores.values()):
        return None
    return scores  # type: ignore[return-value]


def classify(endpoint: str, key: str, text: str) -> dict[str, float] | None:
    """Run the request under a total wall-clock deadline."""
    box: list[dict[str, float] | None] = [None]

    def work() -> None:
        box[0] = _post(endpoint, key, text)

    worker = threading.Thread(target=work, daemon=True)
    worker.start()
    worker.join(DEADLINE_SECONDS)
    return None if worker.is_alive() else box[0]


def directive(scores: dict[str, float]) -> str | None:
    ranked = sorted(((scores[name], name) for name in ROLE_TEXT), reverse=True)
    (best, role), (second, _) = ranked[0], ranked[1]
    if best < THRESHOLD or best - second < MIN_LEAD:
        return None
    text = DIRECTIVE.format(role=ROLE_TEXT[role])
    if scores["needs_plan"] >= THRESHOLD:
        text += PLAN_SUFFIX
    return text


def _denied(cwd: str, home: Path, env: dict[str, str]) -> bool:
    try:
        current = os.path.realpath(cwd or os.getcwd())
    except OSError:
        return True
    if any(part.lower() == "itrd" for part in Path(current).parts):
        return True
    folded = current.casefold()
    for root in (item for item in env.get("PILOTFISH_JEV_DENY", "").split(":") if item):
        resolved = os.path.realpath(os.path.expanduser(root)).casefold()
        if folded == resolved or folded.startswith(resolved + os.sep):
            return True
    return False


def run(payload: dict[str, Any], env: dict[str, str]) -> str | None:
    mode = env.get("PILOTFISH_JEV_MODE", "")
    if mode not in {"active", "shadow"} or payload.get("agent_id"):
        return None
    prompt = payload.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        return None
    home = Path(env.get("HOME") or os.path.expanduser("~"))
    base = {"ts": datetime.now(timezone.utc).isoformat(), "event": "UserPromptSubmit", "mode": mode}

    def log(decision: str, **extra: Any) -> None:
        append_log(home, {**base, "decision": decision, **extra})

    cwd = payload.get("cwd")
    if _denied(cwd if isinstance(cwd, str) else "", home, env):
        log("skipped_deny")
        return None
    reason = screen(prompt)
    if reason:
        log(reason)
        return None
    text = redact(prompt)
    if not text or RESIDUAL_RE.search(text):
        log("skipped_unsafe")
        return None
    endpoint = resolve_endpoint(env, str(home), pwd.getpwuid(os.getuid()).pw_dir)
    if not endpoint or not _endpoint_allowed(endpoint):
        log("skipped_endpoint")
        return None
    key = read_key(home)
    if key is None:
        log("skipped_key")
        return None
    if breaker_open(home):
        log("skipped_breaker")
        return None
    scores = classify(endpoint, key, text)
    record_result(home, scores is not None)
    if scores is None:
        log("failed")
        return None
    output = directive(scores) if mode == "active" else None
    emitted = None
    if output:
        emitted = next(name for name, value in ROLE_TEXT.items() if value in output)
    log("sent", scores={k: round(v, 3) for k, v in scores.items()}, emitted=emitted)
    return output


def main() -> int:
    try:
        raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        if not raw or len(raw) > MAX_INPUT_BYTES:
            return 0
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            return 0
        output = run(payload, dict(os.environ))
        if output:
            sys.stdout.write(
                json.dumps(
                    {
                        "hookSpecificOutput": {
                            "hookEventName": "UserPromptSubmit",
                            "additionalContext": output,
                        }
                    }
                )
            )
            sys.stdout.flush()
    except BaseException:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
