#!/bin/bash
# PreToolUse(Bash)：擋下會把本機憑證印進 context 的 CLI 子指令。
# 用 deny：任何 permission mode 都不放行，需要時由 Miyago 自己在 terminal 執行。
# 只擋三類：kubectl config view --raw/--flatten、gcloud auth print-{access,identity}-token、
# gcloud auth application-default print-access-token。sops、gcloud secrets、kubectl get secret
# 是 Miyago 決定不擋的，不要加進來。
# 威脅模型是合作型 agent 的意外外洩；bash -c、eval、變數或 alias 展開等主動規避不處理。
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# 比對策略：依 shell 引號規則把指令切成「段」（; & | 換行 ( ) $( ` 分段，引號內不分段），
# 每段跳過前置的 VAR=值、shell 關鍵字與 command/env 這類包裝，取執行檔的 basename；
# 是 kubectl / gcloud 才看後面的 word。引號內只是提及的字串因此不會命中。
hit=$(printf '%s' "$cmd" | awk '
function flushword() { if (hasw) words[++nw] = w; w = ""; hasw = 0 }
function endseg() { flushword(); if (nw > 0 && hit == "") check(); nw = 0 }
function isassign(x) { return x ~ /^[A-Za-z_][A-Za-z0-9_]*=/ }
function check(   i, j, b, x, st, flag) {
  i = 1
  while (i <= nw) {
    x = words[i]
    if (isassign(x) || (x in kw)) { i++; continue }
    if (x in wrap) { i++; while (i <= nw && (words[i] ~ /^-/ || isassign(words[i]))) i++; continue }
    break
  }
  if (i > nw) return
  b = words[i]; sub(/.*\//, "", b)
  if (b == "kubectl") {
    # 全域 flag 可能帶值，不維護 flag 表：只要求 config 出現在 view 之前
    st = 0; flag = 0
    for (j = i + 1; j <= nw; j++) {
      x = words[j]
      if (st == 0 && x == "config") st = 1
      else if (st == 1 && x == "view") st = 2
      if (x ~ /^--(raw|flatten)(=|$)/ && x !~ /=false$/) flag = 1
    }
    if (st == 2 && flag) hit = "kubectl config view --raw/--flatten 會印出 kubeconfig 內的 token 與 client key"
  } else if (b == "gcloud") {
    st = 0
    for (j = i + 1; j <= nw; j++) {
      x = words[j]
      if (x == "auth") st = 1
      else if (st == 1 && x ~ /^print-(access|identity)-token$/) { hit = "gcloud auth " x " 會印出可用的 token"; break }
    }
  }
}
BEGIN {
  split("if then else elif do while until ! { time", a, " "); for (k in a) kw[a[k]] = 1
  split("command exec env nohup builtin", a, " "); for (k in a) wrap[a[k]] = 1
}
{ s = (NR == 1 ? "" : s "\n") $0 }
END {
  n = length(s); i = 1; sq = 0; dq = 0; bt = 0; sp = 0; nw = 0; w = ""; hasw = 0; hit = ""
  while (i <= n) {
    c = substr(s, i, 1)
    if (sq) { if (c == "\047") sq = 0; else w = w c; i++; continue }
    if (c == "\\") {
      nx = substr(s, i + 1, 1)
      if (nx != "\n") { w = w nx; hasw = 1 }
      i += 2; continue
    }
    # command substitution 在雙引號內也會執行：另起一段，結束時還原外層引號狀態
    if (c == "$" && substr(s, i + 1, 1) == "(") { endseg(); stack[++sp] = dq; dq = 0; i += 2; continue }
    if (c == "`") {
      endseg()
      if (bt) { bt = 0; if (sp > 0) dq = stack[sp--] } else { bt = 1; stack[++sp] = dq; dq = 0 }
      i++; continue
    }
    if (dq) { if (c == "\"") dq = 0; else { w = w c; hasw = 1 }; i++; continue }
    if (c == "\047") { sq = 1; hasw = 1; i++; continue }
    if (c == "\"") { dq = 1; hasw = 1; i++; continue }
    if (c == " " || c == "\t") { flushword(); i++; continue }
    if (c == "#" && !hasw) { while (i <= n && substr(s, i, 1) != "\n") i++; continue }  # 註解到行尾
    if (c == "&" && i > 1 && substr(s, i - 1, 1) == ">") { w = w c; i++; continue }  # 2>&1 不是分段
    if (c == "\n" || c == ";" || c == "|" || c == "&" || c == "(") {
      endseg(); if (c == "(") stack[++sp] = 0
      i++; continue
    }
    if (c == ")") { endseg(); if (sp > 0) dq = stack[sp--]; i++; continue }
    w = w c; hasw = 1; i++
  }
  endseg()
  if (hit != "") print hit
}')

[ -z "$hit" ] && exit 0
jq -n --arg r "secret-guard: ${hit}，這個指令會把憑證印進 context。需要時由 Miyago 自己在 terminal 執行。" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
