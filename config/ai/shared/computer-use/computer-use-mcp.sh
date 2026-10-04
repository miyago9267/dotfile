#!/bin/sh

# Hardened launcher for the open-computer-use MCP server (third-party macOS
# computer-use driver). Shared by Claude Code, Codex, agy, and opencode.
#
# This is hygiene, not a security boundary: it pins the package version, checks
# the bundled app's signing team, and scrubs OPEN_COMPUTER_USE_* overrides
# before starting `mcp`. The real boundary is the macOS TCC grant.
#
# Fails closed: any check that does not pass exits non-zero without exec.
#
# Binary resolution order (nvm is lazy-loaded, so agent PATHs often lack it):
#   1. COMPUTER_USE_MCP_BIN (test seam)
#   2. `open-computer-use` on PATH, only if that is an absolute executable file
#   3. newest $HOME/.nvm/versions/node/*/bin/open-computer-use whose package
#      version equals the pin
#
# Test seams (names deliberately outside the OPEN_COMPUTER_USE_ prefix):
#   COMPUTER_USE_MCP_BIN       path to the open-computer-use executable
#   COMPUTER_USE_MCP_CODESIGN  codesign binary (default: /usr/bin/codesign)

EXPECTED_VERSION='0.3.6'
EXPECTED_TEAM_ID='J9P29FA5BX'
CODESIGN="${COMPUTER_USE_MCP_CODESIGN:-/usr/bin/codesign}"

die() {
  printf 'computer-use-mcp: %s\n' "$1" >&2
  exit "${2:-1}"
}

# Follow symlinks to an absolute physical path, independent of the caller cwd.
real_path() {
  rp_path="$1"
  while [ -L "$rp_path" ]; do
    rp_target="$(/usr/bin/readlink "$rp_path")" || return 1
    case "$rp_target" in
      /*) rp_path="$rp_target" ;;
      *) rp_path="$(/usr/bin/dirname "$rp_path")/$rp_target" ;;
    esac
  done
  rp_dir="$(CDPATH='' cd -P "$(/usr/bin/dirname "$rp_path")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$rp_dir" "$(/usr/bin/basename "$rp_path")"
}

# Version from the manifest of the package that owns <root>/bin/<executable>;
# never run the binary to ask.
package_version() {
  /usr/bin/sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$(/usr/bin/dirname "$(/usr/bin/dirname "$1")")/package.json" 2>/dev/null | /usr/bin/head -n 1
}

# Newest node version under ~/.nvm that carries the pinned package version.
find_in_nvm() {
  [ -n "${HOME:-}" ] || return 1
  fn_best="$(
    for fn_candidate in "$HOME"/.nvm/versions/node/*/bin/open-computer-use; do
      [ -x "$fn_candidate" ] || continue
      fn_real="$(real_path "$fn_candidate")" || continue
      [ -f "$fn_real" ] || continue
      [ "$(package_version "$fn_real")" = "$EXPECTED_VERSION" ] || continue
      # .../node/v24.13.1/bin/open-computer-use -> "24 13 1"
      fn_key="$(printf '%s\n' "$fn_candidate" |
        /usr/bin/sed -n 's|.*/v\([0-9]\{1,\}\)\.\([0-9]\{1,\}\)\.\([0-9]\{1,\}\)/bin/open-computer-use$|\1 \2 \3|p')"
      [ -n "$fn_key" ] || continue
      # Zero-padded key first so a plain reverse sort picks the newest.
      # shellcheck disable=SC2086 # three numeric fields, split on purpose
      printf '%08d%08d%08d %s\n' $fn_key "$fn_candidate"
    done | /usr/bin/sort -r | /usr/bin/head -n 1 | /usr/bin/cut -d ' ' -f 2-
  )"
  [ -n "$fn_best" ] && printf '%s\n' "$fn_best"
}

found="${COMPUTER_USE_MCP_BIN:-}"
if [ -n "$found" ]; then
  case "$found" in
    /*) ;;
    *) die "refusing non-absolute executable path: $found" 127 ;;
  esac
else
  found="$(command -v open-computer-use 2>/dev/null)" || found=''
  case "$found" in
    /*) [ -f "$found" ] && [ -x "$found" ] || found='' ;;
    *) found='' ;;
  esac
  [ -n "$found" ] || found="$(find_in_nvm)" ||
    die "open-computer-use $EXPECTED_VERSION was not found on PATH or under ~/.nvm; run: npm i -g --ignore-scripts open-computer-use@$EXPECTED_VERSION" 127
fi
bin="$(real_path "$found")" || die 'open-computer-use executable could not be resolved' 127
[ -f "$bin" ] && [ -x "$bin" ] || die "open-computer-use executable is missing: $bin" 127

# Layout of the npm package: <root>/bin/open-computer-use, <root>/package.json,
# <root>/dist/Open Computer Use.app
pkg_root="$(/usr/bin/dirname "$(/usr/bin/dirname "$bin")")"
pkg_json="$pkg_root/package.json"
app="$pkg_root/dist/Open Computer Use.app"

[ -r "$pkg_json" ] || die "package.json not found next to the executable: $pkg_json"
version="$(package_version "$bin")"
[ "$version" = "$EXPECTED_VERSION" ] ||
  die "package version is '${version:-unknown}', expected $EXPECTED_VERSION; refusing to start"

[ -d "$app" ] || die "bundled app not found: $app"
[ -x "$CODESIGN" ] || die "codesign not available at $CODESIGN; cannot check the signer"
team_id="$("$CODESIGN" -dv --verbose=2 "$app" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p' | /usr/bin/head -n 1)"
[ "$team_id" = "$EXPECTED_TEAM_ID" ] ||
  die "bundled app TeamIdentifier is '${team_id:-none}', expected $EXPECTED_TEAM_ID; refusing to start"

"$CODESIGN" --verify --strict "$app" >/dev/null 2>&1 ||
  die "bundled app signature does not verify (codesign --verify --strict); refusing to start"

# The bin script is `#!/usr/bin/env node`. Prefer the node that sits next to the
# installed entry (same npm prefix); otherwise require one on PATH.
node_dir="$(/usr/bin/dirname "$found")"
if [ -x "$node_dir/node" ] && [ ! -d "$node_dir/node" ]; then
  PATH="$node_dir${PATH:+:$PATH}"
  export PATH
elif ! command -v node >/dev/null 2>&1; then
  die "node was not found next to $found or on PATH; cannot start the launcher script" 127
fi

# Drop every inherited OPEN_COMPUTER_USE_* override (native command, pointer
# fallbacks, agent proxy, ...) so the child runs with upstream defaults only.
for name in $(/usr/bin/env | /usr/bin/sed -n 's/^\(OPEN_COMPUTER_USE_[A-Za-z0-9_]*\)=.*/\1/p'); do
  unset "$name"
done

# MCP server only: the subcommand is fixed, so js/repl can never be selected.
exec "$bin" mcp "$@"
