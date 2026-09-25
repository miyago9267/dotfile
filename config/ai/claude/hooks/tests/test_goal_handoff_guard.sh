#!/usr/bin/env bash
# goal-handoff-guard.py 的回歸測試：goal 生效時的交棒問句要 exit 2，其他情況放行。
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/goal-handoff-guard.py"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
G='{"type":"user","message":{"role":"user","content":"<command-name>/goal</command-name>\n<command-message>goal</command-message>\n<command-args>直接做到底</command-args>"}}'
printf '%s\n' "$G" > "$T/goal.jsonl"
printf '%s\n%s\n' "$G" '{"type":"attachment","attachment":{"type":"goal_status","met":true,"condition":"直接做到底"}}' > "$T/met.jsonl"
printf '%s\n%s\n' "$G" '{"type":"user","message":{"role":"user","content":"<command-name>/goal</command-name><command-args>clear</command-args>"}}' > "$T/clear.jsonl"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"hi"}}' > "$T/none.jsonl"
fail=0
run() { # name expect(block|pass) transcript message [reentry]
  json=$(python3 -c 'import json,sys; print(json.dumps({"transcript_path":sys.argv[1],"last_assistant_message":sys.argv[2],"stop_hook_active":sys.argv[3]=="1"},ensure_ascii=False))' "$T/$3" "$4" "${5:-0}")
  err=$(printf '%s' "$json" | python3 "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$2" = block ]; then { [ $rc = 2 ] && echo "$err" | grep -q '/goal 還在生效'; } || { echo "FAIL $1 rc=$rc"; fail=1; }
  else [ $rc = 0 ] && [ -z "$err" ] || { echo "FAIL $1 rc=$rc: $err"; fail=1; }; fi
}
run next_step_prose block goal.jsonl "S1、S2 做完了。下一步：告訴我 S3 要比較哪兩種模型設定，我就開始量測。"
run want_me block goal.jsonl "測試都過了，要我接著做 S3 嗎？"
run english_ask block goal.jsonl "Tests pass. Should I continue with S3?"
run done_report pass goal.jsonl "S0 到 S3 都做完，測試 24 個全過，已 commit。"
run blocked_named pass goal.jsonl "阻塞：TypeSafe API key 過期，要你重新登入才能繼續。"
run question_midtext pass goal.jsonl "你問為什麼會壞？原因是 regex 沒處理 -C。已修好並補了測試，全部通過。"
run goal_met pass met.jsonl "下一步：告訴我要不要繼續？"
run goal_cleared pass clear.jsonl "要我繼續嗎？"
run no_goal pass none.jsonl "要我繼續嗎？"
run reentry pass goal.jsonl "要我繼續嗎？" 1
printf 'not json' | python3 "$HOOK" >/dev/null 2>&1 || { echo "FAIL bad_json"; fail=1; }
[ $fail = 0 ] && echo "all passed"; exit $fail
