#!/bin/bash
# Global Lesson — 追加經驗教訓
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/lesson.sh <category> <key> <desc>
#       bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/lesson.sh --help
# 範例: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/lesson.sh typescript import "ESM requires .js extension even for .ts files"

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/lesson.sh <category> <key> <desc>"
  echo ""
  echo "追加經驗教訓到 .ai/lessons.md（分類 + key 去重）"
  echo ""
  echo "Example: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/lesson.sh typescript import \"ESM requires .js extension\""
  exit 0
fi

CAT="$1"
KEY="$2"
DESC="$3"

if [ -z "$CAT" ] || [ -z "$KEY" ] || [ -z "$DESC" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/lesson.sh <category> <key> <desc>"
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
LESSONS="$AI_DIR/lessons.md"

mkdir -p "$AI_DIR"

if [ ! -f "$LESSONS" ]; then
  echo "# Lessons Learned" > "$LESSONS"
fi

TODAY=$(date '+%Y-%m-%d')

# 確保 category 區段存在
if ! grep -q "^## ${CAT}$" "$LESSONS"; then
  echo "" >> "$LESSONS"
  echo "## ${CAT}" >> "$LESSONS"
fi

ENTRY="- ${TODAY} | [${KEY}] ${DESC}"

# 防止重複（用 key 比對）
if grep -q "\[${KEY}\]" "$LESSONS" 2>/dev/null; then
  echo "Lesson key [${KEY}] already exists. Skipping."
  exit 0
fi

# 插入到正確的 category 之下
# 找到 category 行號，在其後追加
CAT_LINE=$(grep -n "^## ${CAT}$" "$LESSONS" | tail -1 | cut -d: -f1)
if [ -n "$CAT_LINE" ]; then
  # 找下一個 ## 或文件末尾
  NEXT_CAT=$(tail -n +"$((CAT_LINE + 1))" "$LESSONS" | grep -n "^## " | head -1 | cut -d: -f1)
  if [ -n "$NEXT_CAT" ]; then
    INSERT_AT=$((CAT_LINE + NEXT_CAT - 1))
    # macOS/Linux sed -i 相容
    if [[ "$OSTYPE" == darwin* ]]; then
      sed -i '' "${INSERT_AT}i\\
${ENTRY}" "$LESSONS"
    else
      sed -i "${INSERT_AT}i\\${ENTRY}" "$LESSONS"
    fi
  else
    echo "$ENTRY" >> "$LESSONS"
  fi
else
  echo "$ENTRY" >> "$LESSONS"
fi

echo "Lesson added: $ENTRY"
