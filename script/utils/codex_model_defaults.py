#!/usr/bin/env python3
"""Synchronize the managed model defaults without replacing local Codex config."""

from __future__ import annotations

import os
import re
import shutil
import stat
import sys
import tempfile
from datetime import datetime
from pathlib import Path
import tomllib

MANAGED_KEYS = ("model", "model_reasoning_effort")
TABLE_HEADER = re.compile(r"^\s*\[\[?[^\]\n]+\]\]?\s*(?:#.*)?(?:\r?\n)?$")


def _read_defaults(path: Path) -> dict[str, str]:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    defaults = {key: data.get(key) for key in MANAGED_KEYS}
    if any(not isinstance(value, str) or not value for value in defaults.values()):
        raise ValueError("model-defaults.toml must define model and model_reasoning_effort strings")
    return defaults


def _replace_root_values(text: str, defaults: dict[str, str]) -> str:
    lines = text.splitlines(keepends=True)
    root_end = next(
        (index for index, line in enumerate(lines) if TABLE_HEADER.match(line)),
        len(lines),
    )
    root = lines[:root_end]
    tables = lines[root_end:]
    missing: list[str] = []

    for key, value in defaults.items():
        matches = [
            index
            for index, line in enumerate(root)
            if re.match(rf"^\s*{re.escape(key)}\s*=", line)
        ]
        if len(matches) > 1:
            raise ValueError(f"duplicate root-level {key} entries")
        encoded = f'{key} = "{value}"'
        if matches:
            index = matches[0]
            old_line = root[index]
            newline = "\r\n" if old_line.endswith("\r\n") else "\n" if old_line.endswith("\n") else ""
            comment_match = re.search(r"\s+#.*$", old_line.rstrip("\r\n"))
            comment = f" {comment_match.group(0).lstrip()}" if comment_match else ""
            root[index] = encoded + comment + newline
        else:
            missing.append(encoded + "\n")

    if missing:
        if root and not root[-1].endswith(("\n", "\r")):
            root[-1] += "\n"
        root.extend(missing)
    return "".join(root + tables)


def sync_config(config_path: Path, defaults_path: Path) -> tuple[str, Path | None]:
    if config_path.is_symlink():
        return "skipped symlink", None

    defaults = _read_defaults(defaults_path)
    original = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
    parsed = tomllib.loads(original) if original.strip() else {}
    if all(parsed.get(key) == value for key, value in defaults.items()):
        return "unchanged", None

    updated = _replace_root_values(original, defaults)
    verified = tomllib.loads(updated)
    if any(verified.get(key) != value for key, value in defaults.items()):
        raise ValueError("updated Codex config failed model-default verification")

    config_path.parent.mkdir(parents=True, exist_ok=True)
    backup_path = None
    if config_path.exists():
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        backup_path = config_path.with_name(f"{config_path.name}.bak.{stamp}")
        shutil.copy2(config_path, backup_path)
        file_mode = stat.S_IMODE(config_path.stat().st_mode)
    else:
        file_mode = 0o600

    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{config_path.name}.", dir=config_path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
            stream.write(updated)
        os.chmod(temporary_name, file_mode)
        os.replace(temporary_name, config_path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)

    return "updated", backup_path


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: codex_model_defaults.py CONFIG_TOML DEFAULTS_TOML", file=sys.stderr)
        return 2
    config_path, defaults_path = map(Path, argv[1:])
    try:
        status, backup = sync_config(config_path, defaults_path)
    except (OSError, ValueError, tomllib.TOMLDecodeError) as error:
        print(f"[WARN] model defaults not synced for {config_path}: {error}", file=sys.stderr)
        return 1
    suffix = f"; backup={backup}" if backup else ""
    print(f"[OK] model defaults {status}: {config_path}{suffix}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
