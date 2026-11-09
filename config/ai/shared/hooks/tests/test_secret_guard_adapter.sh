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

# check name host expect(deny|hit|none) json：deny 時驗證該 host 的回傳格式與 reason。
# hit 是 secret-guard 命中：codex / opencode 回 deny，agy 回 force_ask（由 Miyago 在 prompt 核准）
check() {
  n=$((n + 1))
  local name="$1" host="$2" expect="$3" json="$4" out rc ok=0 dec reason want=deny
  [ "$expect" = hit ] && [ "$host" = agy ] && want=force_ask
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
    [ "$dec" = "$want" ] && printf '%s' "$reason" | grep -q '^secret-guard: ' && ok=1
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
  check "${h}_kube_raw" "$h" hit "$($mk 'kubectl config view --raw')"
  check "${h}_gcloud_token" "$h" hit "$($mk 'gcloud auth print-access-token')"
  check "${h}_keychain" "$h" hit "$($mk 'security find-generic-password -s x -w')"
  check "${h}_sec_show" "$h" hit "$($mk 'cd /tmp && sec show')"
  check "${h}_broker_edit" "$h" hit "$($mk 'agent-secret2 edit')"
  check "${h}_sops_tilde" "$h" hit "$($mk 'sops -d ~/dotfile/secrets/agent.enc.yaml')"
  check "${h}_sops_relative_cwd" "$h" hit "$($mk 'sops -d secrets/agent.enc.yaml' "$HOME/dotfile")"
  check "${h}_multiline" "$h" hit "$($mk $'ls\nsecurity dump-keychain')"
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
  check "agy_key_$k" agy hit "$(agy_key "$k" 'sec show')"
  check "agy_key_${k}_safe" agy none "$(agy_key "$k" 'sec list')"
done
check agy_unknown_key agy none "$(agy_key Whatever 'sec show')"
check agy_args_cwd_wins agy hit "$(jq -cn --arg d "$HOME/dotfile" '{cwd:"/tmp/work",toolCall:{name:"run_command",args:{CommandLine:"sops -d secrets/agent.enc.yaml",Cwd:$d}}}')"
check agy_payload_cwd_fallback agy hit "$(jq -cn --arg d "$HOME/dotfile" '{cwd:$d,toolCall:{name:"run_command",args:{CommandLine:"sops -d secrets/agent.enc.yaml"}}}')"
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
[ "$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)" = force_ask ] || { echo "FAIL host_equals_form rc=$rc out=$out"; fail=1; }

# --- 經 symlink 呼叫也找得到 guard ---
n=$((n + 1))
ln -s "$ADAPTER" "$tmp/linked-adapter.sh"
out=$(agy 'sec show' | bash "$tmp/linked-adapter.sh" --host agy 2>/dev/null); rc=$?
[ "$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)" = force_ask ] || { echo "FAIL via_symlink rc=$rc out=$out"; fail=1; }

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

# --- agy 分級政策：不可逆 deny > 讀憑證 force_ask > 一般檔案與版控放行（用 repo 內實際的 guard）---
# 指令只以 JSON 字串餵給 adapter，不會被執行
# tier name expect(allow|force_ask|deny-copy|deny-attr) json
tier() {
  n=$((n + 1))
  local out dec reason ok=0
  out=$(printf '%s' "$3" | bash "$ADAPTER" --host agy 2>/dev/null)
  dec=$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)
  reason=$(printf '%s' "$out" | jq -r '.reason // empty' 2>/dev/null)
  case "$2" in
    allow) [ -z "$out" ] && ok=1 ;;
    force_ask) [ "$dec" = force_ask ] && printf '%s' "$reason" | grep -q '^secret-guard: .*核准' && ok=1 ;;
    deny-copy) [ "$dec" = deny ] && printf '%s' "$reason" | grep -q '複製這個指令，自己在 terminal 執行' && ok=1 ;;
    deny-attr) [ "$dec" = deny ] && printf '%s' "$reason" | grep -q '^commit attribution guard' && ok=1 ;;
  esac
  [ "$(printf '%s' "$out" | jq -r 'has("hookSpecificOutput")' 2>/dev/null)" = true ] && ok=0
  [ $ok = 1 ] || { echo "FAIL agy_tier_$1 expect=$2 out=$out"; fail=1; }
}
rf() { jq -cn --arg p "$1" --arg d "${2:-/tmp/work}" '{conversationId:"c",cwd:$d,toolCall:{name:"read_file",args:{Path:$p,StartLine:1,EndLine:50}}}'; }
W=/home/miyago/dotfile
# Tier 1 放行：基本檔案操作與版控（不跑 git-add-guard）
tier git_add_all allow "$(agy 'git add -A' "$W")"
tier git_add_dot allow "$(agy 'git add .' "$W")"
tier git_commit allow "$(agy 'git commit -m x' "$W")"
tier git_push allow "$(agy 'git push origin main' "$W")"
tier git_chain allow "$(agy 'git add -A && git commit -m "fix: x" && git push origin main' "$W")"
tier rm_rf_node_modules allow "$(agy 'rm -rf node_modules' "$W")"
tier rm_file allow "$(agy 'rm file.txt' "$W")"
tier mv_cp_sed allow "$(agy 'mv a.txt b.txt && cp b.txt c.txt && sed -i s/a/b/ c.txt' "$W")"
tier npm_bun_install allow "$(agy 'npm install && bun install' "$W")"
tier git_status allow "$(agy 'git status' "$W")"
# Tier 2 force_ask：讀出憑證或 secret
tier cat_ssh_key force_ask "$(agy 'cat ~/.ssh/id_rsa' "$W")"
tier base64_agent_secret force_ask "$(agy 'base64 ~/.config/agent-secret/secrets.env' "$W")"
tier gcloud_token force_ask "$(agy 'gcloud auth print-access-token' "$W")"
tier read_file_home_ssh force_ask "$(rf "$HOME/.ssh/id_rsa")"
tier read_file_tilde force_ask "$(rf '~/.ssh/id_rsa')"
tier read_file_dollar_home force_ask "$(rf '$HOME/.aws/credentials')"
tier read_file_brace_home force_ask "$(rf '${HOME}/.kube/config')"
tier read_file_agent_secret force_ask "$(rf "$HOME/.config/agent-secret/secrets.env")"
tier read_file_dotfile_secrets force_ask "$(rf "$HOME/dotfile/secrets/agent.enc.yaml")"
tier read_file_quote_in_name force_ask "$(rf "$HOME/.ssh/it's_key")"
tier read_file_relative_in_home force_ask "$(rf '.ssh/id_rsa' "$HOME")"
tier read_file_lowercase_key force_ask "$(jq -cn --arg p "$HOME/.ssh/id_rsa" '{cwd:"/tmp",toolCall:{name:"read_file",args:{path:$p}}}')"
n=$((n + 1))
out=$(rf /home/miyago/.ssh/id_rsa | HOME=/home/miyago bash "$ADAPTER" --host agy 2>/dev/null)
[ "$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)" = force_ask ] || { echo "FAIL agy_tier_read_file_literal_home out=$out"; fail=1; }
tier read_file_pubkey allow "$(rf "$HOME/.ssh/id_ed25519.pub")"
tier read_file_ssh_config allow "$(rf "$HOME/.ssh/config")"
tier read_file_repo allow "$(rf /home/miyago/dotfile/README.md)"
tier read_file_repo_relative allow "$(rf config/ai/gemini/hooks.json "$W")"
tier read_file_no_path allow "$(jq -cn '{toolCall:{name:"read_file",args:{CommandLine:"cat ~/.ssh/id_rsa"}}}')"
# Path 不是指令：分號、$() 與 rm -rf 都只是檔名的一部分
tier read_file_path_injection allow "$(rf '/tmp/x; cat ~/.ssh/id_rsa; rm -rf /home/miyago/Project')"
tier read_file_path_subst allow "$(rf '/tmp/$(cat ~/.ssh/id_rsa)')"
# Tier 3 deny：不可逆或 prod 寫入，請 Miyago 自己執行
tier force_push deny-copy "$(agy 'git push --force origin main' "$W")"
tier delete_remote_branch deny-copy "$(agy 'git push origin --delete feature' "$W")"
tier rm_rf_outside deny-copy "$(agy 'rm -rf /home/miyago/Project' "$W")"
tier sudo_apt deny-copy "$(agy 'sudo apt install x' "$W")"
prod_ctx=$(printf '%s-%s' prod cluster)
tier kubectl_prod_delete deny-copy "$(agy "kubectl --context=$prod_ctx delete deployment api -n web" "$W")"
tier psql_drop deny-copy "$(agy 'psql -c "DROP TABLE users"' "$W")"
# 專案內的絕對路徑 rm：改寫成相對路徑後交給 destructive-guard；cwd 本身、跳出 cwd、混合、$HOME 當 cwd 仍 deny
tier rm_rf_abs_in_cwd allow "$(agy 'rm -rf /home/miyago/dotfile/build' "$W")"
tier rm_rf_abs_in_cwd_quoted allow "$(agy 'rm -rf "/home/miyago/dotfile/build" /home/miyago/dotfile/dist/' "$W")"
tier rm_rf_abs_in_args_cwd allow "$(jq -cn '{cwd:"/tmp/other",toolCall:{name:"run_command",args:{CommandLine:"rm -rf /home/miyago/dotfile/build",Cwd:"/home/miyago/dotfile"}}}')"
tier rm_rf_abs_then_cmd allow "$(agy 'rm -rf /home/miyago/dotfile/build; ls' "$W")"
tier rm_rf_cwd_itself deny-copy "$(agy 'rm -rf /home/miyago/dotfile' "$W")"
tier rm_rf_cwd_itself_slash deny-copy "$(agy 'rm -rf /home/miyago/dotfile/' "$W")"
tier rm_rf_cwd_dot deny-copy "$(agy 'rm -rf /home/miyago/dotfile/.' "$W")"
tier rm_rf_dotdot_escape deny-copy "$(agy 'rm -rf /home/miyago/dotfile/../Project' "$W")"
tier rm_rf_mixed deny-copy "$(agy 'rm -rf /home/miyago/dotfile/build /home/miyago/Project' "$W")"
tier rm_rf_dotgit deny-copy "$(agy 'rm -rf /home/miyago/dotfile/.git' "$W")"
tier rm_rf_glob deny-copy "$(agy 'rm -rf /home/miyago/dotfile/*' "$W")"
tier rm_rf_cd_elsewhere deny-copy "$(agy 'cd /home/miyago/Project && rm -rf /home/miyago/dotfile/build ../x' "$W")"
tier rm_rf_cwd_home deny-copy "$(agy "rm -rf $HOME/x" "$HOME")"
tier rm_rf_cwd_home_tilde deny-copy "$(agy 'rm -rf ~/x' "$HOME")"
tier rm_rf_cwd_parent_of_home deny-copy "$(agy "rm -rf $HOME/x" "$(dirname "$HOME")")"
tier rm_rf_cwd_root deny-copy "$(agy 'rm -rf /home/miyago/x' /)"
tier rm_rf_cwd_relative deny-copy "$(agy 'rm -rf /home/miyago/dotfile/build' dotfile)"
tier rm_rf_in_cwd_and_force_push deny-copy "$(agy 'rm -rf /home/miyago/dotfile/build && git push -f origin main' "$W")"
tier rm_rf_in_cwd_and_secret force_ask "$(agy 'rm -rf /home/miyago/dotfile/build && cat ~/.ssh/id_rsa' "$W")"
# commit attribution：保留原 reason，讓 agy 改寫 message
trailer=$(printf '%s-%s-%s: Bot <bot@example.com>' Co Authored By)
tier commit_attribution deny-attr "$(agy "git commit -m \"fix: x

$trailer\"" "$W")"
# 多級同時命中：取最嚴格
tier secret_and_force_push deny-copy "$(agy 'cat ~/.ssh/id_rsa && git push --force origin main' "$W")"
tier secret_and_attribution deny-attr "$(agy "cat ~/.ssh/id_rsa; git commit -m \"$trailer\"" "$W")"
tier git_add_all_and_secret force_ask "$(agy 'git add -A && cat ~/.aws/credentials' "$W")"

# codex / opencode：同一組指令維持原本只看 secret-guard 的行為（git add -A、force push、sudo 都不擋）
for h in codex opencode; do
  mk=$h; [ "$h" = opencode ] && mk=oc
  i=0
  for c in 'git add -A' 'git push --force origin main' 'rm -rf /home/miyago/Project' 'sudo apt install x' \
    "kubectl --context=$prod_ctx delete deployment api" "git commit -m \"$trailer\""; do
    i=$((i + 1))
    check "${h}_unchanged_none_$i" "$h" none "$($mk "$c" "$W")"
  done
  check "${h}_unchanged_ssh_read" "$h" deny "$($mk 'cat ~/.ssh/id_rsa' "$W")"
  check "${h}_unchanged_secret_and_force_push" "$h" deny "$($mk 'cat ~/.ssh/id_rsa && git push --force origin main' "$W")"
  # agy 的 read_file 形狀不屬於 codex / opencode
  check "${h}_read_file_shape" "$h" none "$(rf "$HOME/.ssh/id_rsa")"
done

# agy：secret guard 回 ask 也是 force_ask；codex / opencode 不轉交 ask
printf '#!/bin/bash\ncat >/dev/null\necho %s\n' \
  "'{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"fake ask\"}}'" > "$tmp/ask-guard.sh"
printf '#!/bin/bash\ncat >/dev/null\necho %s\n' \
  "'{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":{\"command\":\"yes | x\"}},\"systemMessage\":\"m\"}'" > "$tmp/allow-upd-guard.sh"
n=$((n + 1))
out=$(agy 'x' | SECRET_GUARD="$tmp/ask-guard.sh" bash "$ADAPTER" --host agy 2>/dev/null)
{ [ "$(printf '%s' "$out" | jq -r '.decision // empty')" = force_ask ] && printf '%s' "$out" | jq -r '.reason' | grep -q '^fake ask'; } \
  || { echo "FAIL agy_fake_ask_to_force_ask out=$out"; fail=1; }
for h in codex opencode; do
  n=$((n + 1)); mk=$h; [ "$h" = opencode ] && mk=oc
  out=$($mk 'x' | SECRET_GUARD="$tmp/ask-guard.sh" bash "$ADAPTER" --host "$h" 2>/dev/null)
  [ -z "$out" ] || { echo "FAIL ${h}_ask_not_forwarded out=$out"; fail=1; }
done
n=$((n + 1))
out=$(agy 'x' | SECRET_GUARD="$tmp/allow-upd-guard.sh" bash "$ADAPTER" --host agy 2>/dev/null)
[ -z "$out" ] || { echo "FAIL agy_allow_updated_input_ignored out=$out"; fail=1; }

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
