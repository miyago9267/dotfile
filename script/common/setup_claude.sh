#!/bin/bash
# Claude Code 全域設定 symlink 建立腳本
# 將 dotfile/config/ai/claude/ 下的設定 symlink 回 ~/.claude/

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_SRC="$DOTFILE_DIR/config/ai/claude"
CLAUDE_DST="$HOME/.claude"
SHARED_RULES_SRC="$DOTFILE_DIR/config/ai/AGENTS.md"
PERSONAL_MODEL_SRC="${PERSONAL_MODEL_SRC:-$DOTFILE_DIR/../Project/AI/agent-workspace/personal-model/PROFILE.md}"
SHARED_RULES_DST="$CLAUDE_DST/AGENTS.md"
ACTIVE_RULES_DIR="$DOTFILE_DIR/config/ai/generated/claude"
ACTIVE_RULES_SRC="$ACTIVE_RULES_DIR/AGENTS.md"
LEGACY_SHARED_DST="$CLAUDE_DST/AGENT_RULES_SHARED.md"
KB_ROUTER_SRC="$DOTFILE_DIR/config/ai/shared/skills/knowledge-base-router"
KB_ROUTER_DST="$CLAUDE_DST/skills/knowledge-base-router"
REMORA_SRC="$CLAUDE_SRC/remora-proxy/remora.config.toml"
REMORA_DST="$HOME/.config/remora-cc/config.toml"

Y='\033[1;33m'
G='\033[1;32m'
R='\033[1;31m'
N='\033[0m'

# 需要 symlink 的項目（檔案與目錄）
ITEMS=(
  "settings.json"
  "CLAUDE.md"
  "loop.md"
  "hooks"
  "commands"
  "scripts"
  "coralline"
  "coralline.conf"
  "agents"
  "rules"
  "skills"
  "templates"
  "memories"
)

link_item() {
  local name="$1"
  local src="$CLAUDE_SRC/$name"
  local dst="$CLAUDE_DST/$name"

  if [ ! -e "$src" ]; then
    printf "${R}  [SKIP] %s -- 來源不存在${N}\n" "$name"
    return
  fi

  # 如果目標已是正確的 symlink，跳過
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf "${G}  [OK]   %s -- 已是正確的 symlink${N}\n" "$name"
    return
  fi

  # 備份原檔（若存在且非 symlink）
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    printf "${Y}  [BAK]  %s -> %s${N}\n" "$name" "$backup"
    mv "$dst" "$backup"
  elif [ -L "$dst" ]; then
    # 移除舊的 symlink
    rm -f "$dst"
  fi

  ln -s "$src" "$dst"
  printf "${G}  [LINK] %s -> %s${N}\n" "$name" "$src"
}

link_external_item() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -e "$src" ]; then
    printf "${R}  [SKIP] %s -- 來源不存在${N}\n" "$label"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf "${G}  [OK]   %s -- 已是正確的 symlink${N}\n" "$label"
    return
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    printf "${Y}  [BAK]  %s -> %s${N}\n" "$label" "$backup"
    mv "$dst" "$backup"
  elif [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  ln -s "$src" "$dst"
  printf "${G}  [LINK] %s -> %s${N}\n" "$label" "$src"
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
    printf '\n<!-- miyago-personal-model:end -->\n'
  } > "$tmp_file"
  mv "$tmp_file" "$ACTIVE_RULES_SRC"
}

printf "${Y}=== Claude Code 設定 Symlink ===${N}\n"

# 確保 ~/.claude 目錄存在
mkdir -p "$CLAUDE_DST"

for item in "${ITEMS[@]}"; do
  link_item "$item"
done

compose_active_rules
link_external_item "$ACTIVE_RULES_SRC" "$SHARED_RULES_DST" "shared agent contract + personal model"
link_external_item "$KB_ROUTER_SRC" "$KB_ROUTER_DST" "knowledge-base-router skill"

if [ -L "$LEGACY_SHARED_DST" ] && [ "$(readlink "$LEGACY_SHARED_DST")" = "$DOTFILE_DIR/config/ai/codex/AGENT_RULES_SHARED.md" ]; then
  if [ -e "${LEGACY_SHARED_DST}.legacy" ] || [ -L "${LEGACY_SHARED_DST}.legacy" ]; then
    printf '%s\n' "[SKIP] legacy shared contract backup already exists"
  else
    mv "$LEGACY_SHARED_DST" "${LEGACY_SHARED_DST}.legacy"
    printf '%s\n' "[BACKUP] legacy Codex-owned shared contract link"
  fi
fi

mkdir -p "$(dirname "$REMORA_DST")"
install -m 600 "$REMORA_SRC" "$REMORA_DST"
printf "${G}  [SYNC] remora-cc/config.toml${N}\n"

printf "${G}=== 完成 ===${N}\n"
