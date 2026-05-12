#!/usr/bin/env bash

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

[ -z "$cmd" ] && exit 0

if ! printf '%s\n' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+add([[:space:]]+--)?[[:space:]]+(\.|-A)([[:space:];&|]|$)'; then
  exit 0
fi

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "git add guard: use explicit paths instead of git add . or git add -A"
  }
}'
