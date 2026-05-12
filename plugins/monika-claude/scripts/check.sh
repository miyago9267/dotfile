#!/bin/bash
# Global Check — 健康檢查 + 待辦事項
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/check.sh [--init]
#       bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/check.sh --help
# --init: 初始化 .ai/ 結構

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/check.sh [--init]"
  echo ""
  echo "健康檢查 + 待辦事項"
  echo ""
  echo "Options:"
  echo "  --init    初始化 .ai/ 結構（建立目錄和基礎檔案）"
  echo "  --help    顯示此說明"
  exit 0
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
LEGACY_AI_DIR="$PROJECT_ROOT/docs/ai"
SPECS_DIR="$PROJECT_ROOT/docs/specs"

# ─── Init Mode ───────────────────────────────────
if [ "$1" = "--init" ]; then
  echo "=== Initializing .ai/ structure ==="
  mkdir -p "$AI_DIR/sessions"
  mkdir -p "$AI_DIR/snapshots"
  mkdir -p "$SPECS_DIR"

  [ ! -f "$AI_DIR/changelog.md" ] && echo "# Changelog" > "$AI_DIR/changelog.md" && echo "  Created changelog.md"
  [ ! -f "$AI_DIR/lessons.md" ] && echo "# Lessons Learned" > "$AI_DIR/lessons.md" && echo "  Created lessons.md"

  if [ ! -f "$AI_DIR/CURRENT.md" ]; then
    cat > "$AI_DIR/CURRENT.md" << 'EOF'
# Current Session

<!-- 由 AI 自動更新，記錄當前 session 正在做什麼 -->
<!-- end-session.sh 會將此內容合併到 HANDOFF.md 後清空 -->
EOF
    echo "  Created CURRENT.md"
  fi

  if [ ! -f "$AI_DIR/HANDOFF.md" ]; then
    cat > "$AI_DIR/HANDOFF.md" << 'EOF'
# Handoff

<!-- 跨 session 交接文件，bootstrap.sh 會讀取此檔案恢復 context -->
EOF
    echo "  Created HANDOFF.md"
  fi

  # 檢查 .gitignore 是否包含 .ai/
  GITIGNORE="$PROJECT_ROOT/.gitignore"
  if [ -f "$GITIGNORE" ]; then
    if ! grep -q '^\.ai/$' "$GITIGNORE" && ! grep -q '^\.ai$' "$GITIGNORE"; then
      echo "" >> "$GITIGNORE"
      echo "# AI workspace (not versioned)" >> "$GITIGNORE"
      echo ".ai/" >> "$GITIGNORE"
      echo "  Added .ai/ to .gitignore"
    fi
  fi

  echo "=== Init Complete ==="
  exit 0
fi

# ─── Health Check ────────────────────────────────
echo "=== Health Check: $(basename "$PROJECT_ROOT") ==="
ISSUES=0

# .ai 結構
if [ ! -d "$AI_DIR" ]; then
  echo "[WARN] .ai/ not found. Run: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/check.sh --init"
  ISSUES=$((ISSUES + 1))
else
  [ ! -f "$AI_DIR/changelog.md" ] && echo "[WARN] No .ai/changelog.md" && ISSUES=$((ISSUES + 1))
  [ ! -f "$AI_DIR/lessons.md" ] && echo "[WARN] No .ai/lessons.md" && ISSUES=$((ISSUES + 1))
  [ ! -d "$AI_DIR/sessions" ] && echo "[WARN] No .ai/sessions/ dir" && ISSUES=$((ISSUES + 1))
  [ ! -f "$AI_DIR/CURRENT.md" ] && echo "[WARN] No .ai/CURRENT.md" && ISSUES=$((ISSUES + 1))
  [ ! -f "$AI_DIR/HANDOFF.md" ] && echo "[WARN] No .ai/HANDOFF.md" && ISSUES=$((ISSUES + 1))
fi

# Legacy docs/ai/ 偵測
if [ -d "$LEGACY_AI_DIR" ]; then
  echo "[INFO] Legacy docs/ai/ still exists. Consider migrating content to .ai/"
fi

# .gitignore 檢查
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -q '\.ai/' "$GITIGNORE"; then
    echo "[WARN] .ai/ not in .gitignore"
    ISSUES=$((ISSUES + 1))
  fi
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
    [ "$SLUG" = "_templates" ] && continue
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
CHANGELOG_FILE=""
if [ -f "$AI_DIR/changelog.md" ]; then
  CHANGELOG_FILE="$AI_DIR/changelog.md"
elif [ -f "$LEGACY_AI_DIR/changelog.md" ]; then
  CHANGELOG_FILE="$LEGACY_AI_DIR/changelog.md"
fi

if [ -n "$CHANGELOG_FILE" ]; then
  LAST_DATE=$(grep -m1 '^## [0-9]' "$CHANGELOG_FILE" | sed 's/^## //' | head -1)
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
