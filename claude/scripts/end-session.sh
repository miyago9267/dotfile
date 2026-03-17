#!/bin/bash
# Global End Session — 收工 pipeline
# 用法: bash ~/.claude/scripts/end-session.sh [--model X] [--pending "..."] [--decisions "..."]
# 產生 session summary，歸檔 completed specs

set -e

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/docs/ai"
SPECS_DIR="$PROJECT_ROOT/docs/specs"
SESSION_DIR="$AI_DIR/sessions"
TODAY=$(date '+%Y-%m-%d')
SESSION_FILE="$SESSION_DIR/${TODAY}.md"

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

# ─── Gather info ─────────────────────────────────
BRANCH=$(git branch --show-current 2>/dev/null || echo "N/A")
[ -z "$MODEL" ] && MODEL="unknown"

# Git changes today
CHANGED_FILES=""
if git log --oneline --since="$TODAY" --name-only 2>/dev/null | grep -v '^[a-f0-9]' | sort -u > /tmp/changed_files_$$ 2>/dev/null; then
  CHANGED_FILES=$(cat /tmp/changed_files_$$)
  rm -f /tmp/changed_files_$$
fi

# Today's changelog entries
TODAYS_LOG=""
if [ -f "$AI_DIR/changelog.md" ]; then
  # Extract entries under today's date header
  # Use awk to handle single-section case (no next ## to terminate range)
  TODAYS_LOG=$(awk "/^## ${TODAY}/{found=1; next} /^## [0-9]/{found=0} found{print}" "$AI_DIR/changelog.md")
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

    STATUS=$(grep -m1 '^status:' "$spec" 2>/dev/null | sed 's/status: *//')
    if [ "$STATUS" = "completed" ]; then
      mkdir -p "$ARCHIVE_DIR"
      mv "$(dirname "$spec")" "$ARCHIVE_DIR/"
      echo "Archived completed spec: $SLUG"
    fi
  done
fi

echo "=== Session Ended ==="
