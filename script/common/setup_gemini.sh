#!/bin/bash
# Gemini CLI 全域設定 symlink 建立腳本
# 將 dotfile/config/ai/gemini/ 下的設定 symlink 回 ~/.gemini/
# 安裝 shared-core skills + Gemini native skills/policies，避免整包混入 Claude runtime skills

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEMINI_SRC="$DOTFILE_DIR/config/ai/gemini"
GEMINI_DST="$HOME/.gemini"
SHARED_RULES_SRC="$DOTFILE_DIR/config/ai/AGENTS.md"
PERSONAL_MODEL_SRC="${PERSONAL_MODEL_SRC:-$DOTFILE_DIR/../Project/AI/agent-workspace/personal-model/PROFILE.md}"
ACTIVE_RULES_DIR="$DOTFILE_DIR/config/ai/generated/gemini"
ACTIVE_RULES_SRC="$ACTIVE_RULES_DIR/GEMINI.md"
SHARED_SKILL_SRC="$DOTFILE_DIR/config/ai/shared/skills"
GEMINI_SKILL_SRC="$DOTFILE_DIR/config/ai/gemini/skills"
GEMINI_POLICIES_SRC="$DOTFILE_DIR/config/ai/gemini/policies"

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
  knowledge-base-router
)

should_install_gemini_skill() {
  local name="$1"

  case "$name" in
    ask-tty)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
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
    cat "$GEMINI_SRC/GEMINI.md"
    printf '\n%s\n' '<!-- runtime-adapter:end -->'
  } > "$tmp_file"
  mv "$tmp_file" "$ACTIVE_RULES_SRC"
}

printf "${Y}=== Gemini CLI 設定 Symlink ===${N}\n"

mkdir -p "$GEMINI_DST" "$GEMINI_DST/skills"

compose_active_rules
link_item "$ACTIVE_RULES_SRC" "$GEMINI_DST/GEMINI.md" "GEMINI.md"
link_item "$SHARED_RULES_SRC" "$GEMINI_DST/AGENTS.shared.md" "shared agent contract"
link_item "$GEMINI_POLICIES_SRC" "$GEMINI_DST/policies" "policies"

printf "\n${Y}--- Shared Core Skills ---${N}\n"
for name in "${SHARED_CORE_SKILLS[@]}"; do
  if [ -f "$SHARED_SKILL_SRC/$name/SKILL.md" ]; then
    link_item "$SHARED_SKILL_SRC/$name" "$GEMINI_DST/skills/$name" "skills/$name"
  fi
done

if [ -d "$GEMINI_SKILL_SRC" ]; then
  printf "\n${Y}--- Gemini Native Skills ---${N}\n"
  for skill_dir in "$GEMINI_SKILL_SRC"/*/; do
    name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ] && should_install_gemini_skill "$name"; then
      link_item "$skill_dir" "$GEMINI_DST/skills/$name" "skills/$name"
    fi
  done
fi

printf "${G}=== 完成 ===${N}\n"
