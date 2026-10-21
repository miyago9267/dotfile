#!/usr/bin/env bash

guard_git_add() {
  set -uo pipefail
  [[ $cmd =~ git[[:space:]]+add ]] || exit 0
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
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  [ -z "$cmd" ] && exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  guard_git_add
fi
