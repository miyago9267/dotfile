#!/bin/bash
set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHARED_RULES_SRC="$DOTFILE_DIR/config/ai/AGENTS.md"
ASTRA_SRC="$DOTFILE_DIR/config/ai/astra"
CODEX_SRC="$DOTFILE_DIR/config/ai/codex"
PERSONAL_MODEL_SRC="${PERSONAL_MODEL_SRC:-$DOTFILE_DIR/../Project/AI/agent-workspace/personal-model/PROFILE.md}"
ACTIVE_RULES_DIR="$DOTFILE_DIR/config/ai/generated/astra"
ACTIVE_RULES_SRC="$ACTIVE_RULES_DIR/AGENTS.md"
ALLOWLIST_FILE="$ASTRA_SRC/skills-allowlist.txt"
ASTRA_TARGET_ROOT="${ASTRA_TARGET_ROOT:-}"

resolve_skill_source() {
  local name="$1"
  local candidate

  for candidate in \
    "$ASTRA_SRC/skills/$name" \
    "$CODEX_SRC/skills/$name" \
    "$DOTFILE_DIR/config/ai/shared/skills/$name"; do
    if [ -f "$candidate/SKILL.md" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "missing Astra skill source: $name" >&2
  return 1
}

link_managed() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return 0
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    printf '%s\n' "refusing to overwrite existing file: $dst" >&2
    return 1
  fi
  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi
  ln -s "$src" "$dst"
}

compose_active_rules() {
  local tmp_file="$ACTIVE_RULES_SRC.tmp.$$"

  mkdir -p "$ACTIVE_RULES_DIR"
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
    cat "$CODEX_SRC/AGENTS.md"
    printf '\n%s\n\n' '<!-- runtime-adapter:end -->'
    printf '%s\n\n' '<!-- astra-adapter:begin -->'
    cat "$ASTRA_SRC/AGENTS.md"
    printf '\n%s\n' '<!-- astra-adapter:end -->'
  } > "$tmp_file"
  mv "$tmp_file" "$ACTIVE_RULES_SRC"
}

sync_target() {
  local name
  local source_dir

  [ -n "$ASTRA_TARGET_ROOT" ] || return 0
  mkdir -p "$ASTRA_TARGET_ROOT/skills"
  link_managed "$ACTIVE_RULES_SRC" "$ASTRA_TARGET_ROOT/AGENTS.md"

  while IFS= read -r name || [ -n "$name" ]; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    source_dir="$(resolve_skill_source "$name")"
    link_managed "$source_dir" "$ASTRA_TARGET_ROOT/skills/$name"
  done < "$ALLOWLIST_FILE"
}

compose_active_rules
sync_target
printf '%s\n' "generated: $ACTIVE_RULES_SRC"
if [ -n "$ASTRA_TARGET_ROOT" ]; then
  printf '%s\n' "linked: $ASTRA_TARGET_ROOT"
fi
