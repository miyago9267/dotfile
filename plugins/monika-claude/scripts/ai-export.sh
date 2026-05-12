#!/bin/bash
# AI Export — 將 .ai/ 精選內容匯出到 docs/ai/ 供手動 commit
# 用法: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/ai-export.sh [--all]
#       bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/ai-export.sh --help
# 預設匯出 lessons.md + 最近 session summary
# --all: 也匯出 changelog.md

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/ai-export.sh [--all]"
  echo ""
  echo "將 .ai/ 精選內容匯出到 docs/ai/ 供手動 commit"
  echo ""
  echo "Options:"
  echo "  --all     也匯出 changelog.md（通常只匯出 lessons + session）"
  echo "  --help    顯示此說明"
  echo ""
  echo "匯出後需手動 git add + commit docs/ai/ 的改動"
  exit 0
fi

EXPORT_ALL=false
if [ "$1" = "--all" ]; then EXPORT_ALL=true; fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
EXPORT_DIR="$PROJECT_ROOT/docs/ai"

if [ ! -d "$AI_DIR" ]; then
  echo "Error: .ai/ not found. Nothing to export."
  exit 1
fi

mkdir -p "$EXPORT_DIR"

EXPORTED=0

# ─── Lessons ─────────────────────────────────────
if [ -f "$AI_DIR/lessons.md" ]; then
  LESSON_LINES=$(wc -l < "$AI_DIR/lessons.md" | tr -d ' ')
  if [ "$LESSON_LINES" -gt 1 ]; then
    cp "$AI_DIR/lessons.md" "$EXPORT_DIR/lessons.md"
    echo "Exported: lessons.md ($LESSON_LINES lines)"
    EXPORTED=$((EXPORTED + 1))
  fi
fi

# ─── Latest Session Summary ──────────────────────
if [ -d "$AI_DIR/sessions" ]; then
  mkdir -p "$EXPORT_DIR/sessions"
  LATEST=$(ls -1 "$AI_DIR/sessions/"*.md 2>/dev/null | sort | tail -1)
  if [ -n "$LATEST" ]; then
    cp "$LATEST" "$EXPORT_DIR/sessions/"
    echo "Exported: sessions/$(basename "$LATEST")"
    EXPORTED=$((EXPORTED + 1))
  fi
fi

# ─── Changelog (only with --all) ─────────────────
if [ "$EXPORT_ALL" = true ] && [ -f "$AI_DIR/changelog.md" ]; then
  cp "$AI_DIR/changelog.md" "$EXPORT_DIR/changelog.md"
  echo "Exported: changelog.md"
  EXPORTED=$((EXPORTED + 1))
fi

if [ "$EXPORTED" -eq 0 ]; then
  echo "Nothing to export."
else
  echo ""
  echo "=== $EXPORTED file(s) exported to docs/ai/ ==="
  echo ""
  echo "[NOTE] 這些檔案需要手動 commit:"
  echo "  git add docs/ai/"
  echo "  git commit -m \"docs: export AI workspace content\""
fi
