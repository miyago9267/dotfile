#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$DOTFILE_DIR/script/utils/agent-call"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-call-test.XXXXXX")"
PROMPT_FILE="$TEST_DIR/prompt.txt"
SUCCESS_BIN="$TEST_DIR/provider-success"
FAIL_BIN="$TEST_DIR/provider-fail"
SLOW_BIN="$TEST_DIR/provider-slow"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

assert_field() {
  local record="$1"
  local filter="$2"
  local expected="$3"
  local actual

  actual="$(printf '%s\n' "$record" | jq -r "$filter")"
  [ "$actual" = "$expected" ] || {
    printf 'agent-call test: %s = %s, expected %s\n' "$filter" "$actual" "$expected" >&2
    return 1
  }
}

printf 'TEST_SECRET_MARKER\n' >"$PROMPT_FILE"
printf '#!/bin/sh\nexit 0\n' >"$SUCCESS_BIN"
printf '#!/bin/sh\nexit 7\n' >"$FAIL_BIN"
printf '#!/bin/sh\nexec /usr/bin/ruby -e '\''sleep 30'\''\n' >"$SLOW_BIN"
chmod +x "$SUCCESS_BIN" "$FAIL_BIN" "$SLOW_BIN"

sync_record="$(AGENT_CALL_AGY_BIN="$SUCCESS_BIN" "$RUNNER" run \
  --runtime agy --cwd "$DOTFILE_DIR" --prompt-file "$PROMPT_FILE" \
  --state-dir "$TEST_DIR/sync-state" --timeout-seconds 5)"
assert_field "$sync_record" '.status' succeeded
assert_field "$sync_record" '.exit_code' 0
sync_job_dir="$(printf '%s\n' "$sync_record" | jq -r '.output_file' | sed 's#/provider.stdout$##')"
if rg -q 'TEST_SECRET_MARKER' "$sync_job_dir/metadata.json"; then
  printf 'agent-call test: prompt content leaked into metadata\n' >&2
  exit 1
fi

set +e
failure_record="$(AGENT_CALL_AGY_BIN="$FAIL_BIN" "$RUNNER" run \
  --runtime agy --cwd "$DOTFILE_DIR" --prompt-file "$PROMPT_FILE" \
  --state-dir "$TEST_DIR/failure-state" --timeout-seconds 5)"
failure_rc=$?
set -e
[ "$failure_rc" -eq 7 ]
assert_field "$failure_record" '.status' failed
assert_field "$failure_record" '.exit_code' 7
assert_field "$failure_record" '.reason' provider_exit

background_record="$(AGENT_CALL_AGY_BIN="$SUCCESS_BIN" "$RUNNER" run \
  --runtime agy --cwd "$DOTFILE_DIR" --prompt-file "$PROMPT_FILE" \
  --state-dir "$TEST_DIR/background-state" --timeout-seconds 5 --background)"
background_job_dir="$(printf '%s\n' "$background_record" | jq -r '.job_dir')"
background_result="$("$RUNNER" wait --job-dir "$background_job_dir" --wait-seconds 10)"
assert_field "$background_result" '.status' succeeded
assert_field "$background_result" '.exit_code' 0

set +e
timeout_record="$(AGENT_CALL_AGY_BIN="$SLOW_BIN" "$RUNNER" run \
  --runtime agy --cwd "$DOTFILE_DIR" --prompt-file "$PROMPT_FILE" \
  --state-dir "$TEST_DIR/timeout-state" --timeout-seconds 1)"
timeout_rc=$?
set -e
[ "$timeout_rc" -eq 124 ]
assert_field "$timeout_record" '.status' timed_out
assert_field "$timeout_record" '.reason' provider_timeout

cancel_record="$(AGENT_CALL_AGY_BIN="$SLOW_BIN" "$RUNNER" run \
  --runtime agy --cwd "$DOTFILE_DIR" --prompt-file "$PROMPT_FILE" \
  --state-dir "$TEST_DIR/cancel-state" --timeout-seconds 30 --background)"
cancel_job_dir="$(printf '%s\n' "$cancel_record" | jq -r '.job_dir')"
cancel_result="$("$RUNNER" cancel --job-dir "$cancel_job_dir")"
assert_field "$cancel_result" '.status' cancelled
assert_field "$cancel_result" '.reason' cancelled

printf 'agent-call tests: ok\n'
