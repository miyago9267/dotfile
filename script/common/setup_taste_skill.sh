#!/usr/bin/env bash
# Link the vendored taste-skill collection into installed agent runtimes.

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASTE_DIR="$DOTFILE_DIR/config/ai/shared/taste-skill"
MANIFEST="$TASTE_DIR/manifest.txt"

if [ ! -f "$MANIFEST" ]; then
  printf 'taste-skill manifest missing: %s\n' "$MANIFEST" >&2
  exit 1
fi

# Claude's global skills directory links back into the repository, so keep
# those links relative and portable. Other runtimes have their own local dirs.
TARGETS=(
  "$DOTFILE_DIR/config/ai/claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.codex/skills"
  "$HOME/.gemini/skills"
  "$HOME/.gemini/config/skills"
  "$HOME/.grok/skills"
  "$HOME/.pi/agent/skills"
  "$HOME/.config/opencode/skills"
  "$HOME/.junie/skills"
  "$HOME/.copilot/skills"
  "$HOME/.openclaw/skills"
  "$HOME/.openclaw/workspace/skills"
  "$HOME/.sepia/skills"
)

linked=0
already=0
skipped=0
while read -r name folder; do
  [ -n "$name" ] || continue
  src="$TASTE_DIR/skills/$folder"
  if [ ! -f "$src/SKILL.md" ]; then
    printf '[ERROR] taste-skill source missing: %s\n' "$src" >&2
    exit 1
  fi

  for target in "${TARGETS[@]}"; do
    # Do not create a runtime that has not been installed on this machine.
    [ -d "$target" ] || continue
    dst="$target/$name"
    link_target="$src"
    if [ "$target" = "$DOTFILE_DIR/config/ai/claude/skills" ]; then
      link_target="../../shared/taste-skill/skills/$folder"
    fi

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$link_target" ]; then
      already=$((already + 1))
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
      printf '[SKIP] existing skill: %s\n' "$dst" >&2
      skipped=$((skipped + 1))
    else
      ln -s "$link_target" "$dst"
      linked=$((linked + 1))
    fi
  done
done < "$MANIFEST"

printf '[OK] taste-skill: %d linked, %d already linked, %d skipped\n' "$linked" "$already" "$skipped"
