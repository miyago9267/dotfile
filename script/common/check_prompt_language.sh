#!/bin/bash
# Check that active first-party prompt prose contains Traditional Chinese.

set -euo pipefail

dotfile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ai_dir="$dotfile_dir/config/ai"
failures=0
checked=0

is_excluded() {
  case "$1" in
    "$ai_dir/generated/"*|\
    "$ai_dir/claude-plugin/"*|\
    "$ai_dir/codex-plugin/"*|\
    "$ai_dir/codex/coralline/"*|\
    "$ai_dir/claude/mcp/"*|\
    "$ai_dir/claude/coralline/"*|\
    "$ai_dir/gemini/skills/"*/references/*|\
    "$ai_dir/memories/extensions/skysight/resources/"*|\
    "$ai_dir/claude/skills/learned/"*|\
    "$ai_dir/grok/README.md"|\
    *before*|*\.legacy|*\.bak.*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_file() {
  local file="$1"
  checked=$((checked + 1))
  if ! grep -Eq '[一-龜]' "$file"; then
    printf '%s\n' "Traditional Chinese prose missing: ${file#$dotfile_dir/}" >&2
    failures=$((failures + 1))
  fi
}

while IFS= read -r file; do
  if ! is_excluded "$file"; then
    check_file "$file"
  fi
done < <(find "$ai_dir" -type f -name '*.md' -print | sort)

policy_file="$ai_dir/gemini/policies/custom-rules.toml"
if [ -f "$policy_file" ]; then
  check_file "$policy_file"
fi

if [ "$failures" -ne 0 ]; then
  printf '%s\n' "prompt language: FAIL (${failures}/${checked} files)" >&2
  exit 1
fi

printf '%s\n' "prompt language: OK (${checked} files)"
