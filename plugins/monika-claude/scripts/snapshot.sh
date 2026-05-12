#!/bin/bash
# Global Snapshot — Context checkpoint save/restore
# 用法:
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/snapshot.sh save [--decisions "d1;d2"] [--facts "f1;f2"]
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/snapshot.sh restore
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/snapshot.sh list
#   bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/snapshot.sh --help

set -e

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash ${CLAUDE_PLUGIN_ROOT:-~/.claude}/scripts/snapshot.sh <save|restore|list>"
  echo ""
  echo "Context checkpoint 管理"
  echo ""
  echo "Commands:"
  echo "  save [--decisions \"d1;d2\"] [--facts \"f1;f2\"]  儲存 checkpoint"
  echo "  restore                                        恢復最近 checkpoint"
  echo "  list                                           列出可用 snapshots"
  exit 0
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AI_DIR="$PROJECT_ROOT/.ai"
LEGACY_AI_DIR="$PROJECT_ROOT/docs/ai"
SNAPSHOT_DIR="$AI_DIR/snapshots"
ACTION="${1:-list}"
shift 2>/dev/null || true

# ─── Save ────────────────────────────────────────
do_save() {
  DECISIONS=""
  FACTS=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --decisions) DECISIONS="$2"; shift 2 ;;
      --facts) FACTS="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  mkdir -p "$SNAPSHOT_DIR"

  BRANCH=$(git branch --show-current 2>/dev/null || echo "N/A")
  TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
  FILENAME="snapshot-$(date '+%Y%m%d-%H%M%S').json"

  # Gather recent changelog (check both .ai/ and legacy)
  RECENT_LOG=""
  if [ -f "$AI_DIR/changelog.md" ]; then
    RECENT_LOG=$(tail -20 "$AI_DIR/changelog.md" | sed 's/"/\\"/g' | tr '\n' '\t')
  elif [ -f "$LEGACY_AI_DIR/changelog.md" ]; then
    RECENT_LOG=$(tail -20 "$LEGACY_AI_DIR/changelog.md" | sed 's/"/\\"/g' | tr '\n' '\t')
  fi

  # Git status summary
  GIT_DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  GIT_STAT="$GIT_DIRTY uncommitted"

  # Active specs
  SPECS_SUMMARY=""
  if [ -d "$PROJECT_ROOT/docs/specs" ]; then
    for spec in "$PROJECT_ROOT/docs/specs"/*/SPEC.md; do
      [ -f "$spec" ] || continue
      SLUG=$(basename "$(dirname "$spec")")
      [ "$SLUG" = "archive" ] && continue
      [ "$SLUG" = "_templates" ] && continue
      STATUS=$(grep -m1 '^status:' "$spec" 2>/dev/null | sed 's/status: *//')
      SPECS_SUMMARY="${SPECS_SUMMARY}${SLUG}:${STATUS};"
    done
  fi

  # Build JSON manually (no jq dependency)
  cat > "$SNAPSHOT_DIR/$FILENAME" << SNAPEOF
{
  "timestamp": "$TIMESTAMP",
  "branch": "$BRANCH",
  "git": "$GIT_STAT",
  "decisions": "$(echo "$DECISIONS" | sed 's/"/\\"/g')",
  "facts": "$(echo "$FACTS" | sed 's/"/\\"/g')",
  "specs": "$SPECS_SUMMARY",
  "recent_changelog": "$RECENT_LOG"
}
SNAPEOF

  echo "Snapshot saved: $SNAPSHOT_DIR/$FILENAME"
}

# ─── Restore ─────────────────────────────────────
do_restore() {
  if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo "No snapshots directory found."
    exit 1
  fi

  LATEST=$(ls -1 "$SNAPSHOT_DIR"/*.json 2>/dev/null | sort | tail -1)
  if [ -z "$LATEST" ]; then
    echo "No snapshots found."
    exit 1
  fi

  echo "=== Restoring from: $(basename "$LATEST") ==="
  echo ""

  # Parse JSON fields (basic, no jq). Match only top-level keys (2-space indent)
  extract() { grep "^  \"$1\":" "$LATEST" | head -1 | sed "s/^  \"$1\": *\"//;s/\"[, ]*$//"; }

  TIMESTAMP=$(extract timestamp)
  BRANCH=$(extract branch)
  GIT=$(extract git)
  DECISIONS=$(extract decisions)
  FACTS=$(extract facts)
  SPECS=$(extract specs)
  CHANGELOG=$(extract recent_changelog)

  echo "Snapshot from: $TIMESTAMP (branch: $BRANCH)"
  echo "Git state: $GIT"

  if [ -n "$DECISIONS" ]; then
    echo ""
    echo "Decisions:"
    echo "$DECISIONS" | tr ';' '\n' | while read -r d; do
      d=$(echo "$d" | sed 's/^ *//')
      [ -n "$d" ] && echo "  - $d"
    done
  fi

  if [ -n "$FACTS" ]; then
    echo ""
    echo "Key facts:"
    echo "$FACTS" | tr ';' '\n' | while read -r f; do
      f=$(echo "$f" | sed 's/^ *//')
      [ -n "$f" ] && echo "  - $f"
    done
  fi

  if [ -n "$SPECS" ]; then
    echo ""
    echo "Active specs:"
    echo "$SPECS" | tr ';' '\n' | while read -r s; do
      [ -n "$s" ] && echo "  - $s"
    done
  fi

  if [ -n "$CHANGELOG" ]; then
    echo ""
    echo "Recent changes:"
    printf '%s' "$CHANGELOG" | tr '\t' '\n' | while read -r c; do
      [ -n "$c" ] && echo "  $c"
    done
  fi

  # 也讀 HANDOFF
  if [ -f "$AI_DIR/HANDOFF.md" ]; then
    echo ""
    echo "--- Handoff ---"
    cat "$AI_DIR/HANDOFF.md"
  fi

  echo ""
  echo "=== Restore Complete ==="
}

# ─── List ────────────────────────────────────────
do_list() {
  if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo "No snapshots directory."
    exit 0
  fi

  SNAPS=$(ls -1 "$SNAPSHOT_DIR"/*.json 2>/dev/null)
  if [ -z "$SNAPS" ]; then
    echo "No snapshots found."
    exit 0
  fi

  echo "=== Snapshots ==="
  for f in $SNAPS; do
    NAME=$(basename "$f")
    SIZE=$(wc -c < "$f" | tr -d ' ')
    echo "  $NAME (${SIZE}B)"
  done
  echo "=== $(echo "$SNAPS" | wc -l | tr -d ' ') snapshot(s) ==="
}

# ─── Dispatch ────────────────────────────────────
case "$ACTION" in
  save) do_save "$@" ;;
  restore) do_restore ;;
  list) do_list ;;
  *) echo "Usage: snapshot.sh <save|restore|list>"; exit 1 ;;
esac
