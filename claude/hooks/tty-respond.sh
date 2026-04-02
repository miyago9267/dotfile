#!/bin/bash
# UserPromptSubmit hook: route user input to pty-bridge or ask-tty
#
# Priority:
#   1. Unix socket (pty-bridge MCP) -- query state, if WAITING → send via socket
#   2. File IPC (legacy ask-tty) -- if pending file exists → write response file
#   3. tty:/res: prefix -- explicit legacy trigger
#   4. Pass through to Claude
#
# Escape: // prefix always passes through to Claude

ASK_DIR="$HOME/.cache/ask-tty"
SOCK="$ASK_DIR/bridge.sock"
PID_FILE="$ASK_DIR/bridge.pid"

INPUT=$(cat)

# Parse JSON or raw text
if command -v jq &> /dev/null && echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
  IS_JSON=true
else
  PROMPT="$INPUT"
  IS_JSON=false
fi

# --- Escape: // prefix → always pass to Claude ---
if [[ "$PROMPT" == //* ]]; then
  ESCAPED="${PROMPT#//}"
  if [ "$IS_JSON" = true ]; then
    echo "$INPUT" | jq --arg p "$ESCAPED" '.prompt = $p'
  else
    echo "$ESCAPED"
  fi
  exit 0
fi

rewrite_prompt() {
  if [ "$IS_JSON" = true ]; then
    echo "$INPUT" | jq '.prompt = "[input received]"'
  else
    echo "[input received]"
  fi
}

# --- Priority 1: Unix socket (pty-bridge) ---
# Check socket exists AND server PID is alive -- stale socket = skip
if [ -S "$SOCK" ] && [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  STATE=$(curl -s --unix-socket "$SOCK" http://localhost/state 2>/dev/null)
  if echo "$STATE" | jq -e '.status == "waiting"' >/dev/null 2>&1; then
    [ -z "$PROMPT" ] && { echo "$INPUT"; exit 0; }
    curl -s --unix-socket "$SOCK" -X POST -d "$PROMPT" http://localhost/input >/dev/null 2>&1
    rewrite_prompt
    exit 0
  fi
else
  # Stale socket -- clean up
  [ -S "$SOCK" ] && rm -f "$SOCK" "$PID_FILE" 2>/dev/null
fi

# --- Priority 2: File IPC (legacy ask-tty pending) ---
if [ -f "$ASK_DIR/pending" ]; then
  [ -z "$PROMPT" ] && { echo "$INPUT"; exit 0; }
  echo "$PROMPT" > "$ASK_DIR/response"
  rewrite_prompt
  exit 0
fi

# --- Priority 3: Explicit tty:/res: prefix ---
if [[ "$PROMPT" == tty:* ]]; then
  TTY_INPUT="${PROMPT#tty:}"
elif [[ "$PROMPT" == res:* ]]; then
  TTY_INPUT="${PROMPT#res:}"
else
  # --- Priority 4: Pass through ---
  echo "$INPUT"
  exit 0
fi

[ -z "$TTY_INPUT" ] && { echo "Usage: tty:<your input>" >&2; exit 2; }
echo "$TTY_INPUT" > "$ASK_DIR/response"
rewrite_prompt
exit 0
