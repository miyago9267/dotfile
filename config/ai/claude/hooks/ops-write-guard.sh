#!/usr/bin/env bash
# ops-write-guard: PreToolUse hook
# Tier 1 (destructive verbs):  production 或無法確認 context -> deny（bypassPermissions 模式下也擋，
#                              由 Miyago 自己在 terminal 執行）；其他 cluster -> ask
# Tier 2 (mutating verbs):     production -> ask；其他只印 context
# Tier 3 (all):                show context+namespace (systemMessage, no block)
# gcloud destructive:          deny，除非 --project 明確指向非 production 專案（-> ask）
# Bypass: inline SRE_GUARD_BYPASS=<reason>（reason 不可為空）；對 deny 無效
# production 的判斷只看名稱：含 production，或以非字母隔開的 prod / prd；non-prod、pre-prod 這類不算。
# 連帶結果：context 是 prod-cluster、gke_x_prd_1 這類縮寫時，Tier 2 與 use-context 也會由 systemMessage 變成 ask。
# kubectl / gcloud 帶 --help、kubectl 帶 --dry-run 時不會改變任何東西，不擋。
# 指令超過 64KB 不做完整解析，字面命中就 ask。

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# --- 解析：把指令切成 simple command，找出真的會執行的 kubectl / gcloud ---
# awk 認得引號、串接（; && || | & 換行）、括號與 $()、heredoc、full path、sudo/env/xargs 這類前綴，
# 也會把 `bash -c "..."` 這種帶空白的字串參數當成指令再掃一次。echo、git、grep 這類只印字或只讀字的指令不算。
# 每筆輸出一行，欄位以 \037 分隔：
#   K tier verb mode ctx eff ns target   mode: inl=指令內指定 context、cur=用 current-context、unk=無法判斷
#   G tier desc hasproj project
scan_cmd() {
  GUARD_CMD="$1" awk '
# f 是兩個旗標相加。1：這段字串會在遠端或 container 裡執行（ssh、docker），本機的 current-context 不適用。
# 2：這段字串只是某個程式的參數，不確定是不是指令（例如通知訊息），裡面的 kubectl 要在指令開頭或已知的包裝指令後面才算。
function enqueue(s, f) { if (qn < 300) { queue[qn] = s; qf[qn] = f; qn++ } }
function base(w) { sub(/^.*\//, "", w); return w }
function san(s) { gsub(/[\037\n\r\t]/, " ", s); return s }
# s[i] 起是 "<<"：回傳 heredoc delimiter，HD_NEXT 指向 delimiter 之後
function hd_delim(s, i,    n, c, d, q) {
  n = length(s); i += 2; d = ""
  if (substr(s, i, 1) == "-") i++
  while (i <= n && substr(s, i, 1) ~ /[ \t]/) i++
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\047" || c == "\"") { q = c; i++; while (i <= n && substr(s, i, 1) != q) { d = d substr(s, i, 1); i++ } i++; continue }
    if (c == "\\") { d = d substr(s, i + 1, 1); i += 2; continue }
    if (c ~ /[ \t\n;&|()<>]/) break
    d = d c; i++
  }
  HD_NEXT = i
  return d
}
# s[i] 是換行：往下讀到只含 delimiter 的那一行；內容放 HD_BODY，回傳終止行結尾換行的位置
function hd_body(s, i, d,    n, rest, line, p, t, body) {
  n = length(s); body = ""; i++
  while (i <= n) {
    rest = substr(s, i); p = index(rest, "\n")
    line = (p ? substr(rest, 1, p - 1) : rest)
    t = line; gsub(/^[ \t]+|[ \t]+$/, "", t)
    if (t == d) { HD_BODY = body; return (p ? i + p - 1 : n + 1) }
    body = body line "\n"
    i = (p ? i + p : n + 1)
  }
  HD_BODY = body
  return n + 1
}
# s[i] 是 $( 的左括號：找到對應的右括號，內容排進 queue 另外掃，外層 token 留下 $() 當記號
function sub_paren(s, i,    n, j, c, depth, x, k, np, pend) {
  n = length(s); depth = 1; j = i + 1; np = 0
  while (j <= n) {
    c = substr(s, j, 1)
    if (c == "\\") { j += 2; continue }
    if (c == "$" && substr(s, j + 1, 1) == "\047") { j += 2; while (j <= n && substr(s, j, 1) != "\047") { if (substr(s, j, 1) == "\\") j++; j++ } j++; continue }
    if (c == "\047") { k = index(substr(s, j + 1), "\047"); if (k == 0) { j = n + 1; break } j += k + 1; continue }
    if (c == "\"") { j++; while (j <= n && substr(s, j, 1) != "\"") { if (substr(s, j, 1) == "\\") j++; j++ } j++; continue }
    if (c == "<" && substr(s, j + 1, 1) == "<") {
      if (substr(s, j + 2, 1) == "<") { j += 3; continue }
      x = hd_delim(s, j); j = HD_NEXT; if (x != "") pend[++np] = x
      continue
    }
    if (c == "\n" && np > 0) { for (k = 1; k <= np; k++) j = hd_body(s, j, pend[k]); np = 0; j++; continue }
    if (c == "(") depth++
    else if (c == ")") { depth--; if (depth == 0) break }
    j++
  }
  enqueue(substr(s, i + 1, j - i - 1), SCANF); tok = tok "$()"
  return j + 1
}
function sub_tick(s, i,    n, j) {
  n = length(s); j = i + 1
  while (j <= n && substr(s, j, 1) != "`") { if (substr(s, j, 1) == "\\") j++; j++ }
  enqueue(substr(s, i + 1, j - i - 1), SCANF); tok = tok "$()"
  return j + 1
}
function endtok() { if (intok) { cn[cur]++; ct[cur, cn[cur]] = tok; cw[cur, cn[cur]] = (tok ~ /[ \t\n]/) } tok = ""; intok = 0 }
function endcmd() { if (cn[cur] > 0) { cp[cur] = pipe; crem[cur] = SCANF % 2; cmb[cur] = (SCANF >= 2); ncmd = cur; cur = ncmd + 1; cn[cur] = 0 } }
function scan(s, f,    n, i, c, d, j, x, np, pend, pp) {
  n = length(s); i = 1; tok = ""; intok = 0; np = 0; SCANF = f
  pipe = ++npipe; cur = ncmd + 1; cn[cur] = 0
  while (i <= n) {
    c = substr(s, i, 1); d = substr(s, i + 1, 1)
    if (c == "\\") { if (d == "\n") { i += 2; continue } tok = tok d; intok = 1; i += 2; continue }
    if (c == "$" && d == "\047") {   # ANSI-C 引號：反斜線可以跳脫單引號
      i += 2; intok = 1
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\") { d = substr(s, i + 1, 1); tok = tok (d == "n" ? "\n" : (d == "t" ? "\t" : d)); i += 2; continue }
        if (c == "\047") { i++; break }
        tok = tok c; i++
      }
      continue
    }
    if (c == "$" && d == "\"") { i++; continue }
    if (c == "\047") {
      j = index(substr(s, i + 1), "\047")
      if (j == 0) { tok = tok substr(s, i + 1); i = n + 1 } else { tok = tok substr(s, i + 1, j - 1); i += j + 1 }
      intok = 1; continue
    }
    if (c == "\"") {
      i++; intok = 1
      while (i <= n) {
        c = substr(s, i, 1); d = substr(s, i + 1, 1)
        if (c == "\\") { tok = tok d; i += 2; continue }
        if (c == "\"") { i++; break }
        if (c == "$" && d == "(") { i = sub_paren(s, i + 1); continue }
        if (c == "`") { i = sub_tick(s, i); continue }
        tok = tok c; i++
      }
      continue
    }
    if (c == "$" && d == "(") { i = sub_paren(s, i + 1); intok = 1; continue }
    if (c == "`") { i = sub_tick(s, i); intok = 1; continue }
    if (c == "#" && !intok) { while (i <= n && substr(s, i, 1) != "\n") i++; continue }
    if (c == "<" && d == "<") {
      endtok()
      if (substr(s, i + 2, 1) == "<") { i += 3; continue }
      x = hd_delim(s, i); i = HD_NEXT
      if (x != "") { np++; pend[np] = x; pp[np] = pipe }
      continue
    }
    if (c == " " || c == "\t") { endtok(); i++; continue }
    if (c == "\n") {
      endtok(); endcmd(); pipe = ++npipe
      for (j = 1; j <= np; j++) { i = hd_body(s, i, pend[j]); nh++; hb[nh] = HD_BODY; hp[nh] = pp[j] }
      np = 0; i++; continue
    }
    if (c == ";") { endtok(); endcmd(); pipe = ++npipe; i++; continue }
    if (c == "&") {
      if (d == "&") { endtok(); endcmd(); pipe = ++npipe; i += 2; continue }
      if (d == ">" || (i > 1 && substr(s, i - 1, 1) ~ /[<>]/)) { tok = tok c; intok = 1; i++; continue }
      endtok(); endcmd(); pipe = ++npipe; i++; continue
    }
    if (c == "|") {
      endtok(); endcmd()
      if (d == "|") { pipe = ++npipe; i += 2 } else if (d == "&") i += 2; else i++
      continue
    }
    if (c == "(" || c == ")") { endtok(); endcmd(); pipe = ++npipe; i++; continue }
    tok = tok c; intok = 1; i++
  }
  endtok(); endcmd()
}

# kubectl：ct[k, j] 是 kubectl 本身
# rem=1：在遠端或 container 裡執行；maybe=1：指令名是變數或 $()，只有第一個參數就是 Tier 1/2 的 verb 才算
function kube(k, j, kc, rem, maybe,    m, x, t, c2, np, pos, vi, verb, tgt, ctx, hasctx, ctxconf, noop, ns, hard, taint, dd, tier, mode, effout, i) {
  m = cn[k]; np = 0; ctx = ""; hasctx = 0; ctxconf = 0; noop = 0; ns = ""; hard = 0; taint = kc; dd = 0
  for (x = j + 1; x <= m; x++) {
    t = ct[k, x]
    if (t == "--") { dd = x; break }
    if (t ~ /^-/) {
      if (t ~ /^--context=/ || t == "--context") {
        if (t == "--context") { c2 = ct[k, x + 1]; x++ } else c2 = substr(t, 11)
        if (hasctx && c2 != ctx) ctxconf = 1   # 給了兩個不同的 context，不猜哪個生效
        ctx = c2; hasctx = 1
      }
      else if (t == "--help" || t == "-h" || t == "--dry-run" || t ~ /^--dry-run=(client|server|true)$/) noop = 1
      else if (t ~ /^(--namespace|-n)=/) { ns = t; sub(/^[^=]*=/, "", ns) }
      else if (t == "-n" || t == "--namespace") { ns = ct[k, x + 1]; x++ }
      else if (t ~ /^(--server|-s|--cluster)(=|$)/) { hard = 1; if (t !~ /=/) x++ }
      else if (t ~ /^--kubeconfig(=|$)/) { taint = 1; if (t !~ /=/) x++ }
      else if (t in KVAL) x++
      continue
    }
    pos[++np] = t
  }
  # verb 取第一個是 kubectl 子指令的位置參數：沒列在 KVAL 的帶值 flag，值不會被誤認成 verb
  vi = 0
  for (i = 1; i <= np; i++) if (pos[i] in KCMD) { vi = i; break }
  if (maybe && vi != 1) return
  dyn = (vi == 0 && np >= 1 && pos[1] ~ /\$/)   # verb 來自變數或 $()，無法判斷
  if (vi == 0) vi = 1
  verb = (np >= 1 ? pos[vi] : ""); tgt = ""
  if (verb == "rollout" || verb == "config") {
    if (vi + 1 <= np) { verb = verb " " pos[vi + 1]; if (vi + 2 <= np) tgt = pos[vi + 2] }
  } else if (verb == "ctx" && vi + 1 <= np) { verb = "config use-context"; tgt = pos[vi + 1] }

  tier = 0
  if (verb ~ /^(delete|drain|cordon|uncordon|replace|taint)$/) tier = 1
  else if (verb ~ /^(apply|patch|edit|scale|annotate|label|set|create|rollout (restart|undo|pause|resume))$/) tier = 2
  else if (verb ~ /^(exec|cp|port-forward|attach|proxy|config use-context)$/) tier = 3
  if (dyn) { tier = 1; verb = "<verb 來自變數或 $()>" }
  if (noop) tier = 0   # --help、--dry-run 不會改變任何東西
  if (maybe && tier != 1 && tier != 2) return

  effout = ""
  if (hard || ctxconf) mode = "unk"
  else if (hasctx) mode = ((ctx == "" || ctx ~ /\$/) ? "unk" : "inl")
  else if (taint) mode = "unk"
  else { mode = (rem ? "rem" : "cur"); effout = eff }
  printf "K\037%d\037%s\037%s\037%s\037%s\037%s\037%s\n", tier, san(verb), mode, san(ctx), san(effout), san(ns), san(tgt)

  # 這條指令會改掉之後的 current-context
  if (verb == "config use-context") eff = ((tgt == "" || tgt ~ /\$/) ? "?" : tgt)
  else if (verb == "config set" && tgt == "current-context") eff = "?"

  # `kubectl exec pod -- <指令>`：-- 後面當成另一條指令再判斷
  if (dd && dd < m) {
    ncmd++; cn[ncmd] = 0; cp[ncmd] = cp[k]; crem[ncmd] = crem[k]; cmb[ncmd] = cmb[k]
    for (x = dd + 1; x <= m; x++) { cn[ncmd]++; ct[ncmd, cn[ncmd]] = ct[k, x]; cw[ncmd, cn[ncmd]] = cw[k, x] }
  }
}

# gcloud：ct[k, j] 是 gcloud 本身
function gcl(k, j,    m, x, t, p2, np, pos, proj, hasproj, projconf, tier, i, desc) {
  m = cn[k]; np = 0; proj = ""; hasproj = 0; projconf = 0
  for (x = j + 1; x <= m; x++) {
    t = ct[k, x]
    if (t == "--help" || t == "-h") return   # 只印說明
    if (t ~ /^-/) {
      if (t ~ /^--project=/ || t == "--project") {
        if (t == "--project") { p2 = ct[k, x + 1]; x++ } else p2 = substr(t, 11)
        if (hasproj && p2 != proj) projconf = 1   # 給了兩個不同的專案，不猜哪個生效
        proj = p2; hasproj = 1
      }
      else if (t in GVAL) x++
      continue
    }
    if (np == 0 && (t == "alpha" || t == "beta" || t == "preview")) continue
    pos[++np] = t
  }
  if (np == 0 || pos[1] == "config") return   # gcloud config 只動本機設定
  if (pos[1] == "container" && pos[2] == "clusters" && pos[3] == "get-credentials") eff = "?"
  tier = 0
  for (i = 2; i <= np && i <= 6; i++) if (pos[i] == "delete" || pos[i] == "destroy") tier = 1
  if (pos[1] == "storage" && pos[2] == "rm") tier = 1
  if (pos[1] == "compute" && pos[2] == "instances" && (pos[3] == "stop" || pos[3] == "reset")) tier = 1
  if (!tier) for (i = 2; i <= np && i <= 4; i++) if (pos[i] in GMUT) tier = 2
  if (!tier) return
  desc = ""
  for (i = 1; i <= np && i <= 6; i++) desc = desc (i > 1 ? " " : "") pos[i]
  if (proj ~ /\$/ || projconf) proj = ""
  printf "G\037%d\037%s\037%d\037%s\n", tier, san(desc), hasproj, san(proj)
}

# 把 command k 的參數（指令名之後）當成指令再掃：整串一次，帶空白的參數各一次
function rescan_args(k, f,    x, s) {
  s = ""
  for (x = cj[k] + 1; x <= cn[k]; x++) { s = s " " ct[k, x]; if (cw[k, x]) enqueue(ct[k, x], f) }
  if (s != "") enqueue(s, f)
}
# 判斷一條 simple command。開頭的指令不在「明確不執行」清單（NONEXEC）內時，只要有 kubectl / gcloud 這個 word
# （含 full path）就當成會被執行：不管前面包的是 sudo、xargs、op run --、docker exec 還是沒看過的東西。
function analyze(k,    m, j, t, w, x, b, kc, rem, ki, pos, k2, sh) {
  m = cn[k]; kc = 0
  for (j = 1; j <= m; j++) {
    t = ct[k, j]
    if (t in KW) continue
    if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if (t ~ /^KUBECONFIG=/) kc = 1; continue }
    break
  }
  cj[k] = j
  if (j > m) { cnx[k] = 1; if (kc) eff = "?"; return }   # 單獨的 KUBECONFIG=... 會影響後面的指令
  w = base(ct[k, j])
  if (w in NONEXEC) {
    cnx[k] = 1
    # git -c alias.x="!cmd" 會執行 cmd
    if (w == "git") for (x = j + 1; x <= m; x++) if (ct[k, x] ~ /^alias\.[^=]*=!/) { t = ct[k, x]; sub(/^[^=]*=!/, "", t); enqueue(t, crem[k] + 2 * cmb[k]) }
    return
  }
  ex[cp[k]] = 1
  rem = (crem[k] || w == "ssh" || w == "docker" || w == "podman" || w == "nerdctl") ? 1 : 0
  if (rem) prem[cp[k]] = 1
  if (w == "export" || w == "declare" || w == "typeset") {
    for (x = j + 1; x <= m; x++) if (ct[k, x] ~ /^KUBECONFIG=/) eff = "?"
  }
  # 這條指令會把字串參數當成指令執行嗎（bash -c、eval、ssh、watch，或任何位置有 shell）
  sh = (w == "eval" || w == "ssh" || w == "su" || w == "watch") ? 1 : 0
  for (x = j; x <= m && !sh; x++) if (base(ct[k, x]) in SHELL) sh = 1
  if (sh) pshell[cp[k]] = 1
  if (cmb[k]) pmb[cp[k]] = 1
  ki = 0
  for (x = j; x <= m; x++) {
    b = base(ct[k, x])
    if (b == "kubectl" || b == "kubecolor" || b == "gcloud") { ki = x; break }
  }
  if (cmb[k] && ki != j && !(w in WRAP)) ki = 0
  if (ki && b == "gcloud") gcl(k, ki)
  else if (ki) kube(k, ki, kc, rem, 0)
  else if (w == "kubectx" || w == "kctx") {
    if (j + 1 <= m) { x = ct[k, j + 1]; if (x == "-" || x ~ /[=$]/) eff = "?"; else if (x !~ /^-/) eff = x }
  }
  else if (w ~ /^\$/ && !cmb[k]) kube(k, j, kc, rem, 1)   # $K delete ...、"$(which kubectl)" delete ...
  if (w in SHELL) {
    pos = 0
    for (x = j + 1; x <= m; x++) { t = ct[k, x]; if (t ~ /^-/ || t ~ /^[0-9]*[<>]/) continue; pos = 1; break }
    # shell 從 stdin 讀指令：同一條 pipeline 前面 echo / printf 印出來的字就是指令
    if (!pos) for (k2 = 1; k2 < k; k2++) if (cp[k2] == cp[k] && cnx[k2]) rescan_args(k2, rem + 2 * cmb[k])
  }
  # 帶空白的字串參數可能是 `bash -c "..."`、`ssh host "..."` 的指令本體
  for (x = j + 1; x <= m; x++) if (cw[k, x]) enqueue(ct[k, x], rem + 2 * ((cmb[k] || !sh) ? 1 : 0))
}

BEGIN {
  n = split("echo printf git gh glab grep egrep fgrep rg ag sed awk cat tee less more head tail wc ls man which type whence test [ jq yq", a, " ")
  for (i = 1; i <= n; i++) NONEXEC[a[i]] = 1
  n = split("{ } if then else elif fi do done while until ! time function coproc", a, " "); for (i = 1; i <= n; i++) KW[a[i]] = 1
  n = split("bash sh zsh dash ksh", a, " "); for (i = 1; i <= n; i++) SHELL[a[i]] = 1
  n = split("sudo doas env command exec builtin nohup nice ionice stdbuf caffeinate timeout gtimeout xargs watch eval ssh find parallel setsid noglob op mise docker podman nerdctl", a, " ")
  for (i = 1; i <= n; i++) WRAP[a[i]] = 1
  n = split("get describe delete drain cordon uncordon replace taint apply patch edit scale annotate label set create rollout config exec cp port-forward attach proxy logs top explain api-resources api-versions cluster-info version auth diff wait run expose autoscale certificate debug events kustomize completion plugin options ctx ns krew", a, " ")
  for (i = 1; i <= n; i++) KCMD[a[i]] = 1
  n = split("--user --as --as-group --as-uid --token --certificate-authority --client-certificate --client-key --request-timeout --tls-server-name --cache-dir --password --username --profile --profile-output --log-flush-frequency -v --v -c --container -l --selector -f --filename -o --output -k --kustomize -p --patch --field-selector --grace-period --timeout --type --replicas --image --overrides --field-manager --sort-by --tail --since --since-time -L --label-columns", a, " ")
  for (i = 1; i <= n; i++) KVAL[a[i]] = 1
  n = split("--account --configuration --format --verbosity --impersonate-service-account --billing-project --region --zone --location --filter --limit --sort-by --page-size --flags-file --access-token-file --trace-token", a, " ")
  for (i = 1; i <= n; i++) GVAL[a[i]] = 1
  n = split("update set-iam-policy add-iam-policy-binding remove-iam-policy-binding create replace", a, " "); for (i = 1; i <= n; i++) GMUT[a[i]] = 1

  eff = ""; done_k = 0; done_h = 0
  enqueue(ENVIRON["GUARD_CMD"], 0)
  while (qh < qn || done_k < ncmd || done_h < nh) {
    if (qh < qn) { scan(queue[qh], qf[qh]); qh++; continue }
    if (done_k < ncmd) { done_k++; analyze(done_k); continue }
    done_h++
    # heredoc 餵給會執行的指令才當成指令掃；餵給 shell 以外的程式（python、kubectl apply -f -）時只當成「不確定」
    p = hp[done_h]
    if (ex[p]) enqueue(hb[done_h], prem[p] + 2 * ((pmb[p] || !pshell[p]) ? 1 : 0))
  }
}'
}

# 名稱是否像 production：含 production，或以非字母隔開的 prod / prd（product、reproduce、acmeprod 不算）。
# 帶否定或前置詞的 non-prod、nonproduction、pre-prod、preprod、not-prod 先拿掉再判斷，不算 production。
is_prod() {
  local s
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/(^|[^a-z])(non|pre|not)[-_.]?(production|prod|prd)/\1/g')
  local re='production|(^|[^a-z])(prod|prd)([^a-z]|$)'
  [[ $s =~ $re ]]
}

emit() { # decision reason
  jq -n --arg d "$1" --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
}

# 指令過長不做完整解析（逐字掃描的成本隨長度平方成長）：提到 kubectl / gcloud 又有破壞性字樣就 ask
if [ ${#cmd} -gt 65536 ]; then
  case "$cmd" in
    *kubectl* | *kubecolor* | *gcloud*)
      case "$cmd" in
        *delete* | *drain* | *cordon* | *replace* | *taint* | *destroy* | *" rm "* | *" stop "* | *" reset "*)
          emit ask "ops-write-guard：指令超過 64KB，未完整解析，但內含 kubectl / gcloud 與破壞性字樣。請拆成較短的指令再執行。"
          ;;
      esac
      ;;
  esac
  exit 0
fi

if ! records=$(scan_cmd "$cmd"); then
  # 解析失敗：指令有提到 kubectl / gcloud 就擋，寧可多擋
  case "$cmd" in
    *kubectl* | *gcloud*)
      emit deny "ops-write-guard：無法解析這條 kubectl / gcloud 指令，為避免誤動 production 先擋下。請改成較單純的寫法，或由 Miyago 自己在 terminal 執行。"
      ;;
  esac
  exit 0
fi

# --- current-context（最多問一次）---
cur_state=0 # 0=還沒問 1=取得 2=取不到
cur_ctx=""
get_cur() {
  [ $cur_state -ne 0 ] && return 0
  if command -v kubectl >/dev/null 2>&1 && cur_ctx=$(kubectl config current-context 2>/dev/null) && [ -n "$cur_ctx" ]; then
    cur_state=1
  else
    cur_ctx=""; cur_state=2
  fi
}

# 依 mode 算出 r_label（顯示用）、r_prod、r_unk
resolve() { # mode ctx eff
  r_label="<unknown>"; r_prod=0; r_unk=0
  case "$1" in
    inl) r_label=$2; is_prod "$2" && r_prod=1 ;;
    unk) r_unk=1 ;;
    *)
      get_cur
      if [ $cur_state -eq 1 ]; then r_label=$cur_ctx; is_prod "$cur_ctx" && r_prod=1; else r_unk=1; fi
      # 同一條指令前面切過 context：目標與原本的 context 任一個是 production 就算
      if [ "$3" = "?" ]; then
        r_unk=1; r_label="<unknown>"
      elif [ -n "$3" ]; then
        r_label=$3; is_prod "$3" && r_prod=1
      fi
      # 在遠端或 container 裡執行：本機的 context 只能參考，實際打到哪裡無法確認
      [ "$1" = rem ] && r_unk=1
      ;;
  esac
  return 0
}

DENY_TAIL="這類操作不可逆，agent 不代為執行，inline SRE_GUARD_BYPASS 對此無效；請 Miyago 確認目標後，自己在 terminal 執行。"

# --- 逐筆判斷，取最嚴重的一筆（deny=4 > ask=3 > systemMessage=1）---
best=0; best_dec=""; best_text=""
consider() { # level decision text
  if [ "$1" -gt "$best" ]; then best=$1; best_dec=$2; best_text=$3; fi
}
first_k=0; k1_mode=""; k1_ctx=""; k1_eff=""
g2_pending=""

while IFS=$'\037' read -r kind f1 f2 f3 f4 f5 f6 f7; do
  case "$kind" in
    K)
      tier=$f1; verb=$f2; mode=$f3; ctx=$f4; effv=$f5; ns=${f6:-<default>}; tgt=$f7
      if [ $first_k -eq 0 ]; then first_k=1; k1_mode=$mode; k1_ctx=$ctx; k1_eff=$effv; fi
      [ "$tier" = 0 ] && continue
      resolve "$mode" "$ctx" "$effv"
      case "$tier" in
        1)
          reason="kubectl $verb is destructive (Tier 1)"
          if [ $r_unk -eq 1 ]; then
            [ "$mode" = rem ] && r_label="<unknown>"
            consider 4 deny "ops-write-guard：已擋下破壞性操作（Tier 1）。context=$r_label ns=$ns -- ${reason}。原因：無法判斷 context（current-context 取不到，指令用了 KUBECONFIG / --kubeconfig / --server / --cluster、變數當 context，或是在 ssh / container 裡執行），視為 production 處理。目標確定不是 production 時，加上明確的 --context <名稱> 重試；否則$DENY_TAIL"
          elif [ $r_prod -eq 1 ]; then
            consider 4 deny "ops-write-guard：已擋下 production 的破壞性操作（Tier 1）。context=$r_label ns=$ns -- ${reason}。context 名稱判定為 production。$DENY_TAIL"
          else
            consider 3 ask "Tier 1 destructive op. context=$r_label ns=$ns -- $reason. Bypass via inline SRE_GUARD_BYPASS=<reason>."
          fi
          ;;
        2)
          reason="kubectl $verb is mutating (Tier 2)"
          if [ $r_prod -eq 1 ]; then
            consider 3 ask "Tier 2 mutating on PRODUCTION. context=$r_label ns=$ns -- $reason. Bypass via inline SRE_GUARD_BYPASS=<reason>."
          else
            consider 1 msg "[ops-write-guard] Tier 2 non-prod -- context=$r_label ns=$ns ($reason)"
          fi
          ;;
        3)
          # 切到 production cluster：ask（切換本身可逆，不 deny）
          if [ "$verb" = "config use-context" ] && is_prod "$tgt"; then
            consider 3 ask "Tier 1 destructive op. context=$r_label ns=$ns -- kubectl config use-context -> PRODUCTION cluster ($tgt). Bypass via inline SRE_GUARD_BYPASS=<reason>."
          else
            consider 1 msg "[ops-write-guard] context=$r_label ns=$ns (kubectl $verb (context-sensitive))"
          fi
          ;;
      esac
      ;;
    G)
      tier=$f1; desc=$f2; hasproj=$f3; proj=$f4
      if [ "$tier" = 1 ]; then
        reason="gcloud destructive (Tier 1): $desc"
        if [ "$hasproj" = 1 ] && [ -n "$proj" ] && ! is_prod "$proj"; then
          consider 3 ask "Tier 1 destructive op. project=$proj -- $reason. Bypass via inline SRE_GUARD_BYPASS=<reason>."
        elif [ "$hasproj" = 1 ] && [ -n "$proj" ]; then
          consider 4 deny "ops-write-guard：已擋下 production 的 gcloud 破壞性操作。project=$proj -- ${reason}。--project 的名稱判定為 production。$DENY_TAIL"
        else
          consider 4 deny "ops-write-guard：已擋下 gcloud 破壞性操作。project=<未指定> -- ${reason}。沒有用 --project 明確指定專案，無法排除 production。目標確定不是 production 時，加上 --project=<專案> 重試會改成一般確認；否則$DENY_TAIL"
        fi
      else
        g2_pending="gcloud mutating (Tier 2)"
      fi
      ;;
  esac
done <<EOF
$records
EOF

# gcloud Tier 2 沒有自己的 production 判斷：同一條指令有 kubectl 時沿用它的 context（現行行為）
if [ -n "$g2_pending" ]; then
  r_label="<unknown>"; r_prod=0
  [ $first_k -eq 1 ] && resolve "$k1_mode" "$k1_ctx" "$k1_eff"
  if [ $r_prod -eq 1 ]; then
    consider 3 ask "Tier 2 mutating on PRODUCTION. context=$r_label ns=<default> -- $g2_pending. Bypass via inline SRE_GUARD_BYPASS=<reason>."
  else
    consider 1 msg "[ops-write-guard] Tier 2 non-prod -- context=$r_label ns=<default> ($g2_pending)"
  fi
fi

if [ "$best_dec" = deny ]; then
  emit deny "$best_text"
  exit 0
fi

# --- bypass：只對 deny 以外的情況有效，reason 不可為空 ---
bypass=""
if [[ $cmd =~ (^|[[:space:]\;\&\|])SRE_GUARD_BYPASS=([^[:space:]\;\&\|]*) ]]; then
  bypass=${BASH_REMATCH[2]}
  bypass=${bypass//\"/}
  bypass=${bypass//\'/}
fi
if [ -n "$bypass" ]; then
  emit allow "ops-write-guard bypass: $bypass"
  exit 0
fi

case "$best_dec" in
  ask) emit ask "$best_text" ;;
  msg) jq -n --arg m "$best_text" '{systemMessage:$m}' ;;
esac
exit 0
