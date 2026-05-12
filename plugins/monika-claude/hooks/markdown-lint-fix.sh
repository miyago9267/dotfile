#!/usr/bin/env bash
# PostToolUse hook: markdown lint auto-fix
# Write/Edit 後對 .md 檔案跑 markdownlint-cli2 --fix
set -euo pipefail

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
[[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]] || exit 0

FILE_PATH="${CLAUDE_FILE_PATH:-}"
[[ -n "$FILE_PATH" && -f "$FILE_PATH" ]] || exit 0
[[ "$FILE_PATH" == *.md ]] || exit 0

if command -v markdownlint-cli2 &>/dev/null; then
  markdownlint-cli2 --fix "$FILE_PATH" 2>/dev/null || true
elif command -v markdownlint &>/dev/null; then
  markdownlint --fix "$FILE_PATH" 2>/dev/null || true
elif command -v npx &>/dev/null; then
  npx --yes markdownlint-cli2 --fix "$FILE_PATH" 2>/dev/null || true
fi
