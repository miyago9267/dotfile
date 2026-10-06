#!/usr/bin/env bash
# secret-guard-adapter.sh 的離線回歸測試：以合成的 hook JSON 驗證每個 host 的命中、放行與格式轉換。
# 指令只以 JSON 字串餵給 adapter，不會被執行；不啟動任何 runtime。
# ADAPTER 可用環境變數覆寫；結尾的 teeth check 用它把 adapter 換成永遠放行的假貨，確認測試會失敗。
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
ADAPTER=${ADAPTER:-"$DIR/../secret-guard-adapter.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
tmp=$(mktemp -d); trap '/bin/rm -rf "$tmp"' EXIT
fail=0; n=0

# check name host expect(deny|none) json：deny 時驗證該 host 的回傳格式與 reason
check() {
  n=$((n + 1))
  local name="$1" host="$2" expect="$3" json="$4" out rc ok=0 dec reason
  out=$(printf '%s' "$json" | bash "$ADAPTER" --host "$host" 2>/dev/null); rc=$?
  if [ "$expect" = none ]; then
    [ -z "$out" ] && ok=1
  else
    if [ "$host" = codex ]; then
      dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
      reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
      [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null)" = PreToolUse ] || dec=""
    else
      dec=$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)
      reason=$(printf '%s' "$out" | jq -r '.reason // empty' 2>/dev/null)
      # agy / opencode 的回傳不得夾帶 Claude 格式
      [ "$(printf '%s' "$out" | jq -r 'has("hookSpecificOutput")' 2>/dev/null)" = false ] || dec=""
    fi
    [ "$dec" = deny ] && printf '%s' "$reason" | grep -q '^secret-guard: ' && ok=1
  fi
  [ $rc = 0 ] || ok=0
  [ $ok = 1 ] || { echo "FAIL $name host=$host expect=$expect rc=$rc out=$out"; fail=1; }
}

codex() { jq -cn --arg c "$1" --arg d "${2:-/tmp/work}" '{session_id:"s",turn_id:"t",cwd:$d,hook_event_name:"PreToolUse",tool_name:"Bash",tool_use_id:"u",tool_input:{command:$c}}'; }
agy() { jq -cn --arg c "$1" --arg d "${2:-/tmp/work}" '{conversationId:"c",cwd:$d,toolCall:{name:"run_command",args:{CommandLine:$c}}}'; }
agy_key() { jq -cn --arg k "$1" --arg c "$2" '{conversationId:"c",cwd:"/tmp/work",toolCall:{name:"run_command",args:{($k):$c}}}'; }
# shellcheck disable=SC2329  # 經 $mk 間接呼叫
oc() { jq -cn --arg c "$1" --arg d "${2:-/tmp/work}" '{tool:"bash",command:$c,cwd:$d}'; }

# 每個 host 都跑同一組命中與放行（判斷規則本身由 test_secret_guard.sh 負責，這裡只驗轉接）
for h in codex agy opencode; do
  mk=$h; [ "$h" = opencode ] && mk=oc
  check "${h}_kube_raw" "$h" deny "$($mk 'kubectl config view --raw')"
  check "${h}_gcloud_token" "$h" deny "$($mk 'gcloud auth print-access-token')"
  check "${h}_keychain" "$h" deny "$($mk 'security find-generic-password -s x -w')"
  check "${h}_sec_show" "$h" deny "$($mk 'cd /tmp && sec show')"
  check "${h}_broker_edit" "$h" deny "$($mk 'agent-secret2 edit')"
  check "${h}_sops_tilde" "$h" deny "$($mk 'sops -d ~/dotfile/secrets/agent.enc.yaml')"
  check "${h}_sops_relative_cwd" "$h" deny "$($mk 'sops -d secrets/agent.enc.yaml' "$HOME/dotfile")"
  check "${h}_multiline" "$h" deny "$($mk $'ls\nsecurity dump-keychain')"
  check "${h}_plain_ls" "$h" none "$($mk 'ls -la')"
  check "${h}_kube_view" "$h" none "$($mk 'kubectl config view')"
  check "${h}_broker_run" "$h" none "$($mk 'agent-secret2 run gitlab-token -- /opt/homebrew/bin/glab mr list')"
  check "${h}_mention" "$h" none "$($mk 'echo "sec show; gcloud auth print-access-token"')"
  check "${h}_sops_relative_other_cwd" "$h" none "$($mk 'sops -d secrets/agent.enc.yaml' /tmp/work)"
  check "${h}_empty_command" "$h" none "$($mk '')"
  check "${h}_not_json" "$h" none 'not json'
  check "${h}_empty_object" "$h" none '{}'
  check "${h}_empty_stdin" "$h" none ''
done

# --- codex：tool_input.command 是 argv 陣列時取腳本字串 ---
check codex_argv_lc codex deny '{"cwd":"/tmp","tool_name":"Bash","tool_input":{"command":["bash","-lc","sec show"]}}'
check codex_argv_plain codex deny '{"cwd":"/tmp","tool_name":"Bash","tool_input":{"command":["sec","show"]}}'
check codex_argv_safe codex none '{"cwd":"/tmp","tool_name":"Bash","tool_input":{"command":["bash","-lc","ls -la"]}}'
check codex_command_number codex none '{"cwd":"/tmp","tool_input":{"command":42}}'
check codex_no_tool_input codex none '{"cwd":"/tmp","tool_name":"Bash"}'

# --- agy：指令鍵名的各種寫法、Cwd 來源 ---
for k in CommandLine commandLine command Command cmd; do
  check "agy_key_$k" agy deny "$(agy_key "$k" 'sec show')"
  check "agy_key_${k}_safe" agy none "$(agy_key "$k" 'sec list')"
done
check agy_unknown_key agy none "$(agy_key Whatever 'sec show')"
check agy_args_cwd_wins agy deny "$(jq -cn --arg d "$HOME/dotfile" '{cwd:"/tmp/work",toolCall:{name:"run_command",args:{CommandLine:"sops -d secrets/agent.enc.yaml",Cwd:$d}}}')"
check agy_payload_cwd_fallback agy deny "$(jq -cn --arg d "$HOME/dotfile" '{cwd:$d,toolCall:{name:"run_command",args:{CommandLine:"sops -d secrets/agent.enc.yaml"}}}')"
check agy_no_toolcall agy none '{"conversationId":"c","invocationNum":0,"initialNumSteps":1}'
check agy_toolcall_not_object agy none '{"toolCall":"run_command"}'
check agy_args_not_object agy none '{"toolCall":{"name":"run_command","args":"sec show"}}'
check agy_other_tool_no_command agy none '{"toolCall":{"name":"write_to_file","args":{"TargetFile":"/tmp/x","CodeContent":"sec show"}}}'

# --- opencode：plugin 沒抽出指令時，adapter 自己從 args 找 ---
check opencode_args_command opencode deny '{"tool":"bash","cwd":"/tmp","args":{"command":"sec show"}}'
check opencode_args_cmd opencode deny '{"tool":"bash","cwd":"/tmp","args":{"cmd":"sec show"}}'
check opencode_args_safe opencode none '{"tool":"bash","cwd":"/tmp","args":{"command":"sec list"}}'
check opencode_command_object opencode none '{"tool":"bash","cwd":"/tmp","command":{"x":"sec show"}}'

# --- host 不認得或沒給：放行 ---
n=$((n + 1))
out=$(codex 'sec show' | bash "$ADAPTER" --host grok 2>/dev/null); rc=$?
{ [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL unknown_host rc=$rc out=$out"; fail=1; }
n=$((n + 1))
out=$(codex 'sec show' | bash "$ADAPTER" 2>/dev/null); rc=$?
{ [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL missing_host rc=$rc out=$out"; fail=1; }
n=$((n + 1))
out=$(agy 'sec show' | bash "$ADAPTER" --host=agy 2>/dev/null); rc=$?
[ "$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)" = deny ] || { echo "FAIL host_equals_form rc=$rc out=$out"; fail=1; }

# --- 經 symlink 呼叫也找得到 guard ---
n=$((n + 1))
ln -s "$ADAPTER" "$tmp/linked-adapter.sh"
out=$(agy 'sec show' | bash "$tmp/linked-adapter.sh" --host agy 2>/dev/null); rc=$?
[ "$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)" = deny ] || { echo "FAIL via_symlink rc=$rc out=$out"; fail=1; }

# --- deny 的來源是 secret-guard.sh：換成永遠放行的 guard 就不擋；guard 不存在或壞掉也放行 ---
printf '#!/bin/bash\ncat >/dev/null\nexit 0\n' > "$tmp/allow-guard.sh"
printf '#!/bin/bash\ncat >/dev/null\necho garbage\nexit 3\n' > "$tmp/broken-guard.sh"
printf '#!/bin/bash\ncat >/dev/null\necho "not json"\n' > "$tmp/garbage-guard.sh"
for g in allow-guard.sh broken-guard.sh garbage-guard.sh missing-guard.sh; do
  n=$((n + 1))
  out=$(agy 'sec show' | SECRET_GUARD="$tmp/$g" bash "$ADAPTER" --host agy 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL guard_override_$g rc=$rc out=$out"; fail=1; }
done
# guard 收到的 JSON 就是 Claude 的形狀（.tool_input.command 與 .cwd）
n=$((n + 1))
printf '#!/bin/bash\ncat > "%s/seen.json"\n' "$tmp" > "$tmp/record-guard.sh"
agy 'ls -la' /tmp/somewhere | SECRET_GUARD="$tmp/record-guard.sh" bash "$ADAPTER" --host agy >/dev/null 2>&1
[ "$(jq -c '.' "$tmp/seen.json" 2>/dev/null)" = '{"cwd":"/tmp/somewhere","tool_input":{"command":"ls -la"}}' ] \
  || { echo "FAIL guard_payload_shape seen=$(cat "$tmp/seen.json" 2>/dev/null)"; fail=1; }

# --- 缺 jq：fail-open（PATH 指到空目錄，bash 用絕對路徑）---
n=$((n + 1))
mkdir -p "$tmp/emptybin"
bash_bin=$(command -v bash)
payload=$(agy 'sec show')
out=$(printf '%s' "$payload" | PATH="$tmp/emptybin" "$bash_bin" "$ADAPTER" --host agy 2>/dev/null); rc=$?
{ [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL no_jq_fail_open rc=$rc out=$out"; fail=1; }

# --- teeth check：adapter 換成永遠放行的假貨時，這份測試必須失敗 ---
if [ -z "${TEETH_INNER:-}" ]; then
  n=$((n + 1))
  printf '#!/bin/bash\ncat >/dev/null\nexit 0\n' > "$tmp/noop-adapter.sh"
  inner=$(TEETH_INNER=1 ADAPTER="$tmp/noop-adapter.sh" bash "$0" 2>&1); irc=$?
  { [ $irc != 0 ] && printf '%s' "$inner" | grep -q 'FAIL agy_kube_raw'; } \
    || { echo "FAIL teeth_check：假 adapter 下測試沒有失敗 rc=$irc"; fail=1; }
fi

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
