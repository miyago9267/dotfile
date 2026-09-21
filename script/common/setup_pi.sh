#!/bin/bash
# Pi 全域設定安裝腳本
# 將 canonical shared contract、Pi adapter、safe settings defaults 與 shared-core
# skills 接到 ~/.pi/agent/；保留 auth、sessions、model catalog 與既有 extensions。

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PI_SRC="$DOTFILE_DIR/config/ai/pi"
PI_DST="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PI_EXTENSION_SRC="$DOTFILE_DIR/config/ai/pi/extensions/jev-compaction-shadow.ts"
PI_EXTENSION_DST="$PI_DST/extensions/jev-compaction-shadow.ts"
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
  jev-tools
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

sync_runtime_settings() {
  local dst="$PI_DST/settings.json"
  local tmp_file="$PI_DST/.settings.json.tmp.$$"
  local existing_kind="missing"

  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" != "$PI_SRC/settings.json" ]; then
      printf "${R}[SKIP] settings.json -- unmanaged symlink: %s${N}\n" "$dst" >&2
      return 1
    fi
    existing_kind="managed-link"
  elif [ -e "$dst" ]; then
    existing_kind="regular"
  fi

  if command -v jq >/dev/null 2>&1; then
    if [ "$existing_kind" = "missing" ]; then
      jq '.' "$PI_SRC/settings.json" > "$tmp_file"
    elif jq -e 'type == "object"' "$dst" >/dev/null 2>&1; then
      jq -s '
        .[0] as $defaults |
        .[1] as $runtime |
        ($defaults * $runtime) |
        if ($defaults | has("skills")) then .skills = $defaults.skills else . end
      ' "$PI_SRC/settings.json" "$dst" > "$tmp_file"
    else
      rm -f "$tmp_file"
      printf "${R}[SKIP] settings.json -- existing file is not a JSON object${N}\n" >&2
      return 1
    fi
  elif [ "$existing_kind" = "regular" ]; then
    printf "${Y}[KEEP] settings.json -- jq unavailable; existing runtime settings preserved${N}\n" >&2
    return 0
  else
    cp "$PI_SRC/settings.json" "$tmp_file"
  fi

  [ "$existing_kind" = "managed-link" ] && rm -f "$dst"
  mv "$tmp_file" "$dst"
  chmod 644 "$dst"
  printf "${G}[SYNC] settings.json -- mutable runtime copy${N}\n"
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

printf "${Y}=== Pi 設定 ===${N}\n"

mkdir -p "$PI_DST" "$PI_DST/skills" "$PI_DST/extensions"
compose_active_rules
link_managed "$ACTIVE_RULES_SRC" "$PI_DST/AGENTS.md" "AGENTS.md"
link_managed "$SHARED_RULES_SRC" "$PI_DST/AGENTS.shared.md" "shared agent contract"
sync_runtime_settings
link_managed "$PI_EXTENSION_SRC" "$PI_EXTENSION_DST" "extensions/jev-compaction-shadow.ts"

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
