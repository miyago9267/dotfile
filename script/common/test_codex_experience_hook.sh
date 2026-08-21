#!/usr/bin/env bash
set -euo pipefail

dotfile_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
workspace_root="${MIYAGO_AGENT_WORKSPACE_ROOT:-$HOME/Project/AI/agent-workspace}"
hook="$dotfile_dir/config/ai/codex/hooks/experience-observe.py"
test -x "$hook" || {
  echo "codex_experience_hook: source hook is not executable" >&2
  exit 1
}
test_root="$(mktemp -d "${TMPDIR:-/tmp}/miyago-codex-hook.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

payload='{"hook_event_name":"UserPromptSubmit","session_id":"test-session","turn_id":"test-turn","prompt":"記住：跨專案盤點先確認來源與 symlink；token=must-not-persist"}'
printf '%s' "$payload" | \
  MIYAGO_OBSERVATION_ROOT="$test_root/data" \
  MIYAGO_AGENT_WORKSPACE_ROOT="$workspace_root" \
  MIYAGO_DOTFILE_ROOT="$dotfile_dir" \
  python3 "$hook"

observation="$(find "$test_root/data/observations" -type f -name '*.yaml' -print | head -1)"
test -n "$observation"
grep -Fq 'status: candidate' "$observation"
grep -Fq 'source: runtime_hook' "$observation"
grep -Fq '[REDACTED]' "$observation"

quiet_payload='{"hook_event_name":"UserPromptSubmit","session_id":"test-session","turn_id":"test-turn-2","prompt":"請列出目前狀態"}'
printf '%s' "$quiet_payload" | \
  MIYAGO_OBSERVATION_ROOT="$test_root/quiet" \
  MIYAGO_AGENT_WORKSPACE_ROOT="$workspace_root" \
  MIYAGO_DOTFILE_ROOT="$dotfile_dir" \
  python3 "$hook"
test ! -e "$test_root/quiet/observations"

printf '%s\n' 'codex_experience_hook: OK'
