#!/usr/bin/env bash
# PreToolUse hook: auto-add non-interactive flags to common commands
# Only modifies safe, additive commands. Never touches remove/purge/autoremove.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$CMD" ] && exit 0

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
