#!/usr/bin/env python3
"""Opt-in Stop-hook classifier for task-continuation context, shadow only."""

from __future__ import annotations

import hashlib
import json
import os
import re
import ssl
import stat
import sys
from urllib.parse import urlsplit
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ENDPOINT = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"
MAX_INPUT_BYTES = 2 * 1024 * 1024
MAX_MESSAGE_BYTES = 2400
MAX_RESPONSE_BYTES = 64 * 1024
REQUEST_TIMEOUT_SECONDS = 1.5
DEFAULT_TAU = 0.5

SECRET_PATTERNS = [
    re.compile(r"(?i)\b(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16})\b"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"(?i)\b(?:bearer|basic)\s+[A-Za-z0-9._~+/-]{8,}={0,2}"),
]
SECRET_FIELD_RE = re.compile(
    r"(?i)\b(?:api[_-]?key|auth[_-]?token|access[_-]?token|secret|password|passwd|pwd)\b\s*[:=]\s*[^\s,;]+"
)
URL_RE = re.compile(r"https?://[^\s<>]+|www\.[^\s<>]+", re.I)
PATH_RE = re.compile(
    r"(?:/Users/|/private/|/home/|~/|[A-Za-z]:\\|(?:^|\s)\.\.?/)[^\s,;:]+"
)
FILENAME_RE = re.compile(
    r"(?i)\b[\w.-]+\.(?:rs|swift|py|ts|tsx|js|jsx|sh|json|toml|ya?ml|lock|md|c|h|cpp|go|rb|java|kt)\b"
)
SHA_RE = re.compile(r"\b[0-9a-f]{7,40}\b", re.I)
ISSUE_RE = re.compile(r"(?i)(?:#\d+|\bPR\s*\d+|\bissue\s*\d+)")
CODE_FENCE_RE = re.compile(r"```.*?(?:```|\Z)|~~~.*?(?:~~~|\Z)", re.S)
INLINE_CODE_RE = re.compile(r"(?<!`)`+[^`\n]*`+(?!`)")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _tau() -> float:
    try:
        value = float(os.environ.get("JEV_CONTEXT_TAU", DEFAULT_TAU))
    except (TypeError, ValueError):
        return DEFAULT_TAU
    return value if 0.0 <= value <= 1.0 else DEFAULT_TAU


def _read_payload() -> dict[str, Any] | None:
    raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
    if not raw or len(raw) > MAX_INPUT_BYTES:
        return None
    payload = json.loads(raw)
    if not isinstance(payload, dict) or payload.get("stop_hook_active"):
        return None
    return payload


def _redact(message: str) -> str:
    text = CODE_FENCE_RE.sub(" ", message)
    text = INLINE_CODE_RE.sub(" ", text)
    text = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith(">"))
    text = URL_RE.sub(" ", text)

    safe_lines: list[str] = []
    for line in text.splitlines():
        if PATH_RE.search(line) or FILENAME_RE.search(line):
            continue
        safe_lines.append(line)
    text = "\n".join(safe_lines)
    text = SECRET_FIELD_RE.sub("[redacted field]", text)
    for pattern in SECRET_PATTERNS:
        text = pattern.sub("[redacted credential]", text)
    text = SHA_RE.sub(" ", text)
    text = ISSUE_RE.sub(" ", text)
    text = re.sub(r"[\t ]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()

    encoded = text.encode("utf-8")
    if len(encoded) > MAX_MESSAGE_BYTES:
        text = encoded[-MAX_MESSAGE_BYTES:].decode("utf-8", errors="ignore")
    return text


def _unsafe_content(text: str) -> bool:
    if not text or re.search(r"[`{}]", text):
        return True
    if PATH_RE.search(text) or FILENAME_RE.search(text) or URL_RE.search(text):
        return True
    if any(pattern.search(text) for pattern in SECRET_PATTERNS):
        return True
    return bool(SECRET_FIELD_RE.search(text))


def _load_questions() -> tuple[dict[str, Any], str] | None:
    try:
        path = Path(__file__).with_name("context-retention-questions.json")
        raw = path.read_bytes()
        questions = json.loads(raw)
        return questions, hashlib.sha256(raw).hexdigest()
    except (OSError, ValueError, json.JSONDecodeError):
        return None


def _request(message: str, questions: dict[str, Any]) -> float | None:
    api_key = os.environ.get("TYPESAFE_API_KEY")
    if not api_key:
        return None

    item = questions.get("retain_context")
    if not isinstance(item, dict) or not isinstance(item.get("instructions"), dict):
        return None
    body = json.dumps(
        {
            "model": MODEL,
            "state": {
                "source": "one Claude Code Stop turn",
                "candidate": message,
            },
            "questions": {"retain_context": item},
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")

    if len(body) > 8 * 1024:
        return None
    if any(pattern.search(body.decode("utf-8")) for pattern in SECRET_PATTERNS):
        return None
    endpoint = urlsplit(ENDPOINT)
    if endpoint.scheme != "https" or endpoint.hostname != "api.typesafe.ai":
        return None

    request = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=ssl.create_default_context()),
        NoRedirect(),
    )
    try:
        with opener.open(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            if response.status != 200 or response.geturl() != ENDPOINT:
                return None
            response_body = response.read(MAX_RESPONSE_BYTES + 1)
        if len(response_body) > MAX_RESPONSE_BYTES:
            return None
        result = json.loads(response_body)
        score = result.get("answers", {}).get("retain_context", {}).get("noul")
        if isinstance(score, bool) or not isinstance(score, (int, float)):
            return None
        if not 0.0 <= float(score) <= 1.0:
            return None
        return float(score)
    except (OSError, ValueError, urllib.error.URLError, TimeoutError):
        return None
    except Exception:
        return None


def _append_record(record: dict[str, Any]) -> None:
    path = Path(
        os.environ.get(
            "JEV_CONTEXT_SHADOW_LOG",
            str(Path.home() / ".local/state/miyago/jev/context-retention-shadow.jsonl"),
        )
    )
    try:
        cursor = path.parent
        while cursor != cursor.parent:
            if cursor.is_symlink():
                return
            cursor = cursor.parent
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        parent_info = path.parent.stat()
        parent_mode = stat.S_IMODE(parent_info.st_mode)
        if parent_info.st_uid != os.getuid() or parent_mode & 0o077 or path.is_symlink():
            return
        flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT
        flags |= getattr(os, "O_NOFOLLOW", 0)
        fd = os.open(path, flags, 0o600)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                return
            os.fchmod(fd, 0o600)
            line = (json.dumps(record, separators=(",", ":")) + "\n").encode()
            offset = 0
            while offset < len(line):
                offset += os.write(fd, line[offset:])
        finally:
            os.close(fd)
    except OSError:
        return


def main() -> int:
    if os.environ.get("JEV_CONTEXT_SHADOW") != "1":
        return 0

    try:
        payload = _read_payload()
        if payload is None:
            return 0
        message = payload.get("last_assistant_message")
        if not isinstance(message, str) or not message.strip():
            return 0
        redacted = _redact(message)
        if _unsafe_content(redacted):
            return 0
        loaded = _load_questions()
        if loaded is None:
            return 0
        questions, question_hash = loaded
        score = _request(redacted, questions)
        if score is None:
            return 0
        tau = _tau()
        _append_record(
            {
                "ts": datetime.now(timezone.utc).isoformat(),
                "event": "Stop",
                "model": MODEL,
                "question_hash": question_hash,
                "candidate_bytes": len(redacted.encode("utf-8")),
                "score": score,
                "tau": tau,
                "would_keep": score >= tau,
                "mode": "shadow",
            }
        )
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
