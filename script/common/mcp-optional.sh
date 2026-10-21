#!/bin/bash

# Manage opt-in Claude Code MCP servers listed in config/ai/claude/mcp-optional.json.
# This script only registers or removes entries; it never starts a server.
#   list                          names and whether each is registered here
#   on <name> [--scope SCOPE]     add the entry (SCOPE: local|project|user, default local)
#   off <name> [--scope SCOPE]    remove the entry
set -eu

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$DOTFILE_DIR/config/ai/claude/mcp-optional.json"

usage() {
  printf 'usage: %s list | on <name> [--scope local|project|user] | off <name> [--scope local|project|user]\n' "$0" >&2
  exit 2
}

names() {
  python3 -I -c 'import json, sys; print("\n".join(json.load(open(sys.argv[1]))))' "$CONFIG"
}

check_name() {
  if ! names | grep -qx -- "$1"; then
    printf 'unknown name: %s\nvalid names: %s\n' "$1" "$(names | paste -sd' ' -)" >&2
    exit 2
  fi
}

# Sets SCOPE from the remaining arguments.
parse_scope() {
  SCOPE=local
  while [ $# -gt 0 ]; do
    case "$1" in
      --scope)
        [ $# -ge 2 ] || usage
        SCOPE="$2"
        shift 2
        ;;
      --scope=*) SCOPE="${1#--scope=}"; shift ;;
      *) usage ;;
    esac
  done
  case "$SCOPE" in
    local | project | user) ;;
    *) printf 'invalid scope: %s\n' "$SCOPE" >&2; exit 2 ;;
  esac
}

# Prints the entry as JSON with $HOME expanded in every string value.
entry_json() {
  python3 -I -c '
import json, sys
home, entry = sys.argv[1], json.load(open(sys.argv[2]))[sys.argv[3]]
def expand(v):
    if isinstance(v, str):
        return v.replace("$HOME", home)
    if isinstance(v, list):
        return [expand(x) for x in v]
    if isinstance(v, dict):
        return {k: expand(x) for k, x in v.items()}
    return v
print(json.dumps(expand(entry)))
' "$HOME" "$CONFIG" "$1"
}

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  list)
    names | while IFS= read -r name; do
      if claude mcp get "$name" >/dev/null 2>&1 </dev/null; then
        state=registered
      else
        state=not-registered
      fi
      printf '%s\t%s\n' "$name" "$state"
    done
    ;;
  on)
    [ $# -ge 1 ] || usage
    name="$1"
    shift
    check_name "$name"
    parse_scope "$@"
    claude mcp add-json --scope "$SCOPE" "$name" "$(entry_json "$name")"
    ;;
  off)
    [ $# -ge 1 ] || usage
    name="$1"
    shift
    check_name "$name"
    parse_scope "$@"
    claude mcp remove --scope "$SCOPE" "$name"
    ;;
  *) usage ;;
esac
