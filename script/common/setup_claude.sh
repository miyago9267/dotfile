#!/bin/bash
# Claude Code 全域設定 symlink 建立腳本
# 將 dotfile/claude/ 下的設定 symlink 回 ~/.claude/

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_SRC="$DOTFILE_DIR/claude"
CLAUDE_DST="$HOME/.claude"

Y='\033[1;33m'
G='\033[1;32m'
R='\033[1;31m'
N='\033[0m'

# 需要 symlink 的項目（檔案與目錄）
ITEMS=(
  "settings.json"
  "CLAUDE.md"
  "hooks"
  "commands"
  "scripts"
  "agents"
  "rules"
  "skills"
  "templates"
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

printf "${Y}=== Claude Code 設定 Symlink ===${N}\n"

# 確保 ~/.claude 目錄存在
mkdir -p "$CLAUDE_DST"

for item in "${ITEMS[@]}"; do
  link_item "$item"
done

printf "${G}=== 完成 ===${N}\n"
