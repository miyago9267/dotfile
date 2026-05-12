#!/bin/bash
# Strategic Compact Suggester
# PreToolUse hook -- 在 Edit/Write 時追蹤 tool call 次數，到達閾值建議 /compact
#
# Hook config (in ~/.claude/settings.json):
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Edit|Write",
#       "hooks": [{
#         "type": "command",
#         "command": "${CLAUDE_PLUGIN_ROOT}/skills/strategic-compact/suggest-compact.sh"
#       }]
#     }]
#   }
# }

COUNTER_FILE="/tmp/claude-tool-count-${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
THRESHOLD=${COMPACT_THRESHOLD:-50}

# Initialize or increment counter
if [ -f "$COUNTER_FILE" ]; then
  count=$(cat "$COUNTER_FILE")
  count=$((count + 1))
  echo "$count" > "$COUNTER_FILE"
else
  echo "1" > "$COUNTER_FILE"
  count=1
fi

# Suggest compact after threshold tool calls
if [ "$count" -eq "$THRESHOLD" ]; then
  echo "[StrategicCompact] $THRESHOLD tool calls reached - consider /compact if transitioning phases" >&2
fi

# Suggest at regular intervals after threshold
if [ "$count" -gt "$THRESHOLD" ] && [ $((count % 25)) -eq 0 ]; then
  echo "[StrategicCompact] $count tool calls - good checkpoint for /compact if context is stale" >&2
fi
