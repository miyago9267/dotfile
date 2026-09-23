#!/bin/bash
# pilotfish-agy 端對端驗證：實際呼叫 agy，驗 SPEC R1-R4 與 skill 可見性。
# 會消耗 agy quota（約 5 次 headless 呼叫）。需先跑 script/common/setup_gemini.sh。

set -uo pipefail

CONV_DIR="$HOME/.gemini/antigravity-cli/conversations"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAIL=0

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; FAIL=1; }

run_agy() {
  (cd "$WORK" && agy --dangerously-skip-permissions --print-timeout 300s -p="$1" 2>&1)
}

ROLE_MARKERS=("fast, read-only scout" "read-only leaf Plan verifier" "leaf outcome verifier")

# 本次呼叫後更新的 subagent DB 中的 model ID。subagent DB 只含自己角色的
# system prompt 標記；同時含多個標記的是主 session（包括同時開著的其他 agy
# session），排除以免汙染結果。
subagent_models() {
  local mark="$1" phrase="$2" db text other
  find "$CONV_DIR" \( -name '*.db' -o -name '*.db-wal' \) -newer "$mark" | while read -r db; do
    text="$(strings -n 5 "$db")"
    [[ "$text" == *"$phrase"* ]] || continue
    for other in "${ROLE_MARKERS[@]}"; do
      [ "$other" = "$phrase" ] && continue
      [[ "$text" == *"$other"* ]] && continue 2
    done
    grep -oE 'gemini-3\.[0-9]+-(pro|flash)' <<<"$text"
  done | sort -u | tr '\n' ' '
}

echo "R1: agy agents lists 7 roles"
roles="$(cd "$WORK" && agy agents 2>&1 | sort | tr '\n' ' ')"
expected="executor mech-executor plan-verifier scout security-executor security-reviewer verifier "
[ "$roles" = "$expected" ] && pass "$roles" || fail "got: $roles"

echo "R2: tier routing"
for pair in "scout:flash:fast, read-only scout" "plan-verifier:pro:read-only leaf Plan verifier"; do
  role="${pair%%:*}"; rest="${pair#*:}"; tier="${rest%%:*}"; phrase="${rest#*:}"
  mark="$WORK/.mark-$role"; touch "$mark"; sleep 1
  run_agy "Invoke the subagent $role with task: 'Reply with the single word PING.' Then print its reply verbatim." >/dev/null
  models="$(subagent_models "$mark" "$phrase")"
  if [ -z "$models" ]; then fail "$role: subagent DB not found"; continue; fi
  if [ "$tier" = pro ]; then
    [[ "$models" == *-pro* ]] && pass "$role -> $models" || fail "$role expected pro, saw: $models"
  else
    [[ "$models" != *-pro* ]] && pass "$role -> $models" || fail "$role expected flash only, saw: $models"
  fi
done

echo "R3: read-only role cannot write"
target="$WORK/r3-should-not-exist.txt"
run_agy "Invoke the subagent scout with task: 'Create the file $target containing hello. Use any tool you have.' Do NOT create the file yourself. Print its reply verbatim." >/dev/null
[ ! -e "$target" ] && pass "scout could not create $target" || fail "scout created $target"

echo "R4: verifier can run commands"
out="$(run_agy "Invoke the subagent verifier with task: 'Run the shell command: echo VERIFIER-\$((20+22)) and report its exact output.' Print its reply verbatim.")"
[[ "$out" == *VERIFIER-42* ]] && pass "verifier ran a command" || fail "no VERIFIER-42 in output"

echo "R5: orchestration skill visible"
out="$(run_agy "Do not use any tools. List the names of all skills available to you, comma-separated.")"
[[ "$out" == *pilotfish-orchestration* ]] && pass "pilotfish-orchestration listed" || fail "skill not listed"

[ "$FAIL" -eq 0 ] && echo "ALL PASS" || { echo "FAILED"; exit 1; }
