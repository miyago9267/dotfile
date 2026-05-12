#!/bin/bash
# Global End Session — 收工 pipeline
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/end-session.sh [--model X] [--pending "..."] [--decisions "..."]
#       bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/end-session.sh --help
# 產生 session summary，合併 CURRENT -> HANDOFF，歸檔 completed specs

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/end-session.sh [--model X] [--pending \"...\"] [--decisions \"...\"]"
  echo ""
  echo "收工 pipeline: CURRENT -> HANDOFF 合併 + session summary + auto-archive"
  echo ""
  echo "Options:"
  echo "  --model X         使用的模型名稱"
  echo "  --pending \"...\"   待辦事項（分號分隔）"
  echo "  --decisions \"...\" 本次決策（分號分隔）"
  echo "  --help            顯示此說明"
  exit 0
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
LEGACY_AI_DIR="$PROJECT_ROOT/docs/ai"
SPECS_DIR="$PROJECT_ROOT/docs/specs"
SESSION_DIR="$AI_DIR/sessions"
TODAY=$(date '+%Y-%m-%d')
SESSION_FILE="$SESSION_DIR/${TODAY}.md"
CURRENT_FILE="$AI_DIR/CURRENT.md"
HANDOFF_FILE="$AI_DIR/HANDOFF.md"

MODEL=""
PENDING=""
DECISIONS=""

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --pending) PENDING="$2"; shift 2 ;;
    --decisions) DECISIONS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

mkdir -p "$SESSION_DIR"

# ─── CURRENT -> HANDOFF 合併 ─────────────────────
if [ -f "$CURRENT_FILE" ]; then
  CURRENT_CONTENT=$(cat "$CURRENT_FILE" 2>/dev/null || true)
  # 只有非空內容（去掉 HTML 註解和空行後）才合併
  STRIPPED=$(echo "$CURRENT_CONTENT" | grep -v '^<!--' | grep -v '^$' | grep -v '^# Current Session' || true)
  if [ -n "$STRIPPED" ]; then
    {
      echo "# Handoff"
      echo ""
      echo "## 上次 session ($TODAY)"
      echo ""
      echo "$STRIPPED"
      echo ""
      if [ -n "$PENDING" ]; then
        echo "## 待辦"
        echo ""
        echo "$PENDING" | tr ';' '\n' | while read -r item; do
          item=$(echo "$item" | sed 's/^ *//')
          [ -n "$item" ] && echo "- $item"
        done
        echo ""
      fi
      if [ -n "$DECISIONS" ]; then
        echo "## 決策"
        echo ""
        echo "$DECISIONS" | tr ';' '\n' | while read -r item; do
          item=$(echo "$item" | sed 's/^ *//')
          [ -n "$item" ] && echo "- $item"
        done
        echo ""
      fi
    } > "$HANDOFF_FILE"
    echo "HANDOFF updated from CURRENT"
  fi

  # 清空 CURRENT.md
  cat > "$CURRENT_FILE" << 'CURRENTEOF'
# Current Session

<!-- 由 AI 自動更新，記錄當前 session 正在做什麼 -->
<!-- end-session.sh 會將此內容合併到 HANDOFF.md 後清空 -->
CURRENTEOF
  echo "CURRENT.md cleared"
fi

# ─── Gather info ─────────────────────────────────
BRANCH=$(git branch --show-current 2>/dev/null || echo "N/A")
[ -z "$MODEL" ] && MODEL="unknown"

# Git changes today
CHANGED_FILES=""
if git log --oneline --since="$TODAY" --name-only 2>/dev/null | grep -v '^[a-f0-9]' | sort -u > /tmp/changed_files_$$ 2>/dev/null; then
  CHANGED_FILES=$(cat /tmp/changed_files_$$)
  rm -f /tmp/changed_files_$$
fi

# Today's changelog entries (check both .ai/ and legacy docs/ai/)
TODAYS_LOG=""
CHANGELOG_FILE=""
if [ -f "$AI_DIR/changelog.md" ]; then
  CHANGELOG_FILE="$AI_DIR/changelog.md"
elif [ -f "$LEGACY_AI_DIR/changelog.md" ]; then
  CHANGELOG_FILE="$LEGACY_AI_DIR/changelog.md"
fi

if [ -n "$CHANGELOG_FILE" ]; then
  TODAYS_LOG=$(awk "/^## ${TODAY}/{found=1; next} /^## [0-9]/{found=0} found{print}" "$CHANGELOG_FILE")
fi

# ─── Write session file ─────────────────────────
{
  echo "model: $MODEL"
  echo "branch: $BRANCH"
  echo "date: $TODAY"
  echo ""

  echo "## done"
  if [ -n "$TODAYS_LOG" ]; then
    echo "$TODAYS_LOG"
  else
    echo "- (no changelog entries today)"
  fi
  echo ""

  echo "## pending"
  if [ -n "$PENDING" ]; then
    echo "$PENDING" | tr ';' '\n' | while read -r item; do
      item=$(echo "$item" | sed 's/^ *//')
      [ -n "$item" ] && echo "- $item"
    done
  else
    echo "- (none)"
  fi
  echo ""

  echo "## decisions"
  if [ -n "$DECISIONS" ]; then
    echo "$DECISIONS" | tr ';' '\n' | while read -r item; do
      item=$(echo "$item" | sed 's/^ *//')
      [ -n "$item" ] && echo "- $item"
    done
  else
    echo "- (none)"
  fi
  echo ""

  echo "## files_changed"
  if [ -n "$CHANGED_FILES" ]; then
    echo "$CHANGED_FILES" | while read -r f; do
      [ -n "$f" ] && echo "- $f"
    done
  else
    echo "- (no git commits today)"
  fi
} > "$SESSION_FILE"

echo "Session saved: $SESSION_FILE"

# ─── Auto-archive completed specs ────────────────
if [ -d "$SPECS_DIR" ]; then
  ARCHIVE_DIR="$SPECS_DIR/archive"
  for spec in "$SPECS_DIR"/*/SPEC.md; do
    [ -f "$spec" ] || continue
    SLUG=$(basename "$(dirname "$spec")")
    [ "$SLUG" = "archive" ] && continue
    [ "$SLUG" = "_templates" ] && continue

    STATUS=$(grep -m1 '^status:' "$spec" 2>/dev/null | sed 's/status: *//')
    if [ "$STATUS" = "completed" ]; then
      mkdir -p "$ARCHIVE_DIR"
      mv "$(dirname "$spec")" "$ARCHIVE_DIR/"
      echo "Archived completed spec: $SLUG"
    fi
  done
fi

echo "=== Session Ended ==="
