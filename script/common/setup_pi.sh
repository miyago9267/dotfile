#!/bin/bash
# Pi 全域設定 symlink 建立腳本
# 將 canonical shared contract、Pi adapter、safe settings 與 shared-core skills
# 接到 ~/.pi/agent/；保留 auth、sessions、model catalog 與既有 extensions。

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PI_SRC="$DOTFILE_DIR/config/ai/pi"
PI_DST="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
SHARED_RULES_SRC="$DOTFILE_DIR/config/ai/AGENTS.md"
PERSONAL_MODEL_SRC="${PERSONAL_MODEL_SRC:-$DOTFILE_DIR/../Project/AI/agent-workspace/personal-model/PROFILE.md}"
SHARED_SKILL_SRC="$DOTFILE_DIR/config/ai/shared/skills"
ACTIVE_RULES_DIR="$DOTFILE_DIR/config/ai/generated/pi"
ACTIVE_RULES_SRC="$ACTIVE_RULES_DIR/AGENTS.md"

Y='\033[1;33m'
G='\033[1;32m'
R='\033[1;31m'
N='\033[0m'

SHARED_CORE_SKILLS=(
  final-state-publication
  knowledge-base-router
  community-tech-brief
)

link_managed() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -e "$src" ]; then
    printf "${R}[SKIP] %s -- source missing: %s${N}\n" "$label" "$src"
    return
  fi

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf "${G}[OK]   %s${N}\n" "$label"
    return
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$dst" "$backup"
    printf "${Y}[BAK]  %s -> %s${N}\n" "$label" "$backup"
  elif [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  ln -s "$src" "$dst"
  printf "${G}[LINK] %s${N}\n" "$label"
}

compose_active_rules() {
  mkdir -p "$ACTIVE_RULES_DIR"
  local tmp_file="$ACTIVE_RULES_SRC.tmp.$$"
  {
    printf '%s\n\n' '<!-- markdownlint-disable MD012 MD013 MD025 -->'
    cat "$SHARED_RULES_SRC"
    printf '\n\n<!-- miyago-personal-model:begin -->\n\n'
    if [ -f "$PERSONAL_MODEL_SRC" ]; then
      awk 'NR == 1 && $0 == "---" { frontmatter = 1; next } frontmatter && $0 == "---" { frontmatter = 0; next } !frontmatter { print }' "$PERSONAL_MODEL_SRC"
    else
      printf '%s\n' 'Personal Model unavailable; use shared contract only.' >&2
    fi
    printf '\n<!-- miyago-personal-model:end -->\n\n'
    printf '%s\n\n' '<!-- runtime-adapter:begin -->'
    cat "$PI_SRC/AGENTS.md"
    printf '\n%s\n' '<!-- runtime-adapter:end -->'
    printf '\n%s\n' '<!-- markdownlint-enable MD012 MD013 MD025 -->'
  } > "$tmp_file"
  mv "$tmp_file" "$ACTIVE_RULES_SRC"
}

if [ ! -f "$SHARED_RULES_SRC" ] || [ ! -f "$PI_SRC/AGENTS.md" ] || [ ! -f "$PI_SRC/settings.json" ]; then
  printf '%s\n' 'Pi configuration source is incomplete.' >&2
  exit 1
fi

printf "${Y}=== Pi 設定 Symlink ===${N}\n"

mkdir -p "$PI_DST" "$PI_DST/skills"
compose_active_rules
link_managed "$ACTIVE_RULES_SRC" "$PI_DST/AGENTS.md" "AGENTS.md"
link_managed "$SHARED_RULES_SRC" "$PI_DST/AGENTS.shared.md" "shared agent contract"
link_managed "$PI_SRC/settings.json" "$PI_DST/settings.json" "settings.json"

printf "\n${Y}--- Shared Core Skills ---${N}\n"
for name in "${SHARED_CORE_SKILLS[@]}"; do
  if [ -f "$SHARED_SKILL_SRC/$name/SKILL.md" ]; then
    link_managed "$SHARED_SKILL_SRC/$name" "$PI_DST/skills/$name" "skills/$name"
  else
    printf "${R}[SKIP] skills/%s -- source missing${N}\n" "$name"
  fi
done

# Remove only Pi-managed links that target the shared skill source and are no longer allowed.
for skill_path in "$PI_DST/skills"/*; do
  [ -L "$skill_path" ] || continue
  target="$(readlink "$skill_path")"
  case "$target" in
    "$SHARED_SKILL_SRC/"*)
      skill_name="$(basename "$skill_path")"
      keep=false
      for allowed in "${SHARED_CORE_SKILLS[@]}"; do
        [ "$skill_name" = "$allowed" ] && keep=true
      done
      [ "$keep" = true ] || rm -f "$skill_path"
      ;;
  esac
done

printf "${G}=== 完成 ===${N}\n"
