#!/usr/bin/env bash
# PreToolUse hook: auto-add non-interactive flags to common commands
# Only modifies safe, additive commands. Never touches remove/purge/autoremove.

guard_auto_yes() {
  # 快速排除：四種改寫都需要這些字面；bash 比對只會比 grep 寬，命中後仍走原本的 grep
  [[ $CMD == *apt* || $CMD == *npm* || $CMD == *cp* || $CMD == *mv* ]] || exit 0

MODIFIED=""

# --- apt/apt-get install|upgrade|dist-upgrade: add -y ---
if echo "$CMD" | grep -qE '(apt|apt-get)[[:space:]]+(install|upgrade|dist-upgrade)'; then
  # skip if already has -y or --yes
  if ! echo "$CMD" | grep -qE '(^|[[:space:]])(-y|--yes)([[:space:]]|$)'; then
    # skip dangerous subcommands that might be piped or chained
    if ! echo "$CMD" | grep -qE '(apt|apt-get)[[:space:]]+(remove|purge|autoremove)'; then
      MODIFIED=$(echo "$CMD" | sed -E 's/(apt(-get)?[[:space:]]+(install|upgrade|dist-upgrade))/\1 -y/')
    fi
  fi
fi

# --- npm init: add -y ---
if [ -z "$MODIFIED" ] && echo "$CMD" | grep -qE 'npm[[:space:]]+init' && ! echo "$CMD" | grep -qE 'npm[[:space:]]+init[[:space:]]+(-y|--yes)'; then
  MODIFIED=$(echo "$CMD" | sed -E 's/npm[[:space:]]+init/npm init -y/')
fi

# --- cp -i: strip -i (alias artifact) ---
if [ -z "$MODIFIED" ] && echo "$CMD" | grep -qE 'cp[[:space:]]+-i[[:space:]]'; then
  MODIFIED=$(echo "$CMD" | sed -E 's/cp[[:space:]]+-i[[:space:]]+/cp /')
fi

# --- mv -i: strip -i (alias artifact) ---
if [ -z "$MODIFIED" ] && echo "$CMD" | grep -qE 'mv[[:space:]]+-i[[:space:]]'; then
  MODIFIED=$(echo "$CMD" | sed -E 's/mv[[:space:]]+-i[[:space:]]+/mv /')
fi

# --- No modification needed ---
if [ -z "$MODIFIED" ] || [ "$MODIFIED" = "$CMD" ]; then
  exit 0
fi

# --- Output modified command ---
ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '.tool_input')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$MODIFIED" '.command = $cmd')

jq -n \
  --argjson updated "$UPDATED_INPUT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "permissionDecisionReason": "auto-yes: added non-interactive flag",
      "updatedInput": $updated
    }
  }'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  [ -z "$cmd" ] && exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  INPUT=$input; CMD=$cmd
  guard_auto_yes
fi
