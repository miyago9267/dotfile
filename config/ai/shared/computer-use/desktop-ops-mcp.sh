#!/bin/sh

# Thin launcher for the desktop-ops MCP server, shared by Claude Code, Codex,
# agy, and opencode.
#
# The Jev path switch is the single assignment below. It is set in this file
# only: every inherited DESKTOP_OPS_* variable is dropped before the fixed
# ones are set, so the caller's environment cannot turn the Jev path off or
# on, nor point the server at another helper, driver, policy file, state
# directory or API endpoint.
#
#   off  five zero-model tools. No key is looked up (no secrets file, no
#        broker), any inherited TYPESAFE_API_KEY is removed, and the server
#        makes no outbound request.
#   on   adds computer_do / computer_check / computer_choose / computer_read,
#        which send screen text to the TypeSafe API. Only TYPESAFE_API_KEY is
#        injected, the same way jev-browser-mcp.sh does it: the sops cache
#        (~/.env.secrets, read in a subshell so nothing else leaks), else an
#        inherited value, else the agent-secret broker. The key travels in the
#        environment only: never as an argument, never printed.
#
# Shipped as `on` since 2026-10-05 (S2b live acceptance done with Miyago). To
# turn the Jev path off, change that one line to `off`. With `on` and no key
# available the server still starts: the four Jev tools report no_api_key and
# send nothing.
#
# Fails closed: a missing repo, dependency tree, helper binary, or bun exits
# non-zero without exec, before any key lookup. Dependencies are pinned and
# installed inside the repo; nothing is fetched at start (bun --no-install),
# and no .env file is loaded (bun --no-env-file).
#
# Test seam: DESKTOP_OPS_HOME (repo location), read before the scrub.

die() {
  printf 'desktop-ops-mcp: %s\n' "$1" >&2
  exit "${2:-1}"
}

repo="${DESKTOP_OPS_HOME:-${HOME:-}/Project/Active/Tools/desktop-ops}"
self_dir="$(CDPATH='' cd -P "$(/usr/bin/dirname "$0")" 2>/dev/null && pwd -P)" ||
  die 'cannot resolve the launcher directory'

bun="$(command -v bun 2>/dev/null)" || bun=''
case "$bun" in
  /*) [ -f "$bun" ] && [ -x "$bun" ] || bun='' ;;
  *) bun='' ;;
esac
if [ -z "$bun" ] && [ -n "${HOME:-}" ] && [ -x "$HOME/.bun/bin/bun" ]; then
  bun="$HOME/.bun/bin/bun"
fi
[ -n "$bun" ] || die 'bun was not found on PATH or at ~/.bun/bin/bun' 127

[ -f "$repo/src/server.ts" ] || die "desktop-ops repo not found: $repo"
[ -d "$repo/node_modules/@modelcontextprotocol/sdk" ] ||
  die "dependencies are not installed; run: (cd $repo && bun install --frozen-lockfile --ignore-scripts)"
[ -x "$repo/helper/desktop-ops-helper" ] ||
  die "helper binary is not built; run: $repo/helper/build.sh"
[ -x "$self_dir/computer-use-mcp.sh" ] || die "S1 launcher is missing: $self_dir/computer-use-mcp.sh"

for name in $(/usr/bin/env | /usr/bin/sed -n 's/^\(DESKTOP_OPS_[A-Za-z0-9_]*\)=.*/\1/p'); do
  unset "$name"
done

DESKTOP_OPS_JEV_PATH=on
DESKTOP_OPS_DRIVER_CMD="$self_dir/computer-use-mcp.sh"
DESKTOP_OPS_POLICY="$self_dir/policy.json"
export DESKTOP_OPS_JEV_PATH DESKTOP_OPS_DRIVER_CMD DESKTOP_OPS_POLICY

# Run from the repo so bun never picks up a .env or bunfig.toml from the
# caller's working directory.
cd "$repo" || die "cannot enter $repo"

if [ "$DESKTOP_OPS_JEV_PATH" != on ]; then
  unset TYPESAFE_API_KEY
  exec "$bun" --no-install --no-env-file "$repo/src/server.ts"
fi

# Prefer the age+sops cache used by `sec`. Only this one value is kept; the
# rest of the bundle stays inside the subshell.
if [ -r "${HOME:-}/.env.secrets" ]; then
  cached_key="$(. "${HOME}/.env.secrets" 2>/dev/null; printf '%s' "${TYPESAFE_API_KEY:-}")"
  if [ -n "$cached_key" ]; then
    export TYPESAFE_API_KEY="$cached_key"
  fi
  unset cached_key
fi

if [ -n "${TYPESAFE_API_KEY:-}" ]; then
  exec "$bun" --no-install --no-env-file "$repo/src/server.ts"
fi

if command -v agent-secret >/dev/null 2>&1; then
  exec agent-secret run typesafe-api -- "$bun" --no-install --no-env-file "$repo/src/server.ts"
fi

# No key anywhere: start anyway. The five zero-model tools work, and the Jev
# tools report no_api_key without sending anything.
exec "$bun" --no-install --no-env-file "$repo/src/server.ts"
