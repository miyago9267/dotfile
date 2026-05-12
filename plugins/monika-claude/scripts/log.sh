#!/bin/bash
# Global Log — 追加 changelog 條目
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/log.sh <type> <scope> <path> <desc>
#       bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/log.sh --help
# type: feat/fix/refactor/docs/test/chore
# 範例: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/log.sh feat auth src/auth.ts "add JWT validation"

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/log.sh <type> <scope> <path> <desc>"
  echo ""
  echo "追加 changelog 條目到 .ai/changelog.md"
  echo ""
  echo "Types: feat fix refactor docs test chore"
  echo "Example: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/log.sh feat auth src/auth.ts \"add JWT validation\""
  exit 0
fi

TYPE="$1"
SCOPE="$2"
FILEPATH="$3"
DESC="$4"

if [ -z "$TYPE" ] || [ -z "$SCOPE" ] || [ -z "$FILEPATH" ] || [ -z "$DESC" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/log.sh <type> <scope> <path> <desc>"
  echo "Types: feat fix refactor docs test chore"
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
CHANGELOG="$AI_DIR/changelog.md"

mkdir -p "$AI_DIR"

TODAY=$(date '+%Y-%m-%d')

# 如果 changelog 不存在或今天的日期標題不存在，加上日期
if [ ! -f "$CHANGELOG" ]; then
  echo "# Changelog" > "$CHANGELOG"
  echo "" >> "$CHANGELOG"
fi

if ! grep -q "^## $TODAY" "$CHANGELOG"; then
  echo "" >> "$CHANGELOG"
  echo "## $TODAY" >> "$CHANGELOG"
  echo "" >> "$CHANGELOG"  # MD032: list 前需空行
fi

ENTRY="- ${TYPE}:${SCOPE} | ${FILEPATH} | ${DESC}"

# 防止重複
if grep -qF -- "$ENTRY" "$CHANGELOG" 2>/dev/null; then
  echo "Already logged: $ENTRY"
  exit 0
fi

echo "$ENTRY" >> "$CHANGELOG"
echo "Logged: $ENTRY"
