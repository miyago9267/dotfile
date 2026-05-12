#!/bin/bash
# Global Bootstrap — 新 session 自舉上下文
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/bootstrap.sh [--compact]
#       bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/bootstrap.sh --help
# 適用任何專案，自動偵測 .ai/ 和 docs/specs/ 結構

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/bootstrap.sh [--compact]"
  echo ""
  echo "新 session 自舉，讀取 handoff/changelog/lessons/specs/snapshot"
  echo ""
  echo "Options:"
  echo "  --compact    精簡模式（只讀最近內容）"
  echo "  --help       顯示此說明"
  exit 0
fi

COMPACT=false
if [ "$1" = "--compact" ]; then COMPACT=true; fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
LEGACY_AI_DIR="$PROJECT_ROOT/docs/ai"
SPECS_DIR="$PROJECT_ROOT/docs/specs"
SNAPSHOT_DIR="$AI_DIR/snapshots"

echo "=== Bootstrap: $(basename "$PROJECT_ROOT") ==="
echo "Root: $PROJECT_ROOT"
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
echo "Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

# ─── Handoff（跨 session 交接） ──────────────────
if [ -f "$AI_DIR/HANDOFF.md" ]; then
  echo "--- Handoff ---"
  if [ "$COMPACT" = true ]; then
    head -30 "$AI_DIR/HANDOFF.md"
  else
    cat "$AI_DIR/HANDOFF.md"
  fi
  echo ""
fi

# ─── Changelog (最近 20 行) ─────────────────────
CHANGELOG=""
if [ -f "$AI_DIR/changelog.md" ]; then
  CHANGELOG="$AI_DIR/changelog.md"
elif [ -f "$LEGACY_AI_DIR/changelog.md" ]; then
  CHANGELOG="$LEGACY_AI_DIR/changelog.md"
fi

if [ -n "$CHANGELOG" ]; then
  echo "--- Recent Changes ---"
  tail -30 "$CHANGELOG" | head -20
  echo ""
fi

# ─── Lessons ─────────────────────────────────────
LESSONS=""
if [ -f "$AI_DIR/lessons.md" ]; then
  LESSONS="$AI_DIR/lessons.md"
elif [ -f "$LEGACY_AI_DIR/lessons.md" ]; then
  LESSONS="$LEGACY_AI_DIR/lessons.md"
fi

if [ -n "$LESSONS" ]; then
  LESSON_LINES=$(wc -l < "$LESSONS")
  if [ "$COMPACT" = true ] && [ "$LESSON_LINES" -gt 30 ]; then
    echo "--- Lessons (last 15) ---"
    tail -15 "$LESSONS"
  else
    echo "--- Lessons ---"
    cat "$LESSONS"
  fi
  echo ""
fi

# ─── Latest Session ──────────────────────────────
SESSION_DIR=""
if [ -d "$AI_DIR/sessions" ]; then
  SESSION_DIR="$AI_DIR/sessions"
elif [ -d "$LEGACY_AI_DIR/sessions" ]; then
  SESSION_DIR="$LEGACY_AI_DIR/sessions"
fi

if [ -n "$SESSION_DIR" ]; then
  LATEST=$(ls -1 "$SESSION_DIR/"*.md 2>/dev/null | sort | tail -1)
  if [ -n "$LATEST" ]; then
    echo "--- Last Session: $(basename "$LATEST") ---"
    if [ "$COMPACT" = true ]; then
      head -30 "$LATEST"
    else
      cat "$LATEST"
    fi
    echo ""
  fi
fi

# ─── Active Specs ────────────────────────────────
if [ -d "$SPECS_DIR" ]; then
  echo "--- Active Specs ---"
  for spec in "$SPECS_DIR"/*/SPEC.md; do
    [ -f "$spec" ] || continue
    SLUG=$(basename "$(dirname "$spec")")
    # 跳過 archive 和 _templates
    [ "$SLUG" = "archive" ] && continue
    [ "$SLUG" = "_templates" ] && continue
    STATUS=$(grep -m1 '^status:' "$spec" 2>/dev/null | sed 's/status: *//')
    TITLE=$(grep -m1 '^title:' "$spec" 2>/dev/null | sed 's/title: *//')
    [ -z "$STATUS" ] && STATUS="unknown"
    echo "  [$STATUS] $SLUG: $TITLE"
  done
  echo ""
fi

# ─── PROGRESS.md ─────────────────────────────────
if [ -f "$PROJECT_ROOT/PROGRESS.md" ]; then
  echo "--- Progress ---"
  if [ "$COMPACT" = true ]; then
    head -20 "$PROJECT_ROOT/PROGRESS.md"
  else
    cat "$PROJECT_ROOT/PROGRESS.md"
  fi
  echo ""
fi

# ─── Recent Snapshot ─────────────────────────────
if [ -d "$SNAPSHOT_DIR" ]; then
  SNAP=$(ls -1 "$SNAPSHOT_DIR"/*.json 2>/dev/null | sort | tail -1)
  if [ -n "$SNAP" ]; then
    AGE_SEC=$(( $(date +%s) - $(stat -c %Y "$SNAP" 2>/dev/null || stat -f %m "$SNAP" 2>/dev/null || echo 0) ))
    AGE_HR=$(( AGE_SEC / 3600 ))
    if [ "$AGE_HR" -lt 4 ]; then
      echo "*** Recent snapshot available (${AGE_HR}h ago): $(basename "$SNAP")"
      echo "    Restore: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/snapshot.sh restore"
      echo ""
    fi
  fi
fi

# ─── Suggested Actions ───────────────────────────
echo "--- Suggested Actions ---"

# 未 commit 的修改
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
  echo "  - $DIRTY uncommitted changes detected"
fi

# 沒有 .ai 結構
if [ ! -d "$AI_DIR" ]; then
  echo "  - No .ai/ found. Run: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/check.sh --init"
fi

# 沒有 changelog
if [ ! -f "$AI_DIR/changelog.md" ]; then
  echo "  - No changelog. Will be created on first log."
fi

# 有舊版 docs/ai/ 但沒有 .ai/
if [ -d "$LEGACY_AI_DIR" ] && [ ! -d "$AI_DIR" ]; then
  echo "  - Legacy docs/ai/ detected. Consider migrating to .ai/"
fi

echo "=== Bootstrap Complete ==="
