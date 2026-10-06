#!/usr/bin/env bash
# ops-write-guard.sh 的回歸測試：Tier 1 在 production（或無法確認 context）回 deny、非 production 回 ask，
# Tier 2/3、bypass 與 gcloud 的行為也在這裡。已知還存在的漏洞以 GAP 標註。
# kubectl / gcloud 都用 PATH 前置的 stub：kubectl 只回應 `config current-context`（值由 STUB_CTX 控制，
# `!fail` 代表指令失敗），其他呼叫或任何 gcloud 呼叫都會留下記號，結尾檢查沒有被碰過。
# 危險指令只以 JSON 字串餵給 hook，不會被執行。HOOK 可用環境變數覆寫（teeth check 用）。
# shellcheck disable=SC2016  # 測試指令是刻意不展開的字面字串
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/ops-write-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
BASH_BIN=$(command -v bash)
T=$(mktemp -d); trap '/bin/rm -rf "$T"' EXIT
mkdir "$T/bin" "$T/nokube"
cat >"$T/bin/kubectl" <<EOF
#!/bin/sh
if [ "\$*" = "config current-context" ]; then
  [ "\${STUB_CTX:-}" = "!fail" ] && exit 1
  printf '%s\n' "\${STUB_CTX:-}"; exit 0
fi
touch "$T/kubectl_unexpected"; exit 97
EOF
cat >"$T/bin/gcloud" <<EOF
#!/bin/sh
touch "$T/gcloud_called"; exit 97
EOF
chmod +x "$T/bin/kubectl" "$T/bin/gcloud"
# 沒有 kubectl 的 PATH：只放 hook 會用到的工具
for tool in jq awk grep sed tr cat head cut; do
  p=$(command -v "$tool") && ln -s "$p" "$T/nokube/$tool"
done
export PATH="$T/bin:$PATH"

fail=0; n=0
RUN_PATH=$PATH
run() { # name expect(ask|deny|allow|msg|none) ctx(stub 回傳的 current-context；空字串或 !fail 代表取不到) command [輸出子字串]
  n=$((n + 1))
  out=$(jq -n --arg c "$4" '{tool_input:{command:$c}}' | PATH="$RUN_PATH" STUB_CTX="$3" "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  text=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // .systemMessage // empty' 2>/dev/null)
  ok=0
  case "$2" in
    none) [ -z "$out" ] && ok=1 ;;
    msg) [ -z "$dec" ] && [ -n "$text" ] && ok=1 ;; # 只有 systemMessage、不做決定
    *) [ "$dec" = "$2" ] && ok=1 ;;
  esac
  [ $rc = 0 ] || ok=0
  if [ $ok = 1 ] && [ -n "${5:-}" ] && ! printf '%s' "$text" | grep -qF -- "$5"; then ok=0; fi
  [ $ok = 1 ] || { echo "FAIL $1 expect=$2 rc=$rc dec=$dec out=$out"; fail=1; }
}
PROD=gke_proj_asia_production-cluster
DEV=gke_proj_asia_staging-cluster

# --- Tier 1：production deny，非 production ask ---
for v in 'delete pod web-1' 'drain node-1 --ignore-daemonsets' 'cordon node-1' 'uncordon node-1' \
  'replace -f x.yaml' 'taint nodes n1 k=v:NoSchedule'; do
  name=${v%% *}
  run "t1_prod_$name" deny "$PROD" "kubectl $v" "kubectl $name"
  run "t1_dev_$name" ask "$DEV" "kubectl $v" "$name"
done
run t1_delete_dev ask "$DEV" 'kubectl delete pod web-1' 'Tier 1'
run t1_delete_prod deny "$PROD" 'kubectl delete pod web-1' "context=$PROD"
run t1_deny_reason_tier deny "$PROD" 'kubectl delete pod web-1' 'Tier 1'
run t1_deny_reason_who deny "$PROD" 'kubectl delete pod web-1' 'Miyago'
run t1_deny_reason_where deny "$PROD" 'kubectl delete pod web-1' 'terminal'
run t1_deny_reason_bypass deny "$PROD" 'kubectl delete pod web-1' 'SRE_GUARD_BYPASS'
run t1_ns_flag_before_verb ask "$DEV" 'kubectl -n kube-system delete pod x' 'ns=kube-system'
run t1_ns_flag_long_eq ask "$DEV" 'kubectl --namespace=app delete pod x' 'ns=app'
run t1_ns_flag_after ask "$DEV" 'kubectl delete pod x -n app' 'ns=app'
run t1_prod_ns_label deny "$PROD" 'kubectl -n app delete pod x' 'ns=app'
run t1_inline_context_eq ask "$DEV" 'kubectl delete pod x --context=other' 'context=other'
run t1_inline_context_space ask "$DEV" 'kubectl --context other delete pod x' 'context=other'
run t1_inline_prod_beats_stub deny "$DEV" "kubectl delete pod x --context=$PROD" "context=$PROD"
run t1_inline_dev_beats_stub ask "$PROD" 'kubectl --context staging delete pod x' 'context=staging'
run t1_after_semicolon ask "$DEV" 'cd r; kubectl delete pod x' 'Tier 1'
run t1_after_and ask "$DEV" 'true && kubectl delete pod x' 'Tier 1'
run t1_sudo_prefix ask "$DEV" 'sudo kubectl delete pod x' 'Tier 1'

# --- Tier 1：無法確認 context 時視為 production（fail closed）---
run t1_delete_no_ctx deny '' 'kubectl delete pod web-1' 'context=<unknown>'
run t1_ctx_command_fails deny '!fail' 'kubectl delete pod web-1' 'context=<unknown>'
RUN_PATH="$T/nokube"
run t1_no_kubectl_binary deny "$DEV" 'kubectl delete pod web-1' 'context=<unknown>'
run t1_no_kubectl_inline_ctx ask "$DEV" 'kubectl --context staging delete pod x' 'context=staging'
RUN_PATH=$PATH
run t1_context_from_variable deny "$DEV" 'kubectl --context "$CTX" delete pod x' 'context=<unknown>'
run t1_context_from_subst deny "$DEV" 'kubectl --context=$(pick) delete pod x' 'context=<unknown>'
# 指令自己改了連到哪個 cluster，current-context 就不能信
run t1_server_flag deny "$DEV" 'kubectl --server https://k.example delete pod x' 'context=<unknown>'
run t1_server_flag_eq deny "$DEV" 'kubectl delete pod x --server=https://k.example' 'context=<unknown>'
run t1_server_short_flag deny "$DEV" 'kubectl -s https://k.example delete pod x' 'context=<unknown>'
run t1_cluster_flag deny "$DEV" 'kubectl --cluster other delete pod x' 'context=<unknown>'
run t1_kubeconfig_flag deny "$DEV" 'kubectl --kubeconfig /x/cfg delete pod x' 'context=<unknown>'
run t1_kubeconfig_flag_with_ctx ask "$DEV" 'kubectl --kubeconfig /x/cfg --context staging delete pod x' 'context=staging'
run t1_kubeconfig_env deny "$DEV" 'KUBECONFIG=/x/cfg kubectl delete pod x' 'context=<unknown>'
run t1_kubeconfig_export deny "$DEV" 'export KUBECONFIG=/x/cfg; kubectl delete pod x' 'context=<unknown>'
# 同一條指令先切 context 再動手：以切過去的目標為準，原本在 production 也照擋
run t1_use_context_prod_then_delete deny "$DEV" "kubectl config use-context $PROD && kubectl delete pod x" "context=$PROD"
run t1_use_context_dev_then_delete ask "$DEV" 'kubectl config use-context staging && kubectl delete pod x' 'context=staging'
run t1_use_context_dev_but_current_prod deny "$PROD" 'kubectl config use-context staging; kubectl delete pod x' 'Tier 1'
run t1_use_context_variable_then_delete deny "$DEV" 'kubectl config use-context "$C" && kubectl delete pod x' 'context=<unknown>'
run t1_set_current_context_then_delete deny "$DEV" 'kubectl config set current-context x && kubectl delete pod x' 'context=<unknown>'
run t1_kubectx_prod_then_delete deny "$DEV" 'kubectx gke_proj_prod-cluster && kubectl delete pod x' 'context=gke_proj_prod-cluster'
run t1_kubectx_dev_then_delete ask "$DEV" 'kubectx staging && kubectl delete pod x' 'context=staging'
run t1_get_credentials_then_delete deny "$DEV" 'gcloud container clusters get-credentials c1 --project=p1 && kubectl delete pod x' 'context=<unknown>'

# --- production 名稱的判斷：production 字樣，或以非字母隔開的 prod / prd ---
for c in production GKE_PRODUCTION my-production-eu gke_proj_prod-cluster foo-prd prod prd PRD_main \
  a.prod.b prod2 x-prod_y gke_p_asia-east1_prod; do
  run "prod_name_yes_$c" deny "$c" 'kubectl delete pod x' "context=$c"
  run "prod_name_yes_inline_$c" deny "$DEV" "kubectl --context $c delete pod x" "context=$c"
done
for c in product-dev reproduce-cluster my-products producer-dev sprdx prdx staging dev gke_proj_asia_staging-cluster; do
  run "prod_name_no_$c" ask "$c" 'kubectl delete pod x' "context=$c"
done
# 帶否定或前置詞的名稱不算 production
for c in non-prod nonprod non-production nonproduction pre-prod preprod not-prod acme-non-prod gke_x_nonproduction \
  GKE_Non_Prod acme-preprod-1 non.prd; do
  run "prod_name_negated_$c" ask "$c" 'kubectl delete pod x' "context=$c"
done
run prod_name_negated_gcloud ask '' 'gcloud compute instances delete vm --project=acme-non-prod' 'project=acme-non-prod'
# 否定詞要是獨立的詞，而且只抵銷緊接在後面的那一個
run prod_name_prd_tools deny 'prd-tools' 'kubectl delete pod x' 'context=prd-tools'
run prod_name_canon_prod deny 'canon-prod' 'kubectl delete pod x' 'context=canon-prod'
run prod_name_nonprod_then_prod deny 'nonprod-to-prod' 'kubectl delete pod x' 'Tier 1'
# 名稱比對的已知限制：prod 黏在其他字母後面（acmeprod、prodcluster）認不出來
run prod_name_glued_not_detected ask 'acmeprod' 'kubectl delete pod x' 'context=acmeprod'

# --- 不會改變任何東西的指令：不擋也不問 ---
run noop_dry_run_client_prod none "$PROD" 'kubectl delete pod x --dry-run=client'
run noop_dry_run_server_prod none "$PROD" 'kubectl delete pod x --dry-run=server'
run noop_dry_run_legacy_prod none "$PROD" 'kubectl delete pod x --dry-run'
run noop_dry_run_before_verb none "$PROD" 'kubectl --dry-run=client delete pod x'
run noop_dry_run_apply_prod none "$PROD" 'kubectl apply -f x.yaml --dry-run=server'
run noop_dry_run_no_ctx none '' 'kubectl delete pod x --dry-run=client'
run noop_help_prod none "$PROD" 'kubectl delete --help'
run noop_help_short_prod none "$PROD" 'kubectl drain -h'
run noop_gcloud_help none '' 'gcloud compute instances delete --help'
run noop_gcloud_help_short none '' 'gcloud sql instances delete -h'
# --dry-run=none 等於沒有 dry-run；exec 的 -- 後面的 --help 是 pod 內指令的參數
run noop_dry_run_none_is_real deny "$PROD" 'kubectl delete pod x --dry-run=none' 'kubectl delete'
run noop_dry_run_only_covers_own_command deny "$PROD" 'kubectl delete pod x --dry-run=client && kubectl delete pod y' 'kubectl delete'
run noop_help_after_double_dash msg "$PROD" 'kubectl exec web-1 -- ls --help' 'context-sensitive'

# --- 無法判斷 context 時的 deny：reason 要講明原因並建議 --context ---
run unk_reason_kubeconfig_env deny "$DEV" 'KUBECONFIG=~/.kube/dev.yaml kubectl delete pod x' '無法判斷 context'
run unk_reason_suggests_context deny "$DEV" 'KUBECONFIG=~/.kube/dev.yaml kubectl delete pod x' '--context <名稱>'
run unk_reason_kubeconfig_flag deny "$DEV" 'kubectl --kubeconfig ~/.kube/dev.yaml delete pod x' '--context <名稱>'
run unk_reason_ctx_variable deny "$DEV" 'kubectl --context "$DEV_CTX" delete pod x' '無法判斷 context'
run unk_reason_no_current deny '!fail' 'kubectl delete pod x' '--context <名稱>'
run unk_fixed_by_explicit_context ask "$DEV" 'KUBECONFIG=~/.kube/dev.yaml kubectl --context dev delete pod x' 'context=dev'
run unk_two_different_contexts deny "$DEV" 'kubectl --context dev delete pod x --context staging' '無法判斷 context'
run unk_two_contexts_one_prod deny "$DEV" 'kubectl --context dev delete pod x --context prod-a' 'Tier 1'
run unk_empty_context deny "$PROD" 'kubectl --context= delete pod x' '無法判斷 context'
# 在遠端或 container 裡執行：本機的 context 不適用
run unk_ssh_string deny "$DEV" "ssh bastion 'kubectl delete pod x'" '無法判斷 context'
run unk_ssh_words deny "$DEV" 'ssh bastion kubectl delete pod x' '無法判斷 context'
run unk_docker_exec deny "$DEV" 'docker exec tools kubectl delete pod x' '無法判斷 context'
run unk_ssh_explicit_context ask "$DEV" "ssh bastion 'kubectl --context staging delete pod x'" 'context=staging'
run unk_ssh_read_only none "$DEV" "ssh bastion 'kubectl get pods'"

# --- Tier 1：各種寫法都要偵測得到 ---
run t1_chained_after_get ask "$DEV" 'kubectl get pods; kubectl delete pod x' 'kubectl delete'
run t1_chained_after_get_prod deny "$PROD" 'kubectl get pods; kubectl delete pod x' 'kubectl delete'
run t1_chained_and_prod deny "$PROD" 'kubectl get pods && kubectl delete pod x' 'kubectl delete'
run t1_chained_or_prod deny "$PROD" 'kubectl get pod x || kubectl delete pod y' 'kubectl delete'
run t1_chained_pipe_prod deny "$PROD" 'kubectl get pods -o name | kubectl delete -f -' 'kubectl delete'
run t1_chained_newline_prod deny "$PROD" $'kubectl get pods\nkubectl drain node-1' 'kubectl drain'
run t1_chained_background_prod deny "$PROD" 'kubectl get pods & kubectl delete pod x' 'kubectl delete'
run t1_chained_apply_then_delete_prod deny "$PROD" 'kubectl apply -f x.yaml && kubectl delete pod x' 'kubectl delete'
run t1_as_flag ask "$DEV" 'kubectl --as admin delete pod x' 'kubectl delete'
run t1_as_flag_prod deny "$PROD" 'kubectl --as admin delete pod x' 'kubectl delete'
run t1_as_group_flag_prod deny "$PROD" 'kubectl --as-group system:masters delete pod x' 'kubectl delete'
run t1_token_flag_prod deny "$PROD" 'kubectl --token abc delete pod x' 'kubectl delete'
run t1_request_timeout_flag_prod deny "$PROD" 'kubectl --request-timeout 5s delete pod x' 'kubectl delete'
run t1_user_flag_prod deny "$PROD" 'kubectl --user admin drain node-1' 'kubectl drain'
run t1_unknown_value_flag_prod deny "$PROD" 'kubectl --some-flag value delete pod x' 'kubectl delete'
run t1_absolute_path ask "$DEV" '/usr/local/bin/kubectl delete pod x' 'kubectl delete'
run t1_absolute_path_prod deny "$PROD" '/usr/local/bin/kubectl delete pod x' 'kubectl delete'
run t1_relative_path_prod deny "$PROD" './bin/kubectl delete pod x' 'kubectl delete'
run t1_subshell ask "$DEV" '(kubectl delete pod x)' 'kubectl delete'
run t1_subshell_prod deny "$PROD" '(kubectl delete pod x)' 'kubectl delete'
run t1_subshell_cd_prod deny "$PROD" '(cd r && kubectl delete pod x)' 'kubectl delete'
run t1_cmd_subst_prod deny "$PROD" 'x=$(kubectl delete pod x)' 'kubectl delete'
run t1_cmd_subst_in_quotes_prod deny "$PROD" 'echo "$(kubectl delete pod x)"' 'kubectl delete'
run t1_backticks_prod deny "$PROD" 'echo `kubectl delete pod x`' 'kubectl delete'
run t1_brace_group_prod deny "$PROD" '{ kubectl delete pod x; }' 'kubectl delete'
run t1_if_condition_prod deny "$PROD" 'if kubectl delete pod x; then echo ok; fi' 'kubectl delete'
run t1_for_loop_prod deny "$PROD" 'for p in a b; do kubectl delete pod $p; done' 'kubectl delete'
run t1_negated_prod deny "$PROD" '! kubectl delete pod x' 'kubectl delete'
run t1_shell_dash_c_prod deny "$PROD" 'bash -c "kubectl delete pod x"' 'kubectl delete'
run t1_shell_dash_c_chained_prod deny "$PROD" "sh -c 'cd r && kubectl delete pod x'" 'kubectl delete'
run t1_eval_prod deny "$PROD" 'eval kubectl delete pod x' 'kubectl delete'
run t1_xargs_prod deny "$PROD" 'kubectl get pods -o name | xargs kubectl delete' 'kubectl delete'
run t1_xargs_flags_prod deny "$PROD" 'cat pods.txt | xargs -n1 kubectl delete pod' 'kubectl delete'
run t1_sudo_user_prod deny "$PROD" 'sudo -u ops kubectl delete pod x' 'kubectl delete'
run t1_env_prefix_prod deny "$PROD" 'env FOO=1 kubectl delete pod x' 'kubectl delete'
run t1_assignment_prefix_prod deny "$PROD" 'FOO=1 kubectl delete pod x' 'kubectl delete'
run t1_time_prefix_prod deny "$PROD" 'time kubectl delete pod x' 'kubectl delete'
run t1_timeout_prefix_prod deny "$PROD" 'timeout 30 kubectl delete pod x' 'kubectl delete'
run t1_quoted_binary_prod deny "$PROD" '"kubectl" delete pod x' 'kubectl delete'
run t1_backslash_binary_prod deny "$PROD" '\kubectl delete pod x' 'kubectl delete'
run t1_quoted_verb_prod deny "$PROD" "kubectl 'delete' pod x" 'kubectl delete'
run t1_heredoc_to_shell_prod deny "$PROD" $'bash <<EOF\nkubectl delete pod x\nEOF' 'kubectl delete'
run t1_exec_inner_kubectl_prod deny "$PROD" 'kubectl exec ops-0 -- kubectl delete pod x' 'kubectl delete'
run t1_exec_inner_shell_prod deny "$PROD" 'kubectl exec ops-0 -- sh -c "kubectl delete pod x"' 'kubectl delete'
run t1_after_redirect_prod deny "$PROD" 'kubectl get pods 2>&1 >/dev/null; kubectl delete pod x' 'kubectl delete'
run t1_ctx_plugin_prod ask "$DEV" "kubectl ctx $PROD" 'PRODUCTION cluster'
# 開頭的指令不在「明確不執行」清單內，只要有 kubectl 這個 word 就當成會執行（不靠包裝指令白名單）
for w in 'op run --' 'mise exec --' 'setsid' 'noglob' 'coproc' 'stdbuf -oL' 'watch -n 5' 'some-unknown-wrapper --flag v' \
  'nohup' 'command' 'doppler run --'; do
  name=$(printf '%s' "$w" | tr -c 'a-zA-Z0-9\n' '_')
  run "wrap_t1_prod_$name" deny "$PROD" "$w kubectl delete pod x" 'kubectl delete'
  run "wrap_t1_dev_$name" ask "$DEV" "$w kubectl delete pod x" 'kubectl delete'
  run "wrap_t2_prod_$name" ask "$PROD" "$w kubectl apply -f a.yaml" 'Tier 2 mutating on PRODUCTION'
  run "wrap_t0_prod_$name" none "$PROD" "$w kubectl get pods"
done
run wrap_docker_image_t2_prod ask "$PROD" 'docker run --rm -v ~/.kube:/root/.kube bitnami/kubectl apply -f a.yaml' 'Tier 2 mutating on PRODUCTION'
run wrap_docker_exec_t1_prod deny "$PROD" 'docker exec tools kubectl delete pod x' 'kubectl delete'
run wrap_find_exec_prod deny "$PROD" "find . -name '*.yaml' -exec kubectl delete -f {} \\;" 'kubectl delete'
run wrap_gcloud_unknown deny '' 'op run -- gcloud compute instances delete vm1' 'gcloud destructive'
run wrap_kubecolor_prod deny "$PROD" 'kubecolor delete pod x' 'kubectl delete'
run fn_keyword_body_prod deny "$PROD" 'function f { kubectl delete pod x; }; f' 'kubectl delete'
run fn_parens_body_prod deny "$PROD" 'f() { kubectl delete pod x; }; f' 'kubectl delete'
run fn_keyword_body_t2_prod ask "$PROD" 'function f { kubectl apply -f a.yaml; }; f' 'Tier 2 mutating on PRODUCTION'
run then_else_prod deny "$PROD" 'if true; then kubectl delete pod x; else echo no; fi' 'kubectl delete'
run then_newline_prod deny "$PROD" $'if true\nthen\n  kubectl delete pod x\nfi' 'kubectl delete'
run for_newlines_prod deny "$PROD" $'for p in a b\ndo\nkubectl delete pod $p\ndone' 'kubectl delete'
run case_branch_prod deny "$PROD" 'case x in x) kubectl delete pod x;; esac' 'kubectl delete'
run while_read_prod deny "$PROD" 'cat l | while read p; do kubectl delete pod "$p"; done' 'kubectl delete'
run in_assignment_prod deny "$PROD" 'for x in 1; do :; done; in=1 kubectl delete pod x' 'kubectl delete'
run amp_redirect_prod deny "$PROD" 'kubectl delete pod x &>/dev/null' 'kubectl delete'
run proc_subst_prod deny "$PROD" 'cat x.yaml | tee >(kubectl delete -f -)' 'kubectl delete'
# $'...' 引號
run ansi_c_quote_swallow_prod deny "$PROD" "echo \$'it\\'s' ; kubectl delete pod x ; echo 'done'" 'kubectl delete'
run ansi_c_quote_swallow_t2_prod ask "$PROD" "echo \$'it\\'s' ; kubectl apply -f a.yaml ; echo 'done'" 'Tier 2'
run ansi_c_quoted_verb_prod deny "$PROD" "kubectl \$'delete' pod x" 'kubectl delete'
run ansi_c_quote_in_echo none "$PROD" "echo \$'kubectl delete pod x'"
# 印出來的字 pipe 進 shell、here-string、git alias
run echo_piped_to_shell_prod deny "$PROD" 'echo "kubectl delete pod x" | bash' 'kubectl delete'
run printf_piped_to_shell_prod deny "$PROD" "printf '%s\n' 'kubectl delete pod x' | sh" 'kubectl delete'
run echo_words_piped_to_shell_prod deny "$PROD" 'echo kubectl delete pod x | sh -s' 'kubectl delete'
run echo_piped_to_grep_prod none "$PROD" 'echo "kubectl delete pod x" | grep delete'
run here_string_to_shell_prod deny "$PROD" 'bash <<< "kubectl delete pod x"' 'kubectl delete'
run git_alias_bang_prod deny "$PROD" "git -c alias.x='!kubectl delete pod x' x" 'kubectl delete'
run gcloud_echo_piped_to_shell deny '' 'echo "gcloud projects delete p1" | bash' 'gcloud destructive'
# 指令名或 verb 來自變數、$()：無法判斷就當成 Tier 1
run dyn_binary_subst_prod deny "$PROD" '"$(which kubectl)" delete pod x' 'kubectl delete'
run dyn_binary_variable_prod deny "$PROD" 'K=kubectl; $K delete pod x' 'kubectl delete'
run dyn_binary_variable_dev ask "$DEV" '$K -n app delete pod x' 'kubectl delete'
run dyn_binary_other_tool none "$PROD" '$EDITOR notes.md'
run dyn_binary_other_verb none "$PROD" '"$BUN" run build'
run dyn_verb_subst_prod deny "$PROD" 'kubectl $(echo delete) pod x' 'Tier 1'
run dyn_verb_variable_dev ask "$DEV" 'kubectl "$ACTION" pod x' 'Tier 1'
run dyn_flags_variable_then_verb none "$PROD" 'kubectl $KFLAGS get pods'
# 不是 shell 的程式收到的字串參數不確定是不是指令：kubectl 要在開頭或已知包裝指令後面才算
run str_arg_command_shape_prod deny "$PROD" 'my-runner "kubectl delete pod x"' 'kubectl delete'
run str_arg_wrapped_prod deny "$PROD" 'my-runner "sudo kubectl delete pod x"' 'kubectl delete'
run str_arg_prose_not_executed none "$PROD" 'curl -d "after deploy, kubectl delete pod x manually" https://hooks.example/x'
run python_heredoc_prose_not_executed none "$PROD" $'python3 - <<PY\nprint("then kubectl delete pod x")\nPY'
run kubectl_word_as_path_arg none "$PROD" 'chmod +x ./bin/kubectl'
run kubectl_word_install none "$PROD" 'brew install kubectl'
run kubectl_word_download none "$PROD" 'curl -LO https://dl.k8s.io/release/v1.30.0/bin/darwin/arm64/kubectl'

# --- 不誤擋：kubectl 字樣只出現在不會執行的地方 ---
run t1_echo_not_executed none "$PROD" 'echo kubectl delete pod x'
run t1_echo_quoted_not_executed none "$PROD" 'echo "run kubectl delete pod x to clean up"'
run t1_printf_not_executed none "$PROD" "printf '%s\n' 'kubectl delete pod x'"
run t1_commit_msg_not_executed none "$PROD" 'git commit -m "docs: kubectl delete pod x; kubectl drain node"'
run t1_commit_heredoc_not_executed none "$PROD" $'git commit -m "$(cat <<\'EOF\'\ndocs: runbook\n\nkubectl delete pod x (don\'t run in prod)\nEOF\n)"'
run t1_cat_heredoc_not_executed none "$PROD" $'cat > runbook.md <<EOF\nkubectl delete pod x\nEOF'
run t1_grep_not_executed none "$PROD" 'grep -rn "kubectl delete" docs/'
run t1_rg_not_executed none "$PROD" 'rg "kubectl drain" -g "*.md"'
run t1_comment_not_executed none "$PROD" $'ls # kubectl delete pod x\nls'
run t1_gh_body_not_executed none "$PROD" 'gh pr create --title x --body "kubectl delete pod x after merge"'
run t1_jq_arg_not_executed none "$PROD" 'jq -n --arg c "kubectl delete pod x" "{c:\$c}"'
run t1_string_arg_mentions_kubectl none "$PROD" 'bun run notify "please run kubectl delete pod x"'

# --- Tier 2：production ask，非 production 只給 systemMessage ---
for v in 'apply -f x.yaml' 'patch deploy web -p {}' 'edit deploy web' 'scale deploy web --replicas=2' \
  'annotate pod x a=b' 'label pod x a=b' 'set image deploy/web c=img' 'create ns foo' \
  'rollout restart deploy/web' 'rollout undo deploy/web' 'rollout pause deploy/web' 'rollout resume deploy/web'; do
  name=$(printf '%s' "$v" | cut -d' ' -f1-2 | tr ' /' '__')
  run "t2_prod_$name" ask "$PROD" "kubectl $v" 'Tier 2 mutating on PRODUCTION'
  run "t2_dev_$name" msg "$DEV" "kubectl $v" 'Tier 2 non-prod'
done
run t2_prod_context_case_insensitive ask 'GKE_Production' 'kubectl apply -f x.yaml' 'PRODUCTION'
run t2_prod_inline_beats_stub ask "$DEV" "kubectl apply -f x.yaml --context=$PROD" "context=$PROD"
run t2_dev_inline_beats_stub msg "$PROD" 'kubectl apply -f x.yaml --context=staging' 'context=staging'
run t2_prod_context_flag_space ask "$DEV" "kubectl --context $PROD apply -f x.yaml" "context=$PROD"
run t2_no_ctx_is_non_prod msg '' 'kubectl apply -f x.yaml' 'context=<unknown>'
run t2_dev_ns_label msg "$DEV" 'kubectl apply -f x.yaml -n app' 'ns=app'
# production 的定義放寬到 prod / prd 縮寫之後的連帶結果（預期）：這些 context 的 Tier 2 與 use-context
# 由 systemMessage 變成 ask
run t2_prod_cluster_abbrev ask 'prod-cluster' 'kubectl apply -f x.yaml' 'Tier 2 mutating on PRODUCTION'
run t2_prd_underscore_abbrev ask 'gke_x_prd_1' 'kubectl rollout restart deploy/api' 'Tier 2 mutating on PRODUCTION'
run t2_nonprod_stays_msg msg 'acme-non-prod' 'kubectl apply -f x.yaml' 'Tier 2 non-prod'
run t2_prod_abbrev ask 'gke_proj_prod-cluster' 'kubectl apply -f x.yaml' 'Tier 2 mutating on PRODUCTION'
run t2_prd_abbrev ask 'foo-prd' 'kubectl apply -f x.yaml' 'Tier 2 mutating on PRODUCTION'
run t2_product_is_not_prod msg 'product-dev' 'kubectl apply -f x.yaml' 'Tier 2 non-prod'
run t2_rollout_flag_before_sub ask "$PROD" 'kubectl rollout -n app restart deploy/web' 'rollout restart'
# GAP: 會刪東西的 Tier 2 用法（apply --prune、scale --replicas=0）仍然只是 Tier 2，production 不會 deny
run t2_apply_prune_prod ask "$PROD" 'kubectl apply --prune -f x.yaml' 'Tier 2'
run t2_scale_to_zero_prod ask "$PROD" 'kubectl scale deploy web --replicas=0' 'Tier 2'

# --- Tier 3：只提示 context / namespace，不做決定（production 也一樣）---
run t3_exec_dev msg "$DEV" 'kubectl exec -it web-1 -- sh' 'context-sensitive'
run t3_exec_prod msg "$PROD" 'kubectl exec -it web-1 -- sh' "context=$PROD"
run t3_cp msg "$DEV" 'kubectl cp web-1:/a ./a' 'cp'
run t3_port_forward msg "$DEV" 'kubectl port-forward svc/web 8080:80' 'port-forward'
run t3_attach msg "$DEV" 'kubectl attach web-1' 'attach'
run t3_proxy msg "$DEV" 'kubectl proxy' 'proxy'
run t3_use_context_dev msg "$DEV" 'kubectl config use-context staging' 'use-context'
# use-context 切到 production：ask（切換本身可逆，不 deny）
run t3_use_context_prod ask "$DEV" "kubectl config use-context $PROD" 'PRODUCTION cluster'
run t3_use_context_prod_upper ask "$DEV" 'kubectl config use-context GKE_PRODUCTION' 'PRODUCTION cluster'
run t3_use_context_prod_abbrev ask "$DEV" 'kubectl config use-context gke_proj_prod-cluster' 'PRODUCTION cluster'
run t3_use_context_prd_abbrev ask "$DEV" 'kubectl config use-context foo-prd' 'PRODUCTION cluster'
run t3_use_context_product msg "$DEV" 'kubectl config use-context product-dev' 'use-context'
run t3_use_context_prod_from_prod ask "$PROD" "kubectl config use-context $PROD" 'PRODUCTION cluster'
# GAP: exec 進 pod 之後跑的非 kubectl 指令（例如刪檔）不在這支 hook 的判斷範圍
run t3_exec_destructive_inner msg "$PROD" 'kubectl exec web-1 -- rm -rf /data' 'context-sensitive'

# --- Tier 0：放行 ---
run t0_get none "$PROD" 'kubectl get pods -n production'
run t0_describe none "$PROD" 'kubectl describe pod web-1'
run t0_logs none "$PROD" 'kubectl logs web-1 -f'
run t0_current_context none "$PROD" 'kubectl config current-context'
run t0_get_contexts none "$PROD" 'kubectl config get-contexts'
run t0_rollout_status none "$PROD" 'kubectl rollout status deploy/web'
run t0_rollout_history none "$PROD" 'kubectl rollout history deploy/web'
run t0_top none "$PROD" 'kubectl top pods'
run t0_grep_mentions_kubectl none "$PROD" 'grep kubectl notes.txt'
run t0_man none "$PROD" 'man kubectl'
run t0_delete_word_in_name none "$PROD" 'kubectl get pod delete-me'
run t0_delete_word_as_flag_value none "$PROD" 'kubectl get pods -l action=delete -n delete'
run t0_get_no_ctx none '' 'kubectl get pods'
# GAP: alias（例如 k）、包了 kubectl 的 script、直譯器內的 subprocess 與 helm 都偵測不到
run t0_alias_not_detected none "$PROD" 'k delete pod x'
run t0_script_not_detected none "$PROD" './scripts/cleanup-pods.sh'
run t0_python_subprocess_not_detected none "$PROD" "python3 -c \"import subprocess; subprocess.run(['kubectl','delete','pod','x'])\""
run t0_helm_not_covered none "$PROD" 'helm uninstall web'
# GAP: 字串參數裡，不認得的包裝指令後面的 kubectl 不算（為了不誤擋通知訊息這類文字）
run t0_string_arg_unknown_wrapper none "$PROD" 'my-runner "frobnicate kubectl delete pod x"'
# 超過 64KB 的指令不做完整解析：字面命中就 ask（不放行、不 deny），而且要很快結束
big=$(printf 'ls -la /tmp/aaaa && %.0s' $(seq 1 4000))
run big_command_t1 ask "$PROD" "${big}kubectl delete pod x" '64KB'
run big_command_gcloud ask '' "${big}gcloud compute instances delete vm1" '64KB'
run big_command_plain none "$PROD" "${big}ls"
run big_command_read_only none "$PROD" "${big}kubectl get pods"
start=$(date +%s)
run big_command_300kb ask "$PROD" "$big$big$big${big}kubectl delete pod x" '64KB'
n=$((n + 1)); [ $(($(date +%s) - start)) -le 2 ] || { echo "FAIL big_command_300kb 太慢"; fail=1; }

# --- gcloud：Tier 1（destructive）一律 deny，除非 --project 明確指向非 production 專案 ---
run g1_instances_delete deny '' 'gcloud compute instances delete vm1' 'gcloud destructive'
run g1_instances_stop deny '' 'gcloud compute instances stop vm1' 'gcloud destructive'
run g1_instances_reset deny '' 'gcloud compute instances reset vm1' 'gcloud destructive'
run g1_sql_delete deny '' 'gcloud sql instances delete db1' 'gcloud destructive'
run g1_secrets_delete deny '' 'gcloud secrets delete s1' 'gcloud destructive'
run g1_projects_delete deny '' 'gcloud projects delete p1' 'gcloud destructive'
run g1_clusters_delete deny '' 'gcloud container clusters delete c1' 'gcloud destructive'
run g1_after_semicolon deny '' 'cd r; gcloud compute instances delete vm1' 'gcloud destructive'
run g1_with_kubectl_get deny "$DEV" 'gcloud compute instances delete vm1; kubectl get pods' 'gcloud destructive'
run g1_deny_reason_who deny '' 'gcloud compute instances delete vm1' 'Miyago'
run g1_deny_reason_where deny '' 'gcloud compute instances delete vm1' 'terminal'
run g1_deny_reason_project deny '' 'gcloud compute instances delete vm1' '--project'
run g1_dev_ctx_does_not_help deny "$DEV" 'gcloud compute instances delete vm1' 'gcloud destructive'
run g1_project_dev_eq ask '' 'gcloud compute instances delete vm1 --project=my-dev' 'project=my-dev'
run g1_project_dev_space ask '' 'gcloud compute instances delete vm1 --project my-dev' 'project=my-dev'
run g1_global_flag_before_group ask '' 'gcloud --project=p1 compute instances delete vm1' 'project=p1'
run g1_global_flag_space_before_group ask '' 'gcloud --project p1 compute instances delete vm1' 'project=p1'
run g1_project_product_is_not_prod ask '' 'gcloud compute instances delete vm1 --project=product-dev' 'project=product-dev'
run g1_project_production deny '' 'gcloud compute instances delete vm1 --project=acme-production' 'project=acme-production'
run g1_project_prod_abbrev deny '' 'gcloud --project my-prod compute instances delete vm1' 'project=my-prod'
run g1_project_prd_abbrev deny '' 'gcloud sql instances delete db1 --project=acme-prd' 'project=acme-prd'
run g1_project_from_variable deny '' 'gcloud compute instances delete vm1 --project="$P"' 'gcloud destructive'
run g1_project_empty deny '' 'gcloud compute instances delete vm1 --project=' 'gcloud destructive'
run g1_other_global_flags_before_group deny '' 'gcloud --quiet --format json --account a@b.c compute instances delete vm1' 'gcloud destructive'
run g1_disks_delete deny '' 'gcloud compute disks delete d1' 'gcloud destructive'
run g1_disks_delete_dev ask '' 'gcloud compute disks delete d1 --project=my-dev' 'gcloud destructive'
run g1_run_services_delete deny '' 'gcloud run services delete svc' 'gcloud destructive'
run g1_buckets_delete deny '' 'gcloud storage buckets delete gs://b' 'gcloud destructive'
run g1_storage_rm deny '' 'gcloud storage rm -r gs://b/x' 'gcloud destructive'
run g1_secret_version_destroy deny '' 'gcloud secrets versions destroy 3 --secret=s1' 'gcloud destructive'
run g1_beta_prefix deny '' 'gcloud beta compute instances delete vm1' 'gcloud destructive'
run g1_deep_group_delete deny '' 'gcloud artifacts docker images delete img' 'gcloud destructive'
run g1_absolute_path deny '' '/opt/google-cloud-sdk/bin/gcloud compute instances delete vm1' 'gcloud destructive'
run g1_subshell deny '' '(gcloud compute instances delete vm1)' 'gcloud destructive'
run g1_chained_after_list deny '' 'gcloud compute instances list && gcloud compute instances delete vm1' 'gcloud destructive'
run g1_shell_dash_c deny '' 'bash -c "gcloud compute instances delete vm1"' 'gcloud destructive'
run g1_echo_not_executed none '' 'echo gcloud compute instances delete vm1'
run g1_commit_msg_not_executed none '' 'git commit -m "gcloud compute instances delete vm1"'
run g1_local_config_delete none '' 'gcloud config configurations delete old'
run g1_delete_word_in_filter none '' 'gcloud logging read "protoPayload.methodName:delete"'
# GAP: 不叫 delete / destroy 的破壞性操作（例如 sql instances patch、clusters resize）仍是 Tier 2 以下
run g1_cluster_resize_not_covered none '' 'gcloud container clusters resize c1 --num-nodes=0'
# GAP: gsutil / bq 不在這支 hook 的範圍
run g1_gsutil_not_covered none '' 'gsutil rm -r gs://b'

# --- gcloud：Tier 2（mutating）---
# GAP: gcloud 沒有 production 判斷（context 只來自 kubectl），Tier 2 永遠只是 systemMessage
run g2_instances_create msg '' 'gcloud compute instances create vm1' 'gcloud mutating'
run g2_clusters_update msg '' 'gcloud container clusters update c1 --enable-x' 'gcloud mutating'
run g2_add_iam_binding msg '' 'gcloud projects add-iam-policy-binding p1 --member=u --role=r' 'gcloud mutating'
run g2_remove_iam_binding msg '' 'gcloud projects remove-iam-policy-binding p1 --member=u --role=r' 'gcloud mutating'
run g2_set_iam_policy msg '' 'gcloud run services set-iam-policy s p.json' 'gcloud mutating'
run g2_replace msg '' 'gcloud run services replace s.yaml' 'gcloud mutating'
run g2_global_flag_before_group msg '' 'gcloud --project=p1 compute instances create vm1' 'gcloud mutating'
run g2_prod_project_still_msg msg '' 'gcloud compute instances create vm1 --project=acme-production' 'gcloud mutating'
# 同一條指令帶 kubectl 時才有 context 可判斷，production 才會 ask
run g2_with_kubectl_prod ask "$PROD" 'gcloud compute instances create vm1; kubectl get pods' 'Tier 2 mutating on PRODUCTION'
run g2_with_kubectl_dev msg "$DEV" 'gcloud compute instances create vm1; kubectl get pods' 'gcloud mutating'

# --- gcloud：唯讀 / 無關 ---
run g0_list none '' 'gcloud compute instances list'
run g0_describe none '' 'gcloud compute instances describe vm1'
run g0_auth_list none '' 'gcloud auth list'
run g0_config_set none '' 'gcloud config set project p1'
run g0_logging_read none '' 'gcloud logging read "severity>=ERROR"'
run g0_get_credentials none '' 'gcloud container clusters get-credentials c1 --project=p1'

# --- bypass：對 deny 無效，其餘情況照舊放行 ---
run bypass_prod_t1_denied deny "$PROD" 'SRE_GUARD_BYPASS=hotfix kubectl delete pod x' 'SRE_GUARD_BYPASS'
run bypass_prod_t1_after_export_denied deny "$PROD" 'export SRE_GUARD_BYPASS=hotfix; kubectl delete pod x' 'Tier 1'
run bypass_prod_t1_twice_denied deny "$PROD" 'SRE_GUARD_BYPASS=a SRE_GUARD_BYPASS=b kubectl delete pod x' 'Tier 1'
run bypass_unknown_ctx_t1_denied deny '' 'SRE_GUARD_BYPASS=hotfix kubectl delete pod x' 'context=<unknown>'
run bypass_prod_each_verb_drain deny "$PROD" 'SRE_GUARD_BYPASS=hotfix kubectl drain node-1' 'kubectl drain'
run bypass_gcloud_no_project_denied deny '' 'SRE_GUARD_BYPASS=INC-42 gcloud compute instances delete vm1' 'gcloud destructive'
run bypass_gcloud_prod_project_denied deny '' 'SRE_GUARD_BYPASS=INC-42 gcloud compute instances delete vm1 --project=acme-prod' 'gcloud destructive'
run bypass_dev_t1 allow "$DEV" 'SRE_GUARD_BYPASS=hotfix kubectl delete pod x' 'bypass: hotfix'
run bypass_dev_t1_after_export allow "$DEV" 'export SRE_GUARD_BYPASS=hotfix; kubectl delete pod x' 'bypass: hotfix'
run bypass_first_token_only allow "$DEV" 'SRE_GUARD_BYPASS=a SRE_GUARD_BYPASS=b kubectl delete pod x' 'bypass: a'
run bypass_prod_t2 allow "$PROD" 'SRE_GUARD_BYPASS=cicd-watch kubectl apply -f x.yaml' 'bypass: cicd-watch'
run bypass_prod_use_context allow "$DEV" "SRE_GUARD_BYPASS=manual-override kubectl config use-context $PROD" 'bypass: manual-override'
run bypass_gcloud_dev_project allow '' 'SRE_GUARD_BYPASS=INC-42 gcloud compute instances delete vm1 --project=my-dev' 'bypass: INC-42'
run bypass_on_unrelated_command allow '' 'SRE_GUARD_BYPASS=x ls' 'bypass: x'
# 空的 reason 不算 bypass
run bypass_empty_reason_dev ask "$DEV" 'SRE_GUARD_BYPASS= kubectl delete pod x' 'Tier 1'
run bypass_empty_reason_prod deny "$PROD" 'SRE_GUARD_BYPASS= kubectl delete pod x' 'Tier 1'
run bypass_empty_quotes_dev ask "$DEV" 'SRE_GUARD_BYPASS="" kubectl delete pod x' 'Tier 1'
run bypass_empty_single_quotes_dev ask "$DEV" "SRE_GUARD_BYPASS='' kubectl delete pod x" 'Tier 1'
run bypass_empty_reason_prod_t2 ask "$PROD" 'SRE_GUARD_BYPASS= kubectl apply -f x.yaml' 'Tier 2'
run bypass_empty_reason_unrelated none '' 'SRE_GUARD_BYPASS= ls'
# near-miss：變數名稱不完全相同或沒有 = 就不是 bypass
run bypass_name_suffix ask "$DEV" 'SRE_GUARD_BYPASSED=1 kubectl delete pod x' 'Tier 1'
run bypass_name_prefix ask "$DEV" 'X_SRE_GUARD_BYPASS=1 kubectl delete pod x' 'Tier 1'
run bypass_without_equals ask "$DEV" 'echo SRE_GUARD_BYPASS; kubectl delete pod x' 'Tier 1'
run bypass_name_suffix_prod deny "$PROD" 'SRE_GUARD_BYPASSED=1 kubectl delete pod x' 'Tier 1'

# --- 非 kubectl / gcloud 指令與空輸入 ---
run other_ls none "$PROD" 'ls -la'
run other_git_push none "$PROD" 'git push origin main'
run other_docker_rm none "$PROD" 'docker rm -f web'
run other_kubectl_like_name none "$PROD" 'mykubectl delete pod x'
run other_kubectx none "$PROD" 'kubectx staging'
run empty_command none "$PROD" ''
for raw in '{"tool_input":{}}' 'not json'; do # stdin 不是預期格式：無輸出、exit 0
  n=$((n + 1))
  out=$(printf '%s' "$raw" | bash "$HOOK" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL raw_input '$raw' rc=$rc out=$out"; fail=1; }
done

# hermetic：沒有呼叫到 gcloud，kubectl 也只被問過 current-context
[ ! -e "$T/gcloud_called" ] || { echo "FAIL hermetic: 呼叫到 gcloud"; fail=1; }
[ ! -e "$T/kubectl_unexpected" ] || { echo "FAIL hermetic: kubectl 被用來做 current-context 以外的事"; fail=1; }

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
