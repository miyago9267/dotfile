#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_DIR="$ROOT/config/ai/codex"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

check_light_profile() {
  local profile="$1"
  local file="$CODEX_DIR/$profile.config.toml"

  [ -f "$file" ] || fail "$file missing"
  if grep -q '^\[mcp_servers' "$file"; then
    fail "$profile defines mcp_servers"
  fi
  if grep -A1 '^\[plugins\."computer-use@openai-bundled"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables computer-use plugin"
  fi
  if grep -A1 '^\[plugins\."browser@openai-bundled"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables browser plugin"
  fi
  if grep -A1 '^\[plugins\."documents@openai-primary-runtime"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables documents plugin"
  fi
  if grep -A1 '^\[plugins\."spreadsheets@openai-primary-runtime"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables spreadsheets plugin"
  fi
  if grep -A1 '^\[plugins\."presentations@openai-primary-runtime"\]' "$file" | grep -q 'enabled = true'; then
    fail "$profile enables presentations plugin"
  fi
}

check_light_profile fast
check_light_profile code

codex exec --ignore-user-config -p fast --strict-config --version >/dev/null
codex exec --ignore-user-config -p code --strict-config --version >/dev/null
codex exec -p heavy --strict-config --version >/dev/null

printf 'OK: codex profiles pass hygiene checks\n'
