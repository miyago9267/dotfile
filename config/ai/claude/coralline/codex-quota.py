#!/usr/bin/env python3
"""Read normalized Codex quota through the official app-server stdio protocol."""

from __future__ import annotations

import json
import os
import queue
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, TextIO

FRESH_SECONDS = 60
STALE_SECONDS = 900
LOCK_STALE_SECONDS = 10
REQUEST_TIMEOUT_SECONDS = 3.0
MAX_MESSAGE_CHARACTERS = 1_048_576
MAX_BUFFERED_MESSAGES = 16
MAX_IGNORED_MESSAGES = 64
FIELD_SEPARATOR = "\x1f"


class QuotaError(Exception):
    """Expected provider failure that must not expose raw protocol data."""


@dataclass(frozen=True)
class Window:
    used_percent: int
    resets_at: int

    def cache_value(self) -> dict[str, int]:
        return {"usedPercent": self.used_percent, "resetsAt": self.resets_at}


@dataclass(frozen=True)
class Quota:
    five_hour: Window | None
    seven_day: Window | None

    def output_record(self) -> str:
        values = (
            "" if self.five_hour is None else str(self.five_hour.used_percent),
            "" if self.five_hour is None else str(self.five_hour.resets_at),
            "" if self.seven_day is None else str(self.seven_day.used_percent),
            "" if self.seven_day is None else str(self.seven_day.resets_at),
        )
        return FIELD_SEPARATOR.join(values)


@dataclass(frozen=True)
class CachePaths:
    directory: Path
    cache: Path
    lock: Path


@dataclass(frozen=True)
class CachedQuota:
    fetched_at: int
    quota: Quota

    def age(self, now: int) -> int | None:
        value = now - self.fetched_at
        return value if value >= 0 else None


@dataclass(frozen=True)
class ProtocolWindow:
    position: str
    duration_minutes: int | None
    window: Window


class JsonLineClient:
    """Bounded JSONL request client for one Codex app-server child."""

    def __init__(self, process: subprocess.Popen[str], deadline: float) -> None:
        if process.stdin is None or process.stdout is None:
            raise QuotaError("app-server pipes unavailable")
        self.process = process
        self.stdin = process.stdin
        self.stdout = process.stdout
        self.deadline = deadline
        self.messages: queue.Queue[str | BaseException | None] = queue.Queue(maxsize=MAX_BUFFERED_MESSAGES)
        self.reader = threading.Thread(target=self._read_stdout, name="coralline-codex-reader", daemon=True)
        self.reader.start()

    def _enqueue(self, item: str | BaseException | None) -> bool:
        try:
            self.messages.put_nowait(item)
        except queue.Full:
            return False
        return True

    def _read_stdout(self) -> None:
        try:
            while True:
                line = self.stdout.readline(MAX_MESSAGE_CHARACTERS + 1)
                if not line:
                    break
                if len(line) > MAX_MESSAGE_CHARACTERS:
                    self._enqueue(QuotaError("app-server response exceeded size limit"))
                    break
                if not self._enqueue(line):
                    break
        except BaseException as exc:
            self._enqueue(exc)
        finally:
            self._enqueue(None)

    def send(self, message: dict[str, Any]) -> None:
        try:
            self.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            self.stdin.flush()
        except (BrokenPipeError, OSError, ValueError) as exc:
            raise QuotaError("app-server input closed") from exc

    def response(self, request_id: int) -> Any:
        ignored = 0
        while True:
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise QuotaError("app-server request timed out")
            try:
                item = self.messages.get(timeout=remaining)
            except queue.Empty as exc:
                raise QuotaError("app-server request timed out") from exc
            if item is None:
                raise QuotaError("app-server closed before responding")
            if isinstance(item, QuotaError):
                raise item
            if isinstance(item, BaseException):
                raise QuotaError("app-server output could not be read") from item
            try:
                message = json.loads(item)
            except (json.JSONDecodeError, UnicodeError) as exc:
                raise QuotaError("app-server returned malformed JSON") from exc
            if not isinstance(message, dict):
                raise QuotaError("app-server returned an invalid message")
            if message.get("id") != request_id:
                ignored += 1
                if ignored > MAX_IGNORED_MESSAGES:
                    raise QuotaError("app-server sent too many unrelated messages")
                continue
            if message.get("error") is not None:
                raise QuotaError("app-server returned an error")
            if "result" not in message:
                raise QuotaError("app-server response omitted result")
            return message["result"]


class AppServer:
    """Own and reliably reap one short-lived app-server process."""

    def __init__(self, binary: str) -> None:
        command = [binary, "app-server", "--stdio", "-c", "analytics.enabled=false"]
        try:
            self.process = subprocess.Popen(
                command,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                encoding="utf-8",
                errors="strict",
                bufsize=1,
                close_fds=True,
                start_new_session=os.name != "nt",
            )
        except (OSError, ValueError) as exc:
            raise QuotaError("could not start Codex app-server") from exc
        self.client = JsonLineClient(self.process, time.monotonic() + REQUEST_TIMEOUT_SECONDS)

    def close(self) -> None:
        try:
            if self.process.stdin is not None:
                self.process.stdin.close()
        except (BrokenPipeError, OSError, ValueError):
            pass
        try:
            self.process.wait(timeout=0.2)
        except subprocess.TimeoutExpired:
            self._stop(force=False)
            try:
                self.process.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                self._stop(force=True)
                try:
                    self.process.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    pass
        if self.process.stdout is not None:
            try:
                self.process.stdout.close()
            except OSError:
                pass
        self.client.reader.join(timeout=0.2)

    def _stop(self, force: bool) -> None:
        if self.process.poll() is not None:
            return
        try:
            if os.name != "nt":
                os.killpg(self.process.pid, signal.SIGKILL if force else signal.SIGTERM)
            elif force:
                self.process.kill()
            else:
                self.process.terminate()
        except (OSError, ProcessLookupError):
            pass

    def __enter__(self) -> JsonLineClient:
        return self.client

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.close()


def require_python() -> None:
    if sys.version_info < (3, 11):
        raise QuotaError("Python 3.11 or newer is required")


def resolve_codex_binary() -> str:
    override = os.environ.get("CORALLINE_CODEX_BINARY")
    if override is not None:
        if not override or not os.path.isabs(override):
            raise QuotaError("CORALLINE_CODEX_BINARY must be an absolute path")
        candidate = override
    else:
        resolved = shutil.which("codex")
        if resolved is None:
            raise QuotaError("codex executable not found")
        candidate = os.path.abspath(resolved)
    if not os.path.isfile(candidate) or not os.access(candidate, os.X_OK):
        raise QuotaError("codex executable is not an executable file")
    return candidate


def cache_paths() -> CachePaths:
    cache_home = os.environ.get("XDG_CACHE_HOME")
    if cache_home:
        base = Path(cache_home).expanduser()
    else:
        home = os.environ.get("HOME")
        if not home:
            raise QuotaError("HOME is unavailable")
        base = Path(home).expanduser() / ".cache"
    if not base.is_absolute():
        raise QuotaError("cache home must be absolute")
    directory = base / "coralline"
    return CachePaths(directory, directory / "codex-quota.json", directory / ".codex-quota.lock")


def ensure_cache_directory(paths: CachePaths) -> None:
    try:
        paths.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if paths.directory.is_symlink() or not paths.directory.is_dir():
            raise QuotaError("cache path is not a private directory")
        paths.directory.chmod(0o700)
    except OSError as exc:
        raise QuotaError("cache directory is unavailable") from exc


def valid_integer(value: object, minimum: int = 0) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= minimum


def cache_window(value: object) -> Window | None:
    if value is None:
        return None
    if not isinstance(value, dict) or set(value) != {"usedPercent", "resetsAt"}:
        raise QuotaError("cache window is invalid")
    used = value["usedPercent"]
    reset = value["resetsAt"]
    if not valid_integer(used) or used > 100 or not valid_integer(reset, 1):
        raise QuotaError("cache window values are invalid")
    return Window(used, reset)


def read_cache(paths: CachePaths) -> CachedQuota | None:
    try:
        metadata = paths.cache.lstat()
    except FileNotFoundError:
        return None
    except OSError:
        return None
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode) or metadata.st_size > 4096:
        return None
    try:
        paths.cache.chmod(0o600)
        with paths.cache.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    try:
        if not isinstance(value, dict) or set(value) != {"fetchedAt", "fiveHour", "sevenDay"}:
            raise QuotaError("cache document is invalid")
        fetched_at = value["fetchedAt"]
        if not valid_integer(fetched_at):
            raise QuotaError("cache timestamp is invalid")
        quota = Quota(cache_window(value["fiveHour"]), cache_window(value["sevenDay"]))
        if quota.five_hour is None and quota.seven_day is None:
            raise QuotaError("cache contains no quota window")
        return CachedQuota(fetched_at, quota)
    except QuotaError:
        return None


def write_cache(paths: CachePaths, fetched_at: int, quota: Quota) -> None:
    value = {
        "fetchedAt": fetched_at,
        "fiveHour": None if quota.five_hour is None else quota.five_hour.cache_value(),
        "sevenDay": None if quota.seven_day is None else quota.seven_day.cache_value(),
    }
    descriptor = -1
    temporary = ""
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=".codex-quota.", suffix=".tmp", dir=paths.directory)
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            descriptor = -1
            json.dump(value, handle, separators=(",", ":"), sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, paths.cache)
        temporary = ""
        paths.cache.chmod(0o600)
    except OSError as exc:
        raise QuotaError("cache could not be written") from exc
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        if temporary:
            try:
                os.unlink(temporary)
            except OSError:
                pass


def acquire_lock(paths: CachePaths, now: int) -> bool:
    try:
        paths.lock.mkdir(mode=0o700)
        paths.lock.chmod(0o700)
        return True
    except FileExistsError:
        pass
    except OSError:
        return False
    try:
        metadata = paths.lock.lstat()
        if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
            return False
        age = now - int(metadata.st_mtime)
        if age <= LOCK_STALE_SECONDS:
            return False
        paths.lock.rmdir()
        paths.lock.mkdir(mode=0o700)
        paths.lock.chmod(0o700)
        return True
    except OSError:
        return False


def release_lock(paths: CachePaths) -> None:
    try:
        paths.lock.rmdir()
    except OSError:
        pass


def protocol_window(raw: object, position: str) -> ProtocolWindow | None:
    if raw is None:
        return None
    if not isinstance(raw, dict):
        raise QuotaError("rate-limit window is invalid")
    used = raw.get("usedPercent")
    reset = raw.get("resetsAt")
    duration = raw.get("windowDurationMins")
    if not valid_integer(used) or used > 100:
        raise QuotaError("rate-limit percentage is invalid")
    if not valid_integer(reset, 1):
        raise QuotaError("rate-limit reset is invalid")
    if duration is not None and not valid_integer(duration, 1):
        raise QuotaError("rate-limit duration is invalid")
    return ProtocolWindow(position, duration, Window(used, reset))


def normalize_rate_limits(result: object) -> Quota:
    if not isinstance(result, dict):
        raise QuotaError("quota response is invalid")
    rate_limits = result.get("rateLimits")
    if not isinstance(rate_limits, dict):
        raise QuotaError("quota response omitted rateLimits")
    windows = [
        protocol_window(rate_limits.get("primary"), "primary"),
        protocol_window(rate_limits.get("secondary"), "secondary"),
    ]
    mapped: dict[str, Window] = {}
    fallback: list[ProtocolWindow] = []
    for item in windows:
        if item is None:
            continue
        if item.duration_minutes == 300:
            target = "five"
        elif item.duration_minutes == 10080:
            target = "seven"
        elif item.duration_minutes is None:
            fallback.append(item)
            continue
        else:
            continue
        if target in mapped:
            raise QuotaError("duplicate rate-limit duration")
        mapped[target] = item.window
    if len(fallback) == 2:
        for item in fallback:
            target = "five" if item.position == "primary" else "seven"
            if target not in mapped:
                mapped[target] = item.window
    elif len(fallback) == 1:
        item = fallback[0]
        target = "five" if item.position == "primary" else "seven"
        complement = "seven" if target == "five" else "five"
        if target not in mapped and complement in mapped:
            mapped[target] = item.window
    quota = Quota(mapped.get("five"), mapped.get("seven"))
    if quota.five_hour is None and quota.seven_day is None:
        raise QuotaError("quota response contained no supported window")
    return quota


def fetch_quota() -> Quota:
    binary = resolve_codex_binary()
    with AppServer(binary) as client:
        client.send(
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {
                        "name": "coralline",
                        "title": "Coralline quota provider",
                        "version": "1.0",
                    }
                },
            }
        )
        initialized = client.response(1)
        if not isinstance(initialized, dict):
            raise QuotaError("initialize response is invalid")
        client.send({"method": "initialized"})
        client.send({"id": 2, "method": "account/rateLimits/read"})
        return normalize_rate_limits(client.response(2))


def usable_cache(cached: CachedQuota | None, now: int, maximum_age: int) -> Quota | None:
    if cached is None:
        return None
    age = cached.age(now)
    if age is None or age > maximum_age:
        return None
    return cached.quota


def emit(quota: Quota) -> None:
    sys.stdout.write(quota.output_record() + "\n")


def run() -> int:
    require_python()
    paths = cache_paths()
    ensure_cache_directory(paths)
    now = int(time.time())
    cached = read_cache(paths)
    fresh = usable_cache(cached, now, FRESH_SECONDS)
    if fresh is not None:
        emit(fresh)
        return 0
    if not acquire_lock(paths, now):
        stale = usable_cache(cached, now, STALE_SECONDS)
        if stale is not None:
            emit(stale)
            return 0
        raise QuotaError("quota refresh is already in progress")
    try:
        now = int(time.time())
        cached = read_cache(paths)
        fresh = usable_cache(cached, now, FRESH_SECONDS)
        if fresh is not None:
            emit(fresh)
            return 0
        try:
            quota = fetch_quota()
        except QuotaError:
            stale = usable_cache(cached, int(time.time()), STALE_SECONDS)
            if stale is not None:
                emit(stale)
                return 0
            raise
        try:
            write_cache(paths, int(time.time()), quota)
        except QuotaError:
            pass
        emit(quota)
        return 0
    finally:
        release_lock(paths)


def main() -> int:
    try:
        return run()
    except QuotaError as exc:
        sys.stderr.write(f"codex quota unavailable: {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
