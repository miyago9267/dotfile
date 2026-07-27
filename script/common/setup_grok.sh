#!/bin/bash
# Install repository-managed Grok persona and runtime launchers.

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GROK_SRC="$DOTFILE_DIR/config/ai/grok/AGENTS.md"
GROK_BIN_SRC="$DOTFILE_DIR/config/ai/grok/bin"
GROK_HOME_DIR="${GROK_HOME:-$HOME/.grok}"
GROK_DST="$GROK_HOME_DIR/AGENTS.md"
LOCAL_BIN="$HOME/.local/bin"

if [ ! -f "$GROK_SRC" ]; then
  printf '%s\n' "Grok adapter source not found: $GROK_SRC" >&2
  exit 1
fi

for launcher in grok-native grok-compat; do
  if [ ! -f "$GROK_BIN_SRC/$launcher" ]; then
    printf '%s\n' "Grok launcher source not found: $GROK_BIN_SRC/$launcher" >&2
    exit 1
  fi
done

link_managed() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '%s\n' "[OK] $dst"
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local backup
    backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$dst" "$backup"
    printf '%s\n' "[BAK] $dst -> $backup"
  fi

  ln -s "$src" "$dst"
  printf '%s\n' "[LINK] $dst -> $src"
}

mkdir -p "$GROK_HOME_DIR" "$LOCAL_BIN"
link_managed "$GROK_SRC" "$GROK_DST"

for launcher in grok-native grok-compat; do
  link_managed "$GROK_BIN_SRC/$launcher" "$LOCAL_BIN/$launcher"
done

printf '%s\n' "Grok native and compatibility launchers installed."
