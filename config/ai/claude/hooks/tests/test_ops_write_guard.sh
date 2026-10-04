#!/usr/bin/env bash
# ops-write-guard.sh 的回歸測試（characterization）：斷言現行的 Tier 1/2/3、bypass 與 gcloud 行為。
# kubectl / gcloud 都用 PATH 前置的 stub：kubectl 只回應 `config current-context`（值由 STUB_CTX 控制），
# 其他呼叫或任何 gcloud 呼叫都會留下記號，結尾檢查沒有被碰過。危險指令只以 JSON 字串餵給 hook。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/ops-write-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir "$T/bin"
cat >"$T/bin/kubectl" <<EOF
#!/bin/sh
if [ "\$*" = "config current-context" ]; then printf '%s\n' "\${STUB_CTX:-}"; exit 0; fi
touch "$T/kubectl_unexpected"; exit 97
EOF
cat >"$T/bin/gcloud" <<EOF
#!/bin/sh
touch "$T/gcloud_called"; exit 97
EOF
chmod +x "$T/bin/kubectl" "$T/bin/gcloud"
export PATH="$T/bin:$PATH"

fail=0; n=0
run() { # name expect(ask|allow|msg|none) ctx(stub 回傳的 current-context，空字串代表取不到) command [輸出子字串]
  n=$((n + 1))
  out=$(jq -n --arg c "$4" '{tool_input:{command:$c}}' | STUB_CTX="$3" bash "$HOOK" 2>/dev/null); rc=$?
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

# --- Tier 1：任何 cluster 都 ask ---
run t1_delete_dev ask "$DEV" 'kubectl delete pod web-1' 'Tier 1'
run t1_delete_prod ask "$PROD" 'kubectl delete pod web-1' "context=$PROD"
run t1_delete_no_ctx ask '' 'kubectl delete pod web-1' 'context=<unknown>'
run t1_drain ask "$DEV" 'kubectl drain node-1 --ignore-daemonsets' 'drain'
run t1_cordon ask "$DEV" 'kubectl cordon node-1' 'cordon'
run t1_uncordon ask "$DEV" 'kubectl uncordon node-1' 'uncordon'
run t1_replace ask "$DEV" 'kubectl replace -f x.yaml' 'replace'
run t1_taint ask "$DEV" 'kubectl taint nodes n1 k=v:NoSchedule' 'taint'
run t1_ns_flag_before_verb ask "$DEV" 'kubectl -n kube-system delete pod x' 'ns=kube-system'
run t1_ns_flag_long_eq ask "$DEV" 'kubectl --namespace=app delete pod x' 'ns=app'
run t1_ns_flag_after ask "$DEV" 'kubectl delete pod x -n app' 'ns=app'
run t1_inline_context_eq ask "$DEV" 'kubectl delete pod x --context=other' 'context=other'
run t1_inline_context_space ask "$DEV" 'kubectl --context other delete pod x' 'context=other'
run t1_after_semicolon ask "$DEV" 'cd r; kubectl delete pod x' 'Tier 1'
run t1_after_and ask "$DEV" 'true && kubectl delete pod x' 'Tier 1'
run t1_sudo_prefix ask "$DEV" 'sudo kubectl delete pod x' 'Tier 1'
# GAP: 只看第一個 kubectl 的 verb，前面接唯讀指令再串 delete 會整串放行
run t1_chained_after_get none "$DEV" 'kubectl get pods; kubectl delete pod x'
# GAP: --server / --as / --token 等帶值 flag 不在 skip 清單，值被當成 verb，delete 放行
run t1_value_flag_hides_verb none "$DEV" 'kubectl --server https://k.example delete pod x'
run t1_as_flag_hides_verb none "$DEV" 'kubectl --as admin delete pod x'
# GAP: 完整路徑的 kubectl 不會被偵測到
run t1_absolute_path none "$DEV" '/usr/local/bin/kubectl delete pod x'
# GAP: 子 shell / 括號內的 kubectl：grep 偵測得到但 awk 取不到 verb，delete 放行
run t1_subshell none "$DEV" '(kubectl delete pod x)'
# GAP: 偵測只看字面 token，echo / grep 之類不執行的字串也會 ask（誤攔）
run t1_echo_false_positive ask "$DEV" 'echo kubectl delete pod x' 'Tier 1'

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
# GAP: production 只認 context 名稱含 "production"，prod / prd 縮寫不會升級成 ask
run t2_prod_abbrev_not_detected msg 'gke_proj_prod-cluster' 'kubectl apply -f x.yaml' 'Tier 2 non-prod'

# --- Tier 3：只提示 context / namespace，不做決定（production 也一樣）---
run t3_exec_dev msg "$DEV" 'kubectl exec -it web-1 -- sh' 'context-sensitive'
run t3_exec_prod msg "$PROD" 'kubectl exec -it web-1 -- sh' "context=$PROD"
run t3_cp msg "$DEV" 'kubectl cp web-1:/a ./a' 'cp'
run t3_port_forward msg "$DEV" 'kubectl port-forward svc/web 8080:80' 'port-forward'
run t3_attach msg "$DEV" 'kubectl attach web-1' 'attach'
run t3_proxy msg "$DEV" 'kubectl proxy' 'proxy'
run t3_use_context_dev msg "$DEV" 'kubectl config use-context staging' 'use-context'
# use-context 切到 production：升級成 Tier 1 ask
run t3_use_context_prod ask "$DEV" "kubectl config use-context $PROD" 'PRODUCTION cluster'
run t3_use_context_prod_upper ask "$DEV" 'kubectl config use-context GKE_PRODUCTION' 'PRODUCTION cluster'
# GAP: use-context 切到 prod 縮寫的 cluster 只有提示，不升級
run t3_use_context_prod_abbrev msg "$DEV" 'kubectl config use-context gke_proj_prod-cluster' 'use-context'

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

# --- gcloud：Tier 1（destructive）---
run g1_instances_delete ask '' 'gcloud compute instances delete vm1' 'gcloud destructive'
run g1_instances_stop ask '' 'gcloud compute instances stop vm1' 'gcloud destructive'
run g1_instances_reset ask '' 'gcloud compute instances reset vm1' 'gcloud destructive'
run g1_sql_delete ask '' 'gcloud sql instances delete db1' 'gcloud destructive'
run g1_secrets_delete ask '' 'gcloud secrets delete s1' 'gcloud destructive'
run g1_projects_delete ask '' 'gcloud projects delete p1' 'gcloud destructive'
run g1_clusters_delete ask '' 'gcloud container clusters delete c1' 'gcloud destructive'
run g1_after_semicolon ask '' 'cd r; gcloud compute instances delete vm1' 'gcloud destructive'
run g1_with_kubectl_get ask "$DEV" 'gcloud compute instances delete vm1; kubectl get pods' 'gcloud destructive'
# GAP: gcloud 的全域 flag 放在群組前面就比對不到（連 Tier 2 規則也不中）
run g1_global_flag_before_group none '' 'gcloud --project=p1 compute instances delete vm1'
# GAP: 規則只列了幾種資源，其他 delete（例如 disks）放行
run g1_disks_delete none '' 'gcloud compute disks delete d1'

# --- gcloud：Tier 2（mutating）---
# GAP: gcloud 沒有 production 判斷（context 只來自 kubectl），Tier 2 永遠只是 systemMessage
run g2_instances_create msg '' 'gcloud compute instances create vm1' 'gcloud mutating'
run g2_clusters_update msg '' 'gcloud container clusters update c1 --enable-x' 'gcloud mutating'
run g2_add_iam_binding msg '' 'gcloud projects add-iam-policy-binding p1 --member=u --role=r' 'gcloud mutating'
run g2_remove_iam_binding msg '' 'gcloud projects remove-iam-policy-binding p1 --member=u --role=r' 'gcloud mutating'
run g2_set_iam_policy msg '' 'gcloud run services set-iam-policy s p.json' 'gcloud mutating'
run g2_replace msg '' 'gcloud run services replace s.yaml' 'gcloud mutating'
# 同一條指令帶 kubectl 時才有 context 可判斷，production 才會 ask
run g2_with_kubectl_prod ask "$PROD" 'gcloud compute instances create vm1; kubectl get pods' 'Tier 2 mutating on PRODUCTION'
run g2_with_kubectl_dev msg "$DEV" 'gcloud compute instances create vm1; kubectl get pods' 'gcloud mutating'

# --- gcloud：唯讀 / 無關 ---
run g0_list none '' 'gcloud compute instances list'
run g0_describe none '' 'gcloud compute instances describe vm1'
run g0_auth_list none '' 'gcloud auth list'
run g0_config_set none '' 'gcloud config set project p1'
run g0_logging_read none '' 'gcloud logging read "severity>=ERROR"'

# --- bypass ---
run bypass_kubectl_delete allow "$PROD" 'SRE_GUARD_BYPASS=hotfix kubectl delete pod x' 'bypass: hotfix'
run bypass_after_export allow "$PROD" 'export SRE_GUARD_BYPASS=hotfix; kubectl delete pod x' 'bypass: hotfix'
run bypass_gcloud allow '' 'SRE_GUARD_BYPASS=INC-42 gcloud compute instances delete vm1' 'bypass: INC-42'
run bypass_on_unrelated_command allow '' 'SRE_GUARD_BYPASS=x ls' 'bypass: x'
run bypass_first_token_only allow "$PROD" 'SRE_GUARD_BYPASS=a SRE_GUARD_BYPASS=b kubectl delete pod x' 'bypass: a'
# GAP: 空 reason 的 bypass（SRE_GUARD_BYPASS=）也會放行，沒有強制要寫理由
run bypass_empty_reason allow "$PROD" 'SRE_GUARD_BYPASS= kubectl delete pod x' 'bypass: '
# near-miss：變數名稱不完全相同或沒有 = 就不是 bypass
run bypass_name_suffix ask "$PROD" 'SRE_GUARD_BYPASSED=1 kubectl delete pod x' 'Tier 1'
run bypass_name_prefix ask "$PROD" 'X_SRE_GUARD_BYPASS=1 kubectl delete pod x' 'Tier 1'
run bypass_without_equals ask "$PROD" 'echo SRE_GUARD_BYPASS; kubectl delete pod x' 'Tier 1'

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
