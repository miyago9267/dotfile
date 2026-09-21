#!/bin/sh

# Thin launcher for the jev-browser MCP server.
# In Orca, the parent process does not receive the vault secret. Inject it only
# into the MCP child through the local credential broker.
if ! command -v npx >/dev/null 2>&1; then
  printf '%s\n' 'jev-browser unavailable: npx was not found' >&2
  exit 127
fi

# Prefer the existing age+sops cache used by `sec`. Keep only this one value in
# the MCP environment; do not source the whole secret bundle into the child.
if [ -r "${HOME:-}/.env.secrets" ]; then
  cached_key="$(. "${HOME}/.env.secrets"; printf '%s' "${TYPESAFE_API_KEY:-}")"
  if [ -n "$cached_key" ]; then
    export TYPESAFE_API_KEY="$cached_key"
  fi
fi

if [ -n "${TYPESAFE_API_KEY:-}" ]; then
  exec npx -y -p jev-browser jev-browser-mcp "$@"
fi

if command -v agent-secret >/dev/null 2>&1; then
  exec agent-secret run typesafe-api -- npx -y -p jev-browser jev-browser-mcp "$@"
fi

# Keep the wrapper usable on machines without Miyago's vault broker. The MCP
# process will report the missing TYPESAFE_API_KEY without exposing a secret.
exec npx -y -p jev-browser jev-browser-mcp "$@"
