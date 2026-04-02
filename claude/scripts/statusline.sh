#!/bin/bash
# Statusline wrapper: cache usage data -> pipe to claude-hud
# Claude Code pipes stdin JSON containing rate_limits, context_window, etc.
# This script saves a snapshot before forwarding to claude-hud for rendering.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CACHE_DIR="$CLAUDE_DIR/quota"
CACHE_FILE="$CACHE_DIR/current.json"
HISTORY_FILE="$CACHE_DIR/history.jsonl"
mkdir -p "$CACHE_DIR"

# Read all stdin
INPUT=$(cat)

# Cache rate_limits + context_window snapshot (non-blocking, ignore errors)
echo "$INPUT" | jq -c '{
  rate_limits: .rate_limits,
  context_window: {
    used_pct: .context_window.used_percentage,
    remaining_pct: .context_window.remaining_percentage,
    size: .context_window.context_window_size,
    usage: .context_window.current_usage
  },
  model: .model.display_name,
  ts: (now | floor)
}' > "$CACHE_FILE" 2>/dev/null

# Append to history (one line per refresh, cap at 500 lines)
if [ -f "$CACHE_FILE" ]; then
  cat "$CACHE_FILE" >> "$HISTORY_FILE" 2>/dev/null
  # Trim history if over 500 lines
  if [ "$(wc -l < "$HISTORY_FILE" 2>/dev/null)" -gt 500 ]; then
    tail -300 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
  fi
fi

# Find and pipe to claude-hud
HUD_DIR=$(ls -d "$CLAUDE_DIR"/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | sort -t. -k1,1n -k2,2n -k3,3n \
  | tail -1 | cut -f2-)

if [ -z "$HUD_DIR" ]; then
  # Fallback: marketplace directory
  HUD_DIR="$CLAUDE_DIR/plugins/marketplaces/claude-hud/"
fi

HUD_ENTRY="${HUD_DIR}dist/index.js"

if [ -f "$HUD_ENTRY" ]; then
  echo "$INPUT" | node "$HUD_ENTRY" "$@"
else
  # No claude-hud found, minimal output
  FIVE_H=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
  SEVEN_D=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
  CTX=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
  echo "ctx: ${CTX:-?}% | 5h: ${FIVE_H:-?}% | 7d: ${SEVEN_D:-?}%"
fi
