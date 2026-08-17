#!/bin/bash
# Install repository-managed Grok persona and runtime launchers.

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GROK_SRC="$DOTFILE_DIR/config/ai/grok/AGENTS.md"
CODEX_SHARED_SRC="$DOTFILE_DIR/config/ai/codex/AGENT_RULES_SHARED.md"
GROK_BIN_SRC="$DOTFILE_DIR/config/ai/grok/bin"
GROK_HOME_DIR="${GROK_HOME:-$HOME/.grok}"
GROK_DST="$GROK_HOME_DIR/AGENTS.md"
CODEX_SHARED_DST="$GROK_HOME_DIR/AGENT_RULES_SHARED.md"
SHARED_MEMORY_SRC="$DOTFILE_DIR/config/ai/memories/MEMORY.md"
KB_ROUTER_SRC="$DOTFILE_DIR/config/ai/shared/skills/knowledge-base-router"
KB_ROUTER_DST="$GROK_HOME_DIR/skills/knowledge-base-router"
GROK_MEMORY_DST="$GROK_HOME_DIR/memory/MEMORY.md"
GROK_CONFIG="$GROK_HOME_DIR/config.toml"
LOCAL_BIN="$HOME/.local/bin"

if [ ! -f "$GROK_SRC" ]; then
  printf '%s\n' "Grok adapter source not found: $GROK_SRC" >&2
  exit 1
fi

if [ ! -f "$CODEX_SHARED_SRC" ]; then
  printf '%s\n' "Codex-sourced agent contract not found: $CODEX_SHARED_SRC" >&2
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

enable_memory() {
  if [ ! -f "$GROK_CONFIG" ]; then
    printf '%s\n' '[memory]' 'enabled = true' > "$GROK_CONFIG"
    printf '%s\n' "[CONFIG] enabled Grok memory: $GROK_CONFIG"
    return
  fi

  if grep -Eq '^\[memory\]$' "$GROK_CONFIG"; then
    if awk '/^\[memory\]$/{in_memory=1; next} /^\[/{in_memory=0} in_memory && /^enabled[[:space:]]*=[[:space:]]*true[[:space:]]*$/{found=1} END{exit !found}' "$GROK_CONFIG"; then
      printf '%s\n' "[OK] Grok memory enabled: $GROK_CONFIG"
      return
    fi
    printf '%s\n' "[WARN] Grok memory section exists; review manually: $GROK_CONFIG" >&2
    return
  fi

  local backup
  backup="${GROK_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
  cp -p "$GROK_CONFIG" "$backup"
  local tmp
  tmp="${GROK_CONFIG}.tmp.$RANDOM"
  awk '
    /^\[subagents\]$/ && !inserted {
      print "[memory]"
      print "enabled = true"
      print ""
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        print ""
        print "[memory]"
        print "enabled = true"
      }
    }
  ' "$GROK_CONFIG" > "$tmp"
  mv "$tmp" "$GROK_CONFIG"
  printf '%s\n' "[CONFIG] enabled Grok memory: $GROK_CONFIG (backup: $backup)"
}

mkdir -p "$GROK_HOME_DIR" "$LOCAL_BIN" "$GROK_HOME_DIR/skills" "$GROK_HOME_DIR/memory"
link_managed "$GROK_SRC" "$GROK_DST"
link_managed "$CODEX_SHARED_SRC" "$CODEX_SHARED_DST"
link_managed "$KB_ROUTER_SRC" "$KB_ROUTER_DST"
link_managed "$SHARED_MEMORY_SRC" "$GROK_MEMORY_DST"
enable_memory

for launcher in grok-native grok-compat; do
  link_managed "$GROK_BIN_SRC/$launcher" "$LOCAL_BIN/$launcher"
done

printf '%s\n' "Grok native and compatibility launchers installed."
