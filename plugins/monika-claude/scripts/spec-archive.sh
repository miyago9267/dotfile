#!/bin/bash
# Spec Archive — 封存完成的 tasks/tests/phase
# 用法:
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh tasks <slug>
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh phase <slug>
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh --help
#
# tasks: 封存 TASKS.md + TESTS.md 到 archive/（帶時間戳）
# phase: 從 PROGRESS.md 提取已完成的 Phase block 到 archive/

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh <tasks|phase> <slug>"
  echo ""
  echo "封存完成的 spec 內容"
  echo ""
  echo "Commands:"
  echo "  tasks <slug>   封存 TASKS.md + TESTS.md 到 archive/（帶時間戳）"
  echo "  phase <slug>   從 PROGRESS.md 提取已完成的 Phase blocks 到 archive/"
  echo ""
  echo "Example:"
  echo "  bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh tasks sdd-v2"
  echo "  bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh phase sdd-v2"
  exit 0
fi

ACTION="${1:-}"
SLUG="${2:-}"

if [ -z "$ACTION" ] || [ -z "$SLUG" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/spec-archive.sh <tasks|phase> <slug>"
  echo "Run with --help for details."
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SPEC_DIR="$PROJECT_ROOT/docs/specs/$SLUG"
ARCHIVE_DIR="$SPEC_DIR/archive"
TIMESTAMP=$(date '+%Y%m%d')

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory not found: $SPEC_DIR"
  exit 1
fi

# ─── Archive Tasks ───────────────────────────────
do_archive_tasks() {
  mkdir -p "$ARCHIVE_DIR"

  ARCHIVED=0

  if [ -f "$SPEC_DIR/TASKS.md" ]; then
    mv "$SPEC_DIR/TASKS.md" "$ARCHIVE_DIR/${TIMESTAMP}-TASKS.md"
    echo "Archived: TASKS.md -> archive/${TIMESTAMP}-TASKS.md"
    ARCHIVED=$((ARCHIVED + 1))
  else
    echo "Warning: No TASKS.md found in $SPEC_DIR"
  fi

  if [ -f "$SPEC_DIR/TESTS.md" ]; then
    mv "$SPEC_DIR/TESTS.md" "$ARCHIVE_DIR/${TIMESTAMP}-TESTS.md"
    echo "Archived: TESTS.md -> archive/${TIMESTAMP}-TESTS.md"
    ARCHIVED=$((ARCHIVED + 1))
  else
    echo "Warning: No TESTS.md found in $SPEC_DIR"
  fi

  if [ "$ARCHIVED" -gt 0 ]; then
    echo "=== $ARCHIVED file(s) archived for $SLUG ==="
  else
    echo "Nothing to archive."
  fi
}

# ─── Archive Phase ───────────────────────────────
do_archive_phase() {
  PROGRESS_FILE="$SPEC_DIR/PROGRESS.md"

  if [ ! -f "$PROGRESS_FILE" ]; then
    echo "Error: No PROGRESS.md found in $SPEC_DIR"
    exit 1
  fi

  mkdir -p "$ARCHIVE_DIR"

  # 提取已完成的 phase blocks (Status: completed)
  # 策略：兩遍 parse
  #   Pass 1: 收集每個 Phase block（標題行到下一個標題行之間）
  #   Pass 2: 根據 block 內是否含 "Status: completed" 分流

  TEMP_ARCHIVE=$(mktemp)
  TEMP_REMAINING=$(mktemp)
  FOUND_COMPLETED=false

  # 收集 phase blocks: 用 awk 把每個 ## Phase block 分段處理
  awk '
  BEGIN { block=""; is_phase=0 }
  /^## Phase [0-9]/ {
    if (is_phase && block != "") {
      if (block ~ /[Ss]tatus: completed/) {
        print block > "'"$TEMP_ARCHIVE"'"
        found=1
      } else {
        print block > "'"$TEMP_REMAINING"'"
      }
    }
    block=$0
    is_phase=1
    next
  }
  /^## / && !/^## Phase [0-9]/ {
    # 非 Phase 的 ## 標題，結束當前 phase block
    if (is_phase && block != "") {
      if (block ~ /[Ss]tatus: completed/) {
        print block > "'"$TEMP_ARCHIVE"'"
        found=1
      } else {
        print block > "'"$TEMP_REMAINING"'"
      }
      block=""
      is_phase=0
    }
    print > "'"$TEMP_REMAINING"'"
    next
  }
  {
    if (is_phase) {
      block = block "\n" $0
    } else {
      print > "'"$TEMP_REMAINING"'"
    }
  }
  END {
    if (is_phase && block != "") {
      if (block ~ /[Ss]tatus: completed/) {
        print block > "'"$TEMP_ARCHIVE"'"
      } else {
        print block > "'"$TEMP_REMAINING"'"
      }
    }
  }
  ' "$PROGRESS_FILE"

  # 檢查是否有封存內容
  [ -s "$TEMP_ARCHIVE" ] && FOUND_COMPLETED=true

  if [ "$FOUND_COMPLETED" = true ]; then
    # 儲存封存的 phase blocks
    mv "$TEMP_ARCHIVE" "$ARCHIVE_DIR/${TIMESTAMP}-phases.md"
    echo "Archived completed phases -> archive/${TIMESTAMP}-phases.md"

    # 更新 PROGRESS.md（移除已完成的 phase blocks）
    mv "$TEMP_REMAINING" "$PROGRESS_FILE"
    echo "Updated PROGRESS.md (removed completed phases)"

    echo "=== Phase archive complete for $SLUG ==="
  else
    rm -f "$TEMP_ARCHIVE" "$TEMP_REMAINING"
    echo "No completed phases found in PROGRESS.md"
  fi
}

# ─── Dispatch ────────────────────────────────────
case "$ACTION" in
  tasks) do_archive_tasks ;;
  phase) do_archive_phase ;;
  *) echo "Usage: spec-archive.sh <tasks|phase> <slug>"; exit 1 ;;
esac
