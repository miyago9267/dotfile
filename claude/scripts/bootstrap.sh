#!/bin/bash
# Global Bootstrap — 新 session 自舉上下文
# 用法: bash ~/.claude/scripts/bootstrap.sh [--compact]
# 適用任何專案，自動偵測 docs/ai/ 結構

set -e

COMPACT=false
if [ "$1" = "--compact" ]; then COMPACT=true; fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/docs/ai"
SPECS_DIR="$PROJECT_ROOT/docs/specs"
SNAPSHOT_DIR="$AI_DIR/snapshots"

echo "=== Bootstrap: $(basename "$PROJECT_ROOT") ==="
echo "Root: $PROJECT_ROOT"
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
echo "Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

# ─── Changelog (最近 20 行) ─────────────────────
if [ -f "$AI_DIR/changelog.md" ]; then
  echo "--- Recent Changes ---"
  tail -30 "$AI_DIR/changelog.md" | head -20
  echo ""
fi

# ─── Lessons ─────────────────────────────────────
if [ -f "$AI_DIR/lessons.md" ]; then
  LESSON_LINES=$(wc -l < "$AI_DIR/lessons.md")
  if [ "$COMPACT" = true ] && [ "$LESSON_LINES" -gt 30 ]; then
    echo "--- Lessons (last 15) ---"
    tail -15 "$AI_DIR/lessons.md"
  else
    echo "--- Lessons ---"
    cat "$AI_DIR/lessons.md"
  fi
  echo ""
fi

# ─── Latest Session ──────────────────────────────
if [ -d "$AI_DIR/sessions" ]; then
  LATEST=$(ls -1 "$AI_DIR/sessions/"*.md 2>/dev/null | sort | tail -1)
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
    # 跳過 archive
    [ "$SLUG" = "archive" ] && continue
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
      echo "    Restore: bash ~/.claude/scripts/snapshot.sh restore"
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

# 沒有 docs/ai 結構
if [ ! -d "$AI_DIR" ]; then
  echo "  - No docs/ai/ found. Run: bash ~/.claude/scripts/check.sh --init"
fi

# 沒有 changelog
if [ ! -f "$AI_DIR/changelog.md" ]; then
  echo "  - No changelog. Will be created on first log."
fi

echo "=== Bootstrap Complete ==="
