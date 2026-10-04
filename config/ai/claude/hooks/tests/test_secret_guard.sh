#!/usr/bin/env bash
# secret-guard.sh 的回歸測試：會把本機憑證印進 context 的 CLI 子指令回 deny，其餘無輸出。
# 指令只以 JSON 字串餵給 hook，不會被執行。HOOK 可用環境變數覆寫（teeth check 用）。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/secret-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0; n=0
run() { # name expect(deny|none) command
  n=$((n + 1))
  out=$(jq -n --arg c "$3" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null); rc=$?
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  text=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
  ok=0
  if [ "$2" = none ]; then [ -z "$out" ] && ok=1; else [ "$dec" = "$2" ] && printf '%s' "$text" | grep -q 'secret-guard' && ok=1; fi
  [ $rc = 0 ] || ok=0
  [ $ok = 1 ] || { echo "FAIL $1 expect=$2 rc=$rc dec=$dec out=$out"; fail=1; }
}

# --- 被攔：kubectl config view --raw / --flatten ---
run kube_raw deny 'kubectl config view --raw'
run kube_flatten deny 'kubectl config view --flatten'
run kube_raw_minify deny 'kubectl config view --minify --raw -o yaml'
run kube_raw_before_view deny 'kubectl config --raw view'
run kube_raw_eq_true deny 'kubectl config view --raw=true'
run kube_extra_spaces deny 'kubectl   config   view   --raw'
run kube_global_flag deny 'kubectl --context x config view --raw'
run kube_global_flag_eq deny 'kubectl --kubeconfig=/tmp/k -n kube-system config view --flatten'
run kube_full_path deny '/usr/local/bin/kubectl config view --raw'
run kube_env_prefix deny 'KUBECONFIG=x kubectl config view --raw'
run kube_two_env_prefix deny 'A=1 KUBECONFIG="/tmp/a b" kubectl config view --flatten'
run kube_after_semicolon deny 'kubectl get pods; kubectl config view --raw'
run kube_after_and deny 'cd repo && kubectl config view --raw'
run kube_after_or deny 'false || kubectl config view --flatten'
run kube_piped deny 'kubectl config view --raw | grep token'
run kube_pipe_rhs deny 'echo x | kubectl config view --raw'
run kube_newline deny $'kubectl get pods\nkubectl config view --raw'
run kube_after_comment_apostrophe deny $'# don\'t leak\nkubectl config view --raw'
run kube_redirect deny 'kubectl config view --raw > /tmp/k.yaml 2>&1'
run kube_subshell deny '(kubectl config view --raw)'
run kube_cmd_subst deny 'x=$(kubectl config view --raw)'
run kube_cmd_subst_in_dquote deny 'echo "cfg: $(kubectl config view --raw)"'
run kube_backtick deny 'echo `kubectl config view --flatten`'
run kube_quoted_flag deny 'kubectl config view "--raw"'
run kube_command_wrapper deny 'command kubectl config view --raw'
run kube_env_wrapper deny 'env KUBECONFIG=x kubectl config view --raw'
run kube_if_keyword deny 'if kubectl config view --raw; then echo ok; fi'

# --- 被攔：gcloud auth print-*-token ---
run gcloud_access deny 'gcloud auth print-access-token'
run gcloud_identity deny 'gcloud auth print-identity-token'
run gcloud_adc deny 'gcloud auth application-default print-access-token'
run gcloud_access_trailing_flag deny 'gcloud auth print-access-token --impersonate-service-account=sa@p.iam.gserviceaccount.com'
run gcloud_identity_audiences deny 'gcloud auth print-identity-token --audiences=https://x.run.app'
run gcloud_global_flag_eq deny 'gcloud --project=p auth print-access-token'
run gcloud_global_flag_space deny 'gcloud --project p --quiet auth print-identity-token'
run gcloud_adc_global_flag deny 'gcloud --project=p auth application-default print-access-token'
run gcloud_beta deny 'gcloud beta auth print-access-token'
run gcloud_full_path deny '/opt/homebrew/bin/gcloud auth print-access-token'
run gcloud_env_prefix deny 'CLOUDSDK_CORE_PROJECT=p gcloud auth print-access-token'
run gcloud_after_and deny 'gcloud config list && gcloud auth print-access-token'
run gcloud_after_or deny 'true || gcloud auth application-default print-access-token'
run gcloud_after_semicolon deny 'ls; gcloud auth print-identity-token'
run gcloud_piped deny 'gcloud auth print-access-token | pbcopy'
run gcloud_in_curl_header deny 'curl -H "Authorization: Bearer $(gcloud auth print-access-token)" https://x'
run gcloud_assign_subst deny 'TOKEN=$(gcloud auth print-access-token)'

# --- 放行：唯讀且不印憑證 ---
run kube_config_view none 'kubectl config view'
run kube_config_view_minify none 'kubectl config view --minify -o jsonpath={.clusters[0].name}'
run kube_raw_false none 'kubectl config view --raw=false'
run kube_current_context none 'kubectl config current-context'
run kube_get_contexts none 'kubectl config get-contexts'
run kube_get_raw_api none 'kubectl get --raw /healthz'
run gcloud_config_list none 'gcloud config list'
run gcloud_auth_list none 'gcloud auth list'
run gcloud_auth_login none 'gcloud auth application-default login'
run plain_ls none 'ls -la'

# --- 放行：Miyago 決定不擋的指令 ---
run kube_get_secret none 'kubectl get secret'
run kube_describe_secret none 'kubectl describe secret'
run kube_get_secret_yaml none 'kubectl get secret x -o yaml'
run gcloud_secrets_access none 'gcloud secrets versions access latest --secret=x'
run sops_version none 'sops --version'
run sops_encrypt none 'sops -e f'
run sops_decrypt none 'sops -d f'
run sops_decrypt_long none 'sops --decrypt f'
run sops_exec_env none 'sops exec-env f env'

# --- near-miss：只是字串提及，不會執行 ---
run mention_echo_dquote none 'echo "kubectl config view --raw"'
run mention_echo_squote none "echo 'gcloud auth print-access-token'"
run mention_echo_bare none 'echo kubectl config view --raw'
run mention_commit_msg none 'git commit -m "docs: never run gcloud auth print-access-token"'
run mention_commit_msg_adc none "git commit -m 'block gcloud auth application-default print-access-token'"
run mention_grep none 'grep -rn "config view --flatten" docs/'
run mention_separator_in_quote none 'echo "a; kubectl config view --raw"'
run mention_subst_in_squote none 'echo '"'"'$(gcloud auth print-access-token)'"'"''
run mention_comment none 'ls # kubectl config view --raw'
run mention_in_path none 'cat docs/kubectl-config-view-raw.md'
run other_tool_same_args none 'mykubectl config view --raw'

# GAP: heredoc 內文逐行當成指令看，寫進檔案的說明文字也會被攔（誤攔）
run heredoc_body deny $'cat <<EOF > notes.md\nkubectl config view --raw\nEOF'
# GAP: 只認字面的 kubectl / gcloud 執行檔名，變數、alias 展開後才是 kubectl 的寫法放行
run kube_via_variable none '$KUBECTL config view --raw'
run kube_alias none 'k config view --raw'
# GAP: 字串交給另一個 shell / xargs / eval 執行時看不到（主動規避，non-goal）
run kube_bash_c none 'bash -c "kubectl config view --raw"'
run kube_xargs none 'echo --raw | xargs kubectl config view'
run gcloud_eval none 'eval "gcloud auth print-access-token"'
# GAP: env 帶值選項（-u NAME）後面的執行檔取不到，放行
run kube_env_u none 'env -u FOO kubectl config view --raw'

# --- 空輸入 ---
run empty_command none ''
for raw in '{"tool_input":{}}' 'not json'; do # stdin 不是預期格式：無輸出、exit 0
  n=$((n + 1))
  out=$(printf '%s' "$raw" | bash "$HOOK" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL raw_input '$raw' rc=$rc out=$out"; fail=1; }
done

# --- 缺 jq：fail-open（PATH 指到空目錄，bash 用絕對路徑）---
n=$((n + 1))
bash_bin=$(command -v bash); jq_bin=$(command -v jq)
out=$("$jq_bin" -n --arg c 'gcloud auth print-access-token' '{tool_input:{command:$c}}' | PATH="$tmp" "$bash_bin" "$HOOK" 2>/dev/null); rc=$?
{ [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL no_jq_fail_open rc=$rc out=$out"; fail=1; }

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
