#!/usr/bin/env bash

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$repo_root" ] && exit 0

repo_name=$(basename "$repo_root")
branch=$(git -C "$repo_root" branch --show-current 2>/dev/null)
project_map=""

for candidate in "$repo_root/.ai/PROJECT.md" "$repo_root/.claude/PROJECT.md" "$repo_root/docs/ai/PROJECT.md"; do
  if [ -f "$candidate" ]; then
    project_map="$candidate"
    break
  fi
done

if [ -n "$project_map" ]; then
  printf 'Repo context: %s @ %s. Project map: %s\n' "$repo_name" "${branch:-detached}" "$project_map"
else
  printf 'Repo context: %s @ %s. Read repo AGENTS.md before editing if present.\n' "$repo_name" "${branch:-detached}"
fi
