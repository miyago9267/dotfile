#!/bin/bash
# Gemini CLI 全域設定 symlink 建立腳本
# 將 dotfile/config/ai/gemini/ 下的設定 symlink 回 ~/.gemini/
# 並將 dotfile/config/ai/claude/skills/ 下的 skill symlink 至 ~/.gemini/skills/

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEMINI_SRC="$DOTFILE_DIR/config/ai/gemini"
GEMINI_DST="$HOME/.gemini"
SKILL_SRC="$DOTFILE_DIR/config/ai/claude/skills"
GEMINI_SKILL_SRC="$DOTFILE_DIR/config/ai/gemini/skills"

Y='\033[1;33m'
G='\033[1;32m'
R='\033[1;31m'
N='\033[0m'

link_item() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -e "$src" ]; then
    printf "${R}  [SKIP] %s -- source missing${N}\n" "$label"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf "${G}  [OK]   %s${N}\n" "$label"
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
  printf "${G}  [LINK] %s${N}\n" "$label"
}

printf "${Y}=== Gemini CLI 設定 Symlink ===${N}\n"

mkdir -p "$GEMINI_DST" "$GEMINI_DST/skills"

link_item "$GEMINI_SRC/GEMINI.md" "$GEMINI_DST/GEMINI.md" "GEMINI.md"

printf "\n${Y}--- Claude Global Skills ---${N}\n"
for skill_dir in "$SKILL_SRC"/*/; do
  name=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    link_item "$skill_dir" "$GEMINI_DST/skills/$name" "skills/$name"
  fi
done

if [ -d "$GEMINI_SKILL_SRC" ]; then
  printf "\n${Y}--- Gemini Native Skills ---${N}\n"
  for skill_dir in "$GEMINI_SKILL_SRC"/*/; do
    name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      link_item "$skill_dir" "$GEMINI_DST/skills/$name" "skills/$name"
    fi
  done
fi

printf "${G}=== 完成 ===${N}\n"
