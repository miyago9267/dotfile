#!/usr/bin/env bash
# agy auto-check and update hook
# Fires on PreInvocation, checks and updates agy on startup.

set -e

emit_and_exit() {
  printf '{}\n'
  exit 0
}

# Trap unexpected errors to ensure valid JSON is always returned to agy
trap emit_and_exit ERR

# Read stdin JSON payload from Antigravity
PAYLOAD=$(cat)

# Only run on startup (first invocation: invocationNum == 1)
# Skip if invocationNum is >= 2
if echo "$PAYLOAD" | grep -E -q '"invocationNum"[[:space:]]*:[[:space:]]*([2-9]|[1-9][0-9]+)'; then
  emit_and_exit
fi

# Allow manual opt-out via environment variable
if [ "${AGY_AUTO_UPDATE_DISABLED:-0}" = "1" ]; then
  emit_and_exit
fi

# Configuration: default throttle 1 hour (3600s), overrideable by AGY_AUTO_UPDATE_INTERVAL
CACHE_DIR="${HOME}/.gemini/antigravity-cli"
TS_FILE="${CACHE_DIR}/.last_update_check"
INTERVAL="${AGY_AUTO_UPDATE_INTERVAL:-3600}"
NOW=$(date +%s)

# Check interval unless forced
if [ "${AGY_AUTO_UPDATE_FORCE:-0}" != "1" ] && [ -f "$TS_FILE" ]; then
  LAST_CHECK=$(cat "$TS_FILE" 2>/dev/null || echo 0)
  DIFF=$((NOW - LAST_CHECK))
  if [ "$DIFF" -ge 0 ] && [ "$DIFF" -lt "$INTERVAL" ]; then
    emit_and_exit
  fi
fi

# Ensure cache dir exists
mkdir -p "$CACHE_DIR"

# Concurrency lock to prevent multiple update processes
LOCK_DIR="${CACHE_DIR}/.auto-update.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [ -d "$LOCK_DIR" ]; then
    LOCK_AGE=$((NOW - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo "$NOW")))
    if [ "$LOCK_AGE" -gt 300 ]; then
      rm -rf "$LOCK_DIR" 2>/dev/null || true
      mkdir "$LOCK_DIR" 2>/dev/null || emit_and_exit
    else
      emit_and_exit
    fi
  else
    emit_and_exit
  fi
fi

# Update timestamp immediately
echo "$NOW" > "$TS_FILE" 2>/dev/null || true

# Find agy executable
AGY_BIN="${AGY_BIN:-$(command -v agy || echo "$HOME/.local/bin/agy")}"
if [ ! -x "$AGY_BIN" ]; then
  rm -rf "$LOCK_DIR" 2>/dev/null || true
  emit_and_exit
fi

# Run update in detached background process using nohup + disown
LOG_FILE="${CACHE_DIR}/auto-update.log"
nohup bash -c '
  LOG_FILE="$1"
  LOCK_DIR="$2"
  AGY_BIN="$3"
  echo "=== agy auto-update check at $(date) ===" >> "$LOG_FILE" 2>&1
  "$AGY_BIN" update >> "$LOG_FILE" 2>&1
  rm -rf "$LOCK_DIR" 2>/dev/null || true
' _ "$LOG_FILE" "$LOCK_DIR" "$AGY_BIN" </dev/null >/dev/null 2>&1 &
disown -h $! 2>/dev/null || true

emit_and_exit
