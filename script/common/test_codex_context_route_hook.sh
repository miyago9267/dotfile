#!/usr/bin/env bash
set -euo pipefail

dotfile_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
workspace_root="${MIYAGO_AGENT_WORKSPACE_ROOT:-$HOME/Project/AI/agent-workspace}"
hook="$dotfile_dir/config/ai/codex/hooks/context-route.py"
test -x "$hook"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/miyago-codex-route.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

payload='{"hook_event_name":"UserPromptSubmit","prompt":"以前怎麼處理跨專案架構與 routing？"}'
hook_output="$(printf '%s' "$payload" | \
  XDG_DATA_HOME="$test_root/data" \
  MIYAGO_AGENT_WORKSPACE_ROOT="$workspace_root" \
  MIYAGO_CONTEXT_HARNESS_BIN="$HOME/.local/bin/miyago-context-harness" \
  python3 "$hook")"

printf '%s' "$hook_output" | grep -Fq 'hookSpecificOutput'
printf '%s' "$hook_output" | grep -Fq 'Read this route plan'

route_plan="$(find "$test_root/data/miyago-agent/routes" -type f -name '*.yaml' -print | head -1)"
test -n "$route_plan"
grep -Fq 'intent: collaboration_history' "$route_plan"
if grep -Fq '以前怎麼處理' "$route_plan"; then
  echo 'route hook persisted raw query' >&2
  exit 1
fi

printf '%s\n' 'codex_context_route_hook: OK'
