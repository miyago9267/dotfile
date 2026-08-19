#!/bin/bash
# Install repository-managed Grok persona and runtime launchers.

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GROK_SRC="$DOTFILE_DIR/config/ai/grok/AGENTS.md"
SHARED_RULES_SRC="$DOTFILE_DIR/config/ai/AGENTS.md"
PERSONAL_MODEL_SRC="${PERSONAL_MODEL_SRC:-$DOTFILE_DIR/../Project/AI/agent-workspace/personal-model/PROFILE.md}"
ACTIVE_RULES_DIR="$DOTFILE_DIR/config/ai/generated/grok"
ACTIVE_RULES_SRC="$ACTIVE_RULES_DIR/AGENTS.md"
GROK_BIN_SRC="$DOTFILE_DIR/config/ai/grok/bin"
GROK_HOME_DIR="${GROK_HOME:-$HOME/.grok}"
GROK_DST="$GROK_HOME_DIR/AGENTS.md"
SHARED_RULES_DST="$GROK_HOME_DIR/AGENTS.shared.md"
LEGACY_SHARED_DST="$GROK_HOME_DIR/AGENT_RULES_SHARED.md"
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

if [ ! -f "$SHARED_RULES_SRC" ]; then
  printf '%s\n' "Shared agent contract not found: $SHARED_RULES_SRC" >&2
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

compose_active_rules() {
  mkdir -p "$ACTIVE_RULES_DIR"
  local tmp_file="$ACTIVE_RULES_SRC.tmp.$$"
  {
    cat "$SHARED_RULES_SRC"
    printf '\n\n<!-- miyago-personal-model:begin -->\n\n'
    if [ -f "$PERSONAL_MODEL_SRC" ]; then
      awk 'NR == 1 && $0 == "---" { frontmatter = 1; next } frontmatter && $0 == "---" { frontmatter = 0; next } !frontmatter { print }' "$PERSONAL_MODEL_SRC"
    else
      printf '%s\n' 'Personal Model unavailable; use shared contract only.' >&2
    fi
    printf '\n<!-- miyago-personal-model:end -->\n\n'
    printf '%s\n\n' '<!-- runtime-adapter:begin -->'
    cat "$GROK_SRC"
    printf '\n%s\n' '<!-- runtime-adapter:end -->'
  } > "$tmp_file"
  mv "$tmp_file" "$ACTIVE_RULES_SRC"
}

mkdir -p "$GROK_HOME_DIR" "$LOCAL_BIN" "$GROK_HOME_DIR/skills" "$GROK_HOME_DIR/memory"
compose_active_rules
link_managed "$ACTIVE_RULES_SRC" "$GROK_DST"
link_managed "$SHARED_RULES_SRC" "$SHARED_RULES_DST"
link_managed "$KB_ROUTER_SRC" "$KB_ROUTER_DST"

if [ -L "$LEGACY_SHARED_DST" ] && [ "$(readlink "$LEGACY_SHARED_DST")" = "$DOTFILE_DIR/config/ai/codex/AGENT_RULES_SHARED.md" ]; then
  if [ -e "${LEGACY_SHARED_DST}.legacy" ] || [ -L "${LEGACY_SHARED_DST}.legacy" ]; then
    printf '%s\n' '[SKIP] legacy shared contract backup already exists'
  else
    mv "$LEGACY_SHARED_DST" "${LEGACY_SHARED_DST}.legacy"
    printf '%s\n' '[BACKUP] legacy Codex-owned shared contract link'
  fi
fi
link_managed "$SHARED_MEMORY_SRC" "$GROK_MEMORY_DST"
enable_memory

for launcher in grok-native grok-compat; do
  link_managed "$GROK_BIN_SRC/$launcher" "$LOCAL_BIN/$launcher"
done

printf '%s\n' "Grok native and compatibility launchers installed."
