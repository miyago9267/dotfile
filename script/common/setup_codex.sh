#!/bin/bash
# Codex CLI 全域設定 symlink 建立腳本
# 將 dotfile/config/ai/codex/ 下的設定 symlink 回 ~/.codex/
# 安裝 shared-core skills + Codex native skills，避免整包混入 Claude runtime skills

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_SRC="$DOTFILE_DIR/config/ai/codex"
CODEX_DST="$HOME/.codex"
SHARED_SKILL_SRC="$DOTFILE_DIR/config/ai/claude/skills"
CODEX_SKILL_SRC="$DOTFILE_DIR/config/ai/codex/skills"

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

SHARED_CORE_SKILLS=(
  ask-discipline
  auto-docs
  auto-spec
  efficiency
  git-workflow
  markdown-lint
  no-ai-attribution
  path-aware
  safe-ops
  sdd
  search-discipline
  tdd
)

printf "${Y}=== Codex CLI 設定 Symlink ===${N}\n"

mkdir -p "$CODEX_DST" "$CODEX_DST/skills"

link_item "$CODEX_SRC/AGENTS.md" "$CODEX_DST/AGENTS.md" "AGENTS.md"

for profile in fast code heavy; do
  link_item "$CODEX_SRC/$profile.config.toml" "$CODEX_DST/$profile.config.toml" "$profile.config.toml"
done

link_item "$CODEX_SRC/coralline" "$CODEX_DST/coralline" "coralline"
link_item "$CODEX_SRC/coralline.conf" "$CODEX_DST/coralline.conf" "coralline.conf"

printf "\n${Y}--- Shared Core Skills ---${N}\n"
for name in "${SHARED_CORE_SKILLS[@]}"; do
  if [ -f "$SHARED_SKILL_SRC/$name/SKILL.md" ]; then
    link_item "$SHARED_SKILL_SRC/$name" "$CODEX_DST/skills/$name" "skills/$name"
  fi
done

if [ -d "$CODEX_SKILL_SRC" ]; then
  printf "\n${Y}--- Codex Native Skills ---${N}\n"
  for skill_dir in "$CODEX_SKILL_SRC"/*/; do
    name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      link_item "$skill_dir" "$CODEX_DST/skills/$name" "skills/$name"
    fi
  done
fi

printf "${G}=== 完成 ===${N}\n"
