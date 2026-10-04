#!/bin/bash

# Register the shared open-computer-use MCP launcher with Claude Code, Codex,
# AGY, and daily opencode. Default is dry-run; --apply and --remove mutate
# user-level MCP registries and config/opencode/opencode.json.
#
# Registration only: this script never starts the MCP server, and never installs
# or verifies the npm package (see config/ai/shared/computer-use/README.md).
set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCHER="$DOTFILE_DIR/config/ai/shared/computer-use/computer-use-mcp.sh"
OPENCODE_JSON="$DOTFILE_DIR/config/opencode/opencode.json"
CODEX_TOML="$HOME/.codex/config.toml"
NAME="open-computer-use"
MODE="dry-run"
SKIPPED=0

case "${1:-}" in
  "" | --dry-run) MODE="dry-run" ;;
  --apply) MODE="apply" ;;
  --remove) MODE="remove" ;;
  *)
    printf 'usage: %s [--dry-run|--apply|--remove]\n' "$0" >&2
    exit 2
    ;;
esac

if [ "$MODE" != "remove" ] && [ ! -x "$LAUNCHER" ]; then
  printf 'launcher is not executable: %s\n' "$LAUNCHER" >&2
  exit 1
fi

printf 'mode=%s\n' "$MODE"
printf '%s: %s\n' "$NAME" "$LAUNCHER"

skip() {
  SKIPPED=1
  printf 'skip %s\n' "$1" >&2
}

# Append or delete this script's marker-delimited block in ~/.codex/config.toml.
# Plain text edit, atomic replace, file mode kept; nothing else in the file is
# parsed or rewritten, so --remove restores the pre-apply bytes.
# Exit codes: 0 done, 1 stop (file left unchanged), 4 table present without
# markers on remove (caller falls back to `codex mcp remove`).
codex_edit() {
  python3 - "$1" "$CODEX_TOML" "$NAME" "$LAUNCHER" <<'PY'
import os
import re
import sys
import tempfile

action, path, name, launcher = sys.argv[1:5]
path = os.path.realpath(path)
owner = "script/common/setup_computer_use.sh"
begin = "# >>> %s (managed by %s) >>>" % (name, owner)
end = "# <<< %s (managed by %s) <<<" % (name, owner)
header = "[mcp_servers.%s]" % name


def stop(message):
    print("Codex: " + message, file=sys.stderr)
    sys.exit(1)


with open(path, "rb") as handle:
    raw = handle.read()
text = raw.decode("utf-8")

block = '\n%s\n%s\ncommand = "%s"\n%s\n' % (begin, header, launcher, end)
table = re.compile(r'^[ \t]*\[[ \t]*mcp_servers[ \t]*\.[ \t]*["\']?%s["\']?[ \t]*(\]|\.)' % re.escape(name), re.M)
managed = re.compile(r"\n?^%s\n.*?^%s\n" % (re.escape(begin), re.escape(end)), re.M | re.S)
has_markers = begin in text or end in text

if action == "apply":
    if re.search(r'["\\\x00-\x1f]', launcher):
        stop("launcher path cannot be written as a TOML string")
    if block in text:
        print("codex: already up to date")
        sys.exit(0)
    if has_markers:
        stop("managed block exists with different content; resolve it by hand")
    if table.search(text):
        stop("[mcp_servers.%s] already exists without this script's markers" % name)
    if text and not text.endswith("\n"):
        stop("config.toml does not end with a newline; not appending")
    new_text = text + block
else:
    if block in text:
        new_text = text.replace(block, "", 1)
    elif has_markers:
        new_text, count = managed.subn("", text, count=1)
        if count != 1:
            stop("managed markers are damaged; resolve them by hand")
    elif table.search(text):
        sys.exit(4)
    else:
        print("codex: already up to date")
        sys.exit(0)
    if begin in new_text or end in new_text or table.search(new_text):
        stop("another %s entry would remain; resolve it by hand" % name)

try:
    import tomllib
except ImportError:
    tomllib = None
if tomllib is not None:
    try:
        parsed = tomllib.loads(new_text)
    except tomllib.TOMLDecodeError as error:
        stop("edited config would not parse as TOML (%s)" % error)
    entry = parsed.get("mcp_servers", {}).get(name)
    expected = {"command": launcher} if action == "apply" else None
    if entry != expected:
        stop("edited config does not contain the expected %s entry" % name)

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".config.toml.")
try:
    with os.fdopen(fd, "wb") as handle:
        handle.write(new_text.encode("utf-8"))
    os.chmod(tmp, os.stat(path).st_mode & 0o7777)
    os.replace(tmp, path)
except BaseException:
    os.unlink(tmp)
    raise
print("codex: updated " + path)
PY
}

# Edit only the mcp entry and the permission rule for this server in the daily
# opencode config. opencode names MCP tools "<server>_<tool>" and matches
# permission keys with wildcards (last match wins), so "<server>_*": "ask" is
# appended as the last permission rule. Refuses to touch the file unless it
# round-trips through this writer byte-for-byte, so --remove restores it exactly.
opencode_edit() {
  python3 - "$1" "$OPENCODE_JSON" "$NAME" "$LAUNCHER" <<'PY'
import json
import os
import sys
import tempfile

action, path, name, launcher = sys.argv[1:5]
rule = name + "_*"


def dump(data):
    return (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


with open(path, "rb") as handle:
    raw = handle.read()
config = json.loads(raw.decode("utf-8"))
if dump(config) != raw:
    sys.exit("opencode.json does not round-trip byte-for-byte; not editing it")

if action == "apply":
    permission = config.setdefault("permission", {})
    if not isinstance(permission, dict):
        sys.exit("opencode permission is not an object; cannot add an ask rule")
    mcp = config.setdefault("mcp", {})
    mcp[name] = {"type": "local", "command": [launcher], "enabled": True}
    permission.pop(rule, None)
    permission[rule] = "ask"
else:
    mcp = config.get("mcp")
    if isinstance(mcp, dict):
        mcp.pop(name, None)
        if not mcp:
            del config["mcp"]
    permission = config.get("permission")
    if isinstance(permission, dict):
        permission.pop(rule, None)
        if not permission:
            del config["permission"]

out = dump(config)
if out == raw:
    print("opencode: already up to date")
    sys.exit(0)

fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".opencode.json.")
try:
    with os.fdopen(fd, "wb") as handle:
        handle.write(out)
    os.chmod(tmp, os.stat(path).st_mode & 0o7777)
    os.replace(tmp, path)
except BaseException:
    os.unlink(tmp)
    raise
print("opencode: updated " + path)
PY
}

if [ "$MODE" = "dry-run" ]; then
  printf 'would run: claude mcp add --scope user %s -- %s\n' "$NAME" "$LAUNCHER"
  printf 'would append: marker-delimited [mcp_servers.%s] block to %s\n' "$NAME" "$CODEX_TOML"
  printf 'would run: agy mcp add %s %s\n' "$NAME" "$LAUNCHER"
  printf 'would set: mcp.%s and permission."%s_*"=ask in %s\n' "$NAME" "$NAME" "$OPENCODE_JSON"
  printf '%s\n' 'no changes made; use --apply to register or --remove to unregister'
  exit 0
fi

# Claude: `claude mcp list` health-checks (spawns) every server, so presence is
# never probed here; remove-then-add keeps --apply idempotent.
if command -v claude >/dev/null 2>&1; then
  claude mcp remove --scope user "$NAME" >/dev/null 2>&1 || true
  if [ "$MODE" = "apply" ]; then
    claude mcp add --scope user "$NAME" -- "$LAUNCHER"
  fi
else
  skip 'Claude: claude command not found'
fi

# Codex: native ~/.codex only. `codex mcp add/remove` re-serializes unrelated
# tables, so the entry is a marker-delimited text block owned by this script.
if [ ! -f "$CODEX_TOML" ]; then
  skip "Codex: config not found: $CODEX_TOML"
elif ! command -v python3 >/dev/null 2>&1; then
  skip 'Codex: python3 not found'
else
  codex_rc=0
  codex_edit "$MODE" || codex_rc=$?
  if [ "$codex_rc" -eq 4 ]; then
    # Table exists but the markers are gone: Codex rewrote the file.
    printf '%s\n' 'warning: Codex markers are gone; falling back to `codex mcp remove`, config.toml will not be byte-identical to its pre-apply state' >&2
    if command -v codex >/dev/null 2>&1; then
      codex mcp remove "$NAME"
    else
      skip 'Codex: codex command not found for fallback removal'
    fi
  elif [ "$codex_rc" -ne 0 ]; then
    skip 'Codex: config left unchanged'
  fi
fi

# AGY: add is add-or-update; no trust/auto-approve flag is passed.
if command -v agy >/dev/null 2>&1; then
  if [ "$MODE" = "apply" ]; then
    agy mcp add "$NAME" "$LAUNCHER"
  else
    agy mcp remove "$NAME" >/dev/null 2>&1 || true
  fi
else
  skip 'AGY: agy command not found'
fi

if [ ! -f "$OPENCODE_JSON" ]; then
  skip "opencode: config not found: $OPENCODE_JSON"
elif ! command -v python3 >/dev/null 2>&1; then
  skip 'opencode: python3 not found'
elif ! opencode_edit "$MODE"; then
  skip 'opencode: config left unchanged'
fi

if [ "$MODE" = "apply" ]; then
  printf 'registered %s for Claude/Codex/AGY/opencode\n' "$NAME"
else
  printf 'removed %s from Claude/Codex/AGY/opencode\n' "$NAME"
fi

# A skipped runtime is reported above; signal it without hiding the others.
[ "$SKIPPED" -eq 0 ] || exit 3
