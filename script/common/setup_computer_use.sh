#!/bin/bash

# Install and register the shared computer-use MCP launchers for Claude Code,
# Codex, AGY, and daily opencode. Default is dry-run.
#
#   --apply / --remove  mutate user-level MCP registries and
#                       config/opencode/opencode.json
#   --install           install what the launchers need: the pinned npm driver
#                       (integrity, Team ID and notarization checked) and the
#                       private service repo at a pinned commit, its
#                       dependencies and its Swift helper. Registers nothing.
#   --dry-run --install print the install plan; nothing is changed and the
#                       network is not used
#
# Two servers, selected with --server:
#   open-computer-use  the third-party driver (computer-use-mcp.sh)
#   desktop-ops       the policy-gated layer on top of it (desktop-ops-mcp.sh)
#   all                both (default)
#
# This script never starts an MCP server, never asks for root, and never reads
# a secret. See config/ai/shared/computer-use/README.md.
set -euo pipefail

# Pins. The driver pins must match computer-use-mcp.sh; the launcher re-checks
# version and Team ID on every start.
DRIVER_PACKAGE="open-computer-use"
DRIVER_VERSION="0.3.6"
DRIVER_INTEGRITY="sha512-pGNfWBBefl5qzQMo6rkC/e28sOfeczTQ0hEKkYn2sXwti38uz+fC4Y0oBdtnNACemsNVR06Dzp6SozJjkpkbSg=="
DRIVER_TEAM_ID="J9P29FA5BX"
SERVICE_SLUG="miyago9267/desktop-ops"
SERVICE_URL="git@github.com:$SERVICE_SLUG.git"
SERVICE_PIN="864aa801ca0bde84bf29fae0d63fc7be0d195796"
SERVICE_DIR="$HOME/Project/Active/Tools/desktop-ops"

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHARED_DIR="$DOTFILE_DIR/config/ai/shared/computer-use"
OPENCODE_JSON="$DOTFILE_DIR/config/opencode/opencode.json"
CODEX_TOML="$HOME/.codex/config.toml"
MODE="dry-run"
INSTALL=0
DRY_SEEN=0
OTHER_ACTION=0
SERVER="all"
SKIPPED=0
# Set per server by the loop at the bottom.
NAME=""
LAUNCHER=""

usage() {
  printf 'usage: %s [--dry-run|--apply|--remove|--install|--dry-run --install] [--server open-computer-use|desktop-ops|all]\n' "$0" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    "") MODE="dry-run" ;;
    --dry-run)
      MODE="dry-run"
      DRY_SEEN=1
      ;;
    --apply)
      MODE="apply"
      OTHER_ACTION=1
      ;;
    --remove)
      MODE="remove"
      OTHER_ACTION=1
      ;;
    --install) INSTALL=1 ;;
    --server)
      [ "$#" -ge 2 ] || usage
      SERVER="$2"
      shift
      ;;
    --server=*) SERVER="${1#--server=}" ;;
    *) usage ;;
  esac
  shift
done

case "$SERVER" in
  open-computer-use | desktop-ops) SERVERS="$SERVER" ;;
  all) SERVERS="open-computer-use desktop-ops" ;;
  *) usage ;;
esac

launcher_for() {
  case "$1" in
    open-computer-use) printf '%s\n' "$SHARED_DIR/computer-use-mcp.sh" ;;
    desktop-ops) printf '%s\n' "$SHARED_DIR/desktop-ops-mcp.sh" ;;
  esac
}

# --install is its own action; it only combines with --dry-run.
if [ "$INSTALL" -eq 1 ]; then
  [ "$OTHER_ACTION" -eq 0 ] || usage
  MODE="install"
fi

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

# Follow symlinks to an absolute physical path.
real_path() {
  local path="$1" target dir
  while [ -L "$path" ]; do
    target="$(readlink "$path")" || return 1
    case "$target" in
      /*) path="$target" ;;
      *) path="$(dirname "$path")/$target" ;;
    esac
  done
  dir="$(CDPATH='' cd -P "$(dirname "$path")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$dir" "$(basename "$path")"
}

# Version from <package root>/package.json; the binary is never run to ask.
driver_version_at() {
  sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/package.json" 2>/dev/null | head -n 1
}

# Print the package root computer-use-mcp.sh would resolve: `open-computer-use`
# on PATH, else the newest ~/.nvm node version carrying the pinned version.
driver_locate() {
  local found candidate real key
  found="$(command -v "$DRIVER_PACKAGE" 2>/dev/null)" || found=""
  case "$found" in
    /*) [ -f "$found" ] && [ -x "$found" ] || found="" ;;
    *) found="" ;;
  esac
  if [ -z "$found" ]; then
    found="$(
      for candidate in "$HOME"/.nvm/versions/node/*/bin/"$DRIVER_PACKAGE"; do
        [ -x "$candidate" ] || continue
        real="$(real_path "$candidate")" || continue
        [ -f "$real" ] || continue
        [ "$(driver_version_at "$(dirname "$(dirname "$real")")")" = "$DRIVER_VERSION" ] || continue
        key="$(printf '%s\n' "$candidate" |
          sed -n 's|.*/v\([0-9]\{1,\}\)\.\([0-9]\{1,\}\)\.\([0-9]\{1,\}\)/bin/[^/]*$|\1 \2 \3|p')"
        [ -n "$key" ] || continue
        # shellcheck disable=SC2086 # three numeric fields, split on purpose
        printf '%08d%08d%08d %s\n' $key "$candidate"
      done | sort -r | head -n 1 | cut -d ' ' -f 2-
    )"
  fi
  [ -n "$found" ] || return 1
  real="$(real_path "$found")" || return 1
  [ -f "$real" ] || return 1
  dirname "$(dirname "$real")"
}

# Path of bun as desktop-ops-mcp.sh finds it, or nothing.
bun_path() {
  if command -v bun >/dev/null 2>&1; then
    command -v bun
  elif [ -x "$HOME/.bun/bin/bun" ]; then
    printf '%s\n' "$HOME/.bun/bin/bun"
  fi
}

# One line per thing the launcher of server $1 would refuse to start without.
missing_prerequisites() {
  local root
  case "$1" in
    open-computer-use)
      if ! root="$(driver_locate)" || [ "$(driver_version_at "$root")" != "$DRIVER_VERSION" ] ||
        [ ! -d "$root/dist/Open Computer Use.app" ]; then
        printf '%s %s is not installed\n' "$DRIVER_PACKAGE" "$DRIVER_VERSION"
      fi
      ;;
    desktop-ops)
      [ -f "$SERVICE_DIR/src/server.ts" ] || printf 'service repo not found: %s\n' "$SERVICE_DIR"
      [ -d "$SERVICE_DIR/node_modules/@modelcontextprotocol/sdk" ] ||
        printf 'dependencies are not installed in %s\n' "$SERVICE_DIR"
      [ -x "$SERVICE_DIR/helper/desktop-ops-helper" ] ||
        printf 'helper binary is not built: %s\n' "$SERVICE_DIR/helper/desktop-ops-helper"
      [ -n "$(bun_path)" ] || printf '%s\n' 'bun was not found on PATH or at ~/.bun/bin/bun'
      ;;
  esac
}

# Check every selected launcher and its prerequisites before touching anything,
# so --apply never registers a server that cannot start.
if [ "$MODE" = "apply" ] || [ "$MODE" = "dry-run" ]; then
  for NAME in $SERVERS; do
    LAUNCHER="$(launcher_for "$NAME")"
    if [ ! -x "$LAUNCHER" ]; then
      printf 'launcher is not executable: %s\n' "$LAUNCHER" >&2
      exit 1
    fi
  done
  PREREQ_MISSING=0
  for NAME in $SERVERS; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      PREREQ_MISSING=1
      printf 'missing prerequisite for %s: %s\n' "$NAME" "$line" >&2
    done <<<"$(missing_prerequisites "$NAME")"
  done
  if [ "$PREREQ_MISSING" -eq 1 ]; then
    printf 'run first: %s --install\n' "$0" >&2
    [ "$MODE" = "dry-run" ] || exit 1
  fi
fi

if [ "$MODE" = "install" ] && [ "$DRY_SEEN" -eq 1 ]; then
  printf 'mode=install (dry-run)\n'
else
  printf 'mode=%s\n' "$MODE"
fi

# --- --install ---------------------------------------------------------------------

tool_hint() {
  case "$1" in
    npm) printf '%s\n' 'install Node.js first (bash setup.sh --environment, "Node.js", or script/common/install_node.sh)' ;;
    bun) printf '%s\n' 'install Bun first (bash setup.sh --environment, "Bun", or script/common/install_bun.sh)' ;;
    git | swiftc) printf '%s\n' 'install the Xcode Command Line Tools: xcode-select --install' ;;
    codesign) printf '%s\n' 'part of macOS at /usr/bin/codesign; put /usr/bin on PATH' ;;
    spctl) printf '%s\n' 'part of macOS at /usr/sbin/spctl; put /usr/sbin on PATH' ;;
  esac
}

# /usr/bin/git and /usr/bin/swiftc exist without the Command Line Tools, as
# shims that open an install dialog. Treat those as missing instead of calling them.
tool_present() {
  local path
  path="$(command -v "$1" 2>/dev/null)" || return 1
  case "$path" in
    /usr/bin/git | /usr/bin/swiftc)
      command -v xcode-select >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1 || return 1
      ;;
  esac
}

# Stop before the first step when a tool is missing, so nothing is half-done.
require_tools() {
  local tool missing=0 newest
  # nvm is lazy-loaded; a non-interactive shell usually has no npm on PATH.
  if ! command -v npm >/dev/null 2>&1; then
    newest="$(ls -d "$HOME"/.nvm/versions/node/*/bin/npm 2>/dev/null | sort -V | tail -n 1)" || newest=""
    if [ -n "$newest" ] && [ -x "$newest" ]; then PATH="$(dirname "$newest"):$PATH"; fi
  fi
  if ! command -v bun >/dev/null 2>&1 && [ -x "$HOME/.bun/bin/bun" ]; then
    PATH="$HOME/.bun/bin:$PATH"
  fi
  export PATH
  for tool in "$@"; do
    if ! tool_present "$tool"; then
      missing=1
      printf 'missing tool: %s -- %s\n' "$tool" "$(tool_hint "$tool")" >&2
    fi
  done
  [ "$missing" -eq 0 ] || exit 1
}

# Signer and notarization of the app bundled in package root $1. Prints the
# reason and returns 1 on any mismatch.
driver_verify() {
  local app="$1/dist/Open Computer Use.app" team assessment
  if [ ! -d "$app" ]; then
    printf 'bundled app not found: %s\n' "$app"
    return 1
  fi
  team="$(codesign -dv --verbose=2 "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -n 1)" || team=""
  if [ "$team" != "$DRIVER_TEAM_ID" ]; then
    printf "TeamIdentifier is '%s', expected %s\n" "${team:-none}" "$DRIVER_TEAM_ID"
    return 1
  fi
  if ! codesign --verify --strict "$app" >/dev/null 2>&1; then
    printf '%s\n' 'signature does not verify (codesign --verify --strict)'
    return 1
  fi
  if ! assessment="$(spctl --assess --type execute -vv "$app" 2>&1)" ||
    ! printf '%s\n' "$assessment" | grep -qx 'source=Notarized Developer ID'; then
    printf '%s\n' 'app is not accepted as notarized by Gatekeeper (spctl --assess)'
    return 1
  fi
}

install_driver() {
  local root reason integrity spec="$DRIVER_PACKAGE@$DRIVER_VERSION"
  if root="$(driver_locate)" && [ "$(driver_version_at "$root")" = "$DRIVER_VERSION" ]; then
    reason="$(driver_verify "$root")" ||
      die "driver: installed $spec failed verification: $reason. Not touching it; remove it (npm rm -g $DRIVER_PACKAGE) and run --install again."
    printf 'driver: %s already installed and verified (%s)\n' "$spec" "$root"
    return 0
  fi

  if [ "$DRY_SEEN" -eq 1 ]; then
    printf 'driver: %s is not installed\n' "$spec"
    printf 'would check: npm view %s dist.integrity equals %s\n' "$spec" "$DRIVER_INTEGRITY"
    printf 'would run: npm install -g --ignore-scripts %s\n' "$spec"
    printf 'would check: Team ID %s and notarization of the installed app\n' "$DRIVER_TEAM_ID"
    return 0
  fi

  integrity="$(npm view "$spec" dist.integrity)" || die "driver: could not read the registry integrity of $spec"
  [ "$integrity" = "$DRIVER_INTEGRITY" ] ||
    die "driver: registry integrity of $spec is '${integrity:-empty}', expected $DRIVER_INTEGRITY; refusing to install"
  npm install -g --ignore-scripts "$spec" || die "driver: npm install of $spec failed"
  hash -r

  root="$(driver_locate)" ||
    die "driver: $spec was installed but is not on PATH or under ~/.nvm, where the launcher looks"
  [ "$(driver_version_at "$root")" = "$DRIVER_VERSION" ] ||
    die "driver: $root is version '$(driver_version_at "$root")', expected $DRIVER_VERSION"
  reason="$(driver_verify "$root")" ||
    die "driver: installed $spec failed verification: $reason. Do not use it; remove it with: npm rm -g $DRIVER_PACKAGE"
  printf 'driver: installed and verified %s (%s)\n' "$spec" "$root"
}

install_service_repo() {
  local dir="$SERVICE_DIR" origin status head
  if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
    if [ "$DRY_SEEN" -eq 1 ]; then
      printf 'would run: git clone %s %s\n' "$SERVICE_URL" "$dir"
      printf 'would run: git -C %s checkout --detach %s\n' "$dir" "$SERVICE_PIN"
      return 0
    fi
    mkdir -p "$(dirname "$dir")"
    git clone "$SERVICE_URL" "$dir" ||
      die "service: git clone of $SERVICE_URL failed. The repo is private: set up your GitHub ssh key (or clone it yourself with: gh repo clone $SERVICE_SLUG $dir), then run --install again."
    git -C "$dir" checkout --detach "$SERVICE_PIN" || die "service: could not check out $SERVICE_PIN in $dir"
    head="$(git -C "$dir" rev-parse HEAD)" || head=""
    [ "$head" = "$SERVICE_PIN" ] || die "service: $dir is at '$head' after checkout, expected $SERVICE_PIN"
    printf 'service: cloned %s at %s\n' "$dir" "$SERVICE_PIN"
    return 0
  fi

  [ -d "$dir" ] && [ -e "$dir/.git" ] ||
    die "service: $dir exists but is not a git checkout; move it away and run --install again"
  origin="$(git -C "$dir" config --get remote.origin.url)" || origin=""
  case "$origin" in
    "git@github.com:$SERVICE_SLUG.git" | "git@github.com:$SERVICE_SLUG" | \
      "ssh://git@github.com/$SERVICE_SLUG.git" | "ssh://git@github.com/$SERVICE_SLUG" | \
      "https://github.com/$SERVICE_SLUG.git" | "https://github.com/$SERVICE_SLUG") ;;
    *) die "service: origin of $dir is '${origin:-unset}', expected $SERVICE_URL (ssh or https form); refusing to touch it" ;;
  esac

  if git -C "$dir" merge-base --is-ancestor "$SERVICE_PIN" HEAD 2>/dev/null; then
    printf 'service: %s already contains %s; checkout left alone\n' "$dir" "$SERVICE_PIN"
    return 0
  fi

  # HEAD is behind the pin (or does not have it yet). Only a clean work tree is
  # moved, and only forward; local work is never reset, cleaned or stashed.
  status="$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --porcelain)" || die "service: git status failed in $dir"
  [ -z "$status" ] ||
    die "service: $dir does not contain $SERVICE_PIN and has local changes. Commit or stash them yourself, then run --install again."
  if [ "$DRY_SEEN" -eq 1 ]; then
    printf 'would run: git -C %s fetch origin\n' "$dir"
    printf 'would run: git -C %s merge --ff-only %s\n' "$dir" "$SERVICE_PIN"
    return 0
  fi
  git -C "$dir" fetch origin || die "service: git fetch failed in $dir"
  git -C "$dir" cat-file -e "$SERVICE_PIN^{commit}" 2>/dev/null ||
    die "service: $SERVICE_PIN is not on origin; check the pin in $0"
  git -C "$dir" merge-base --is-ancestor HEAD "$SERVICE_PIN" ||
    die "service: $dir has diverged from $SERVICE_PIN and cannot be fast-forwarded; resolve it by hand"
  git -C "$dir" merge --ff-only "$SERVICE_PIN" || die "service: fast-forward to $SERVICE_PIN failed in $dir"
  printf 'service: fast-forwarded %s to %s\n' "$dir" "$SERVICE_PIN"
}

install_service_build() {
  local dir="$SERVICE_DIR" modules="$SERVICE_DIR/node_modules" helper="$SERVICE_DIR/helper/desktop-ops-helper"
  if [ ! -d "$dir" ]; then
    # Dry run on a machine without the repo: nothing to inspect yet.
    printf 'would run: (cd %s && bun install --frozen-lockfile --ignore-scripts)\n' "$dir"
    printf 'would run: /bin/bash %s/helper/build.sh\n' "$dir"
    return 0
  fi

  # bun rewrites node_modules/.bin on every install, so either mtime shows an
  # install that happened after the lockfile last changed.
  if [ ! -d "$modules/@modelcontextprotocol/sdk" ] ||
    { [ "$dir/bun.lock" -nt "$modules" ] && [ "$dir/bun.lock" -nt "$modules/.bin" ]; }; then
    if [ "$DRY_SEEN" -eq 1 ]; then
      printf 'would run: (cd %s && bun install --frozen-lockfile --ignore-scripts)\n' "$dir"
    else
      (cd "$dir" && bun install --frozen-lockfile --ignore-scripts) || die "service: bun install failed in $dir"
      touch "$modules"
      printf 'service: dependencies installed\n'
    fi
  else
    printf 'service: dependencies are current\n'
  fi

  if [ ! -x "$helper" ] || [ "$helper.swift" -nt "$helper" ]; then
    if [ "$DRY_SEEN" -eq 1 ]; then
      printf 'would run: /bin/bash %s/helper/build.sh\n' "$dir"
    else
      /bin/bash "$dir/helper/build.sh" || die "service: helper build failed ($dir/helper/build.sh)"
      [ -x "$helper" ] || die "service: helper build did not produce $helper"
      printf 'service: helper built\n'
    fi
  else
    printf 'service: helper is current\n'
  fi
}

if [ "$MODE" = "install" ]; then
  TOOLS=""
  for NAME in $SERVERS; do
    case "$NAME" in
      open-computer-use) TOOLS="$TOOLS npm codesign spctl" ;;
      desktop-ops) TOOLS="$TOOLS git bun swiftc" ;;
    esac
  done
  # shellcheck disable=SC2086 # word list, split on purpose
  require_tools $TOOLS
  for NAME in $SERVERS; do
    case "$NAME" in
      open-computer-use) install_driver ;;
      desktop-ops)
        install_service_repo
        install_service_build
        ;;
    esac
  done
  if [ "$DRY_SEEN" -eq 1 ]; then
    printf '%s\n' 'no changes made; drop --dry-run to install'
  fi
  cat <<STEPS

Left for you (cannot be automated):
  1. open-computer-use doctor
     grants Accessibility and Screen Recording to "Open Computer Use" in System Settings
  2. make TYPESAFE_API_KEY available through your existing secrets setup;
     this script never reads or prints it
  3. $0 --apply
  4. restart agent sessions (Claude Code, Codex, agy, opencode)
STEPS
  exit 0
fi

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
# opencode.json 在版控裡，三個平台共用；home 用 opencode 的 {env:HOME} 表示。
home = os.path.expanduser("~").rstrip("/")
if home and launcher.startswith(home + "/"):
    launcher = "{env:HOME}" + launcher[len(home):]


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

# Register or remove $NAME (launcher $LAUNCHER) in the four runtimes.
process_server() {
  printf '%s: %s\n' "$NAME" "$LAUNCHER"

  if [ "$MODE" = "dry-run" ]; then
    printf 'would run: claude mcp add --scope user %s -- %s\n' "$NAME" "$LAUNCHER"
    printf 'would append: marker-delimited [mcp_servers.%s] block to %s\n' "$NAME" "$CODEX_TOML"
    printf 'would run: agy mcp add %s %s\n' "$NAME" "$LAUNCHER"
    printf 'would set: mcp.%s and permission."%s_*"=ask in %s\n' "$NAME" "$NAME" "$OPENCODE_JSON"
    return 0
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
}

for NAME in $SERVERS; do
  LAUNCHER="$(launcher_for "$NAME")"
  process_server
done

if [ "$MODE" = "dry-run" ]; then
  printf '%s\n' 'no changes made; use --apply to register or --remove to unregister'
  exit 0
fi

# A skipped runtime is reported above; signal it without hiding the others.
[ "$SKIPPED" -eq 0 ] || exit 3
