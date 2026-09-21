#!/bin/sh

# Thin launcher for Reticle's MCP server. Reticle itself is dev-only/local-only.
if ! command -v npx >/dev/null 2>&1; then
  printf '%s\n' 'reticle unavailable: npx was not found' >&2
  exit 127
fi

exec npx -y @reticlehq/server mcp "$@"
