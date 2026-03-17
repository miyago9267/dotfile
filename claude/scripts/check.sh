#!/bin/bash
# Global Check — 健康檢查 + 待辦事項
# 用法: bash ~/.claude/scripts/check.sh [--init]
# --init: 初始化 docs/ai/ 結構

set -e

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/docs/ai"
SPECS_DIR="$PROJECT_ROOT/docs/specs"

# ─── Init Mode ───────────────────────────────────
if [ "$1" = "--init" ]; then
  echo "=== Initializing docs/ai/ structure ==="
  mkdir -p "$AI_DIR/sessions"
  mkdir -p "$AI_DIR/snapshots"
  mkdir -p "$SPECS_DIR"

  [ ! -f "$AI_DIR/changelog.md" ] && echo "# Changelog" > "$AI_DIR/changelog.md" && echo "  Created changelog.md"
  [ ! -f "$AI_DIR/lessons.md" ] && echo "# Lessons Learned" > "$AI_DIR/lessons.md" && echo "  Created lessons.md"

  echo "=== Init Complete ==="
  exit 0
fi

# ─── Health Check ────────────────────────────────
echo "=== Health Check: $(basename "$PROJECT_ROOT") ==="
ISSUES=0

# docs/ai 結構
if [ ! -d "$AI_DIR" ]; then
  echo "[WARN] docs/ai/ not found. Run: bash ~/.claude/scripts/check.sh --init"
  ISSUES=$((ISSUES + 1))
else
  [ ! -f "$AI_DIR/changelog.md" ] && echo "[WARN] No changelog.md" && ISSUES=$((ISSUES + 1))
  [ ! -f "$AI_DIR/lessons.md" ] && echo "[WARN] No lessons.md" && ISSUES=$((ISSUES + 1))
  [ ! -d "$AI_DIR/sessions" ] && echo "[WARN] No sessions/ dir" && ISSUES=$((ISSUES + 1))
fi

# Git 狀態
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY" -gt 0 ]; then
  echo "[INFO] $DIRTY uncommitted changes"
  git status --porcelain 2>/dev/null | head -10
  [ "$DIRTY" -gt 10 ] && echo "  ... +$((DIRTY - 10)) more"
fi

# Active specs
if [ -d "$SPECS_DIR" ]; then
  IN_PROGRESS=0
  DRAFT=0
  for spec in "$SPECS_DIR"/*/SPEC.md; do
    [ -f "$spec" ] || continue
    SLUG=$(basename "$(dirname "$spec")")
    [ "$SLUG" = "archive" ] && continue
    STATUS=$(grep -m1 '^status:' "$spec" 2>/dev/null | sed 's/status: *//')
    case "$STATUS" in
      in_progress|in-progress) IN_PROGRESS=$((IN_PROGRESS + 1)) ;;
      draft) DRAFT=$((DRAFT + 1)) ;;
    esac
  done
  [ "$IN_PROGRESS" -gt 0 ] && echo "[INFO] $IN_PROGRESS spec(s) in progress"
  [ "$DRAFT" -gt 0 ] && echo "[INFO] $DRAFT draft spec(s)"
fi

# Changelog 最後更新
if [ -f "$AI_DIR/changelog.md" ]; then
  LAST_DATE=$(grep -m1 '^## [0-9]' "$AI_DIR/changelog.md" | sed 's/^## //' | head -1)
  if [ -n "$LAST_DATE" ]; then
    echo "[INFO] Last changelog entry: $LAST_DATE"
  fi
fi

# 今天是否有 session 文件
TODAY=$(date '+%Y-%m-%d')
if [ -d "$AI_DIR/sessions" ] && [ ! -f "$AI_DIR/sessions/${TODAY}.md" ]; then
  echo "[TODO] No session file for today. Will be created by end-session."
fi

if [ "$ISSUES" -eq 0 ]; then
  echo "[OK] All checks passed"
else
  echo "[RESULT] $ISSUES issue(s) found"
fi

echo "=== Check Complete ==="
