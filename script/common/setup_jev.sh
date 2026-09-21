#!/bin/bash

# Register the shared Jev toolbox with Claude Code, Codex, and AGY.
# Default is dry-run; --apply mutates user-level MCP registries.
set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JEv_DIR="$DOTFILE_DIR/config/ai/shared/jev"
JEv_BROWSER="$JEv_DIR/jev-browser-mcp.sh"
RETICLE="$JEv_DIR/reticle-mcp.sh"
MODE="dry-run"

if [ "${1:-}" = "--apply" ]; then
  MODE="apply"
elif [ "${1:-}" != "--dry-run" ] && [ "${1:-}" != "" ]; then
  printf 'usage: %s [--dry-run|--apply]\n' "$0" >&2
  exit 2
fi

for path in "$JEv_BROWSER" "$RETICLE"; do
  [ -x "$path" ] || {
    printf 'adapter is not executable: %s\n' "$path" >&2
    exit 1
  }
done

printf 'mode=%s\n' "$MODE"
printf 'jev-browser: %s\n' "$JEv_BROWSER"
printf 'reticle: %s\n' "$RETICLE"
printf 'TYPESAFE_API_KEY: %s\n' "${TYPESAFE_API_KEY:+inherited}"

if [ "$MODE" = "dry-run" ]; then
  printf '%s\n' 'would register Claude, Codex, and AGY user-level MCP servers'
  printf '%s\n' 'would leave Pi on CLI/library skill path'
  exit 0
fi

command -v claude >/dev/null 2>&1 || {
  printf '%s\n' 'skip Claude: claude command not found' >&2
}
if command -v claude >/dev/null 2>&1; then
  claude mcp remove jev-browser >/dev/null 2>&1 || true
  claude mcp remove reticle >/dev/null 2>&1 || true
  claude mcp add --scope user jev-browser -- "$JEv_BROWSER"
  claude mcp add --scope user reticle -- "$RETICLE"
fi

command -v codex >/dev/null 2>&1 || {
  printf '%s\n' 'skip Codex: codex command not found' >&2
}
if command -v codex >/dev/null 2>&1; then
  codex mcp remove jev-browser >/dev/null 2>&1 || true
  codex mcp remove reticle >/dev/null 2>&1 || true
  codex mcp add jev-browser -- "$JEv_BROWSER"
  codex mcp add reticle -- "$RETICLE"
fi

command -v agy >/dev/null 2>&1 || {
  printf '%s\n' 'skip AGY: agy command not found' >&2
}
if command -v agy >/dev/null 2>&1; then
  agy mcp add jev-browser "$JEv_BROWSER"
  agy mcp add reticle "$RETICLE"
fi

printf '%s\n' 'registered Claude/Codex/AGY MCP entries; Pi uses config/ai/shared/jev/pi-jev-tools.md'
