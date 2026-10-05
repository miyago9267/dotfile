#!/bin/bash
# PreToolUse(Bash)：擋下會把本機憑證印進 context 的 CLI 子指令。
# 用 deny：任何 permission mode 都不放行，需要時由 Miyago 自己在 terminal 執行。
# 擋的範圍：
#   - kubectl config view --raw/--flatten
#   - gcloud auth print-{access,identity}-token、gcloud auth application-default print-access-token
#   - security find-generic-password / find-internet-password / dump-keychain / export /
#     unlock-keychain（含唯一前綴寫法），以及 security -i（-p 隱含 -i）
#   - sec show、sec export、sec edit
#   - agent-secret edit、agent-secret2 edit（互動式編輯在 agent 手上沒有正當用途，不論 EDITOR 為何）
#   - 任何目標檔在 ~/dotfile/secrets/ 底下的 sops（解密、編輯、加密都算；--version、--help 沒有目標檔）
# sops：Miyago 原本決定完全不擋；2026-10-05 起擋目標在 ~/dotfile/secrets/ 的 sops，
# 其餘（工作 repo 的 sops -d、加密、編輯）維持不擋。gcloud secrets、kubectl get secret
# 仍是 Miyago 決定不擋的，不要加進來。agent 取用個人 secret 一律走 agent-secret run。
# 威脅模型是合作型 agent 的意外外洩；bash -c、eval、變數或 alias 展開等主動規避不處理。
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
user=$(id -un 2>/dev/null || true)

# 比對策略：依 shell 引號規則把指令切成「段」（; & | 換行 ( ) $( ` 分段，引號內不分段），
# 每段跳過前置的 VAR=值、shell 關鍵字、開頭的 redirect，以及 command/env/sudo/xargs 這類包裝
# （含它們帶值的選項），取執行檔的 basename；執行檔是 shell 時改看它後面的腳本路徑。
# 是 kubectl / gcloud / security / sec / agent-secret / sops 才看後面的 word。
# 引號內只是提及的字串因此不會命中。
# heredoc（<<W、<<'W'、<<"W"、<<-W）的內文不是指令，整段跳過。只有後面確實找得到結束行才跳；
# $(( )) 與 (( )) 內的 << 是位移，不算 heredoc。內文真的會被執行時也不跳，照一般指令逐行檢查：
# 起始行上有任何一段是 shell 或 source / .（含經 pipe 接過去）、起始行以 | 結尾、
# 或 delimiter 沒加引號且內文含 $( 或反引號。
# sops 的目標路徑：~/、~<目前帳號>/、$HOME/、${HOME}/ 與絕對路徑直接比對；相對路徑以 hook 輸入的 cwd 解析。
hit=$(printf '%s' "$cmd" | awk -v home="${HOME:-}" -v cwd="$cwd" -v user="$user" '
function flushword() { if (hasw) words[++nw] = w; w = ""; hasw = 0 }
function endseg() { flushword(); if (nw > 0) { if (segshell()) lineshell = 1; if (hit == "") check() }; nw = 0 }
function isassign(x) { return x ~ /^[A-Za-z_][A-Za-z0-9_]*=/ }
function base(x) { sub(/.*\//, "", x); return x }
# 把路徑的 . 與 .. 與重複的 / 收掉（純字串處理，不解 symlink）
function norm(p,   n, parts, k, top, seg, out) {
  n = split(p, parts, "/"); top = 0
  for (k = 1; k <= n; k++) {
    if (parts[k] == "" || parts[k] == ".") continue
    if (parts[k] == "..") { if (top > 0) top--; continue }
    seg[++top] = parts[k]
  }
  out = ""
  for (k = 1; k <= top; k++) out = out "/" seg[k]
  return out
}
function insecrets(x,   p) {
  if (home == "") return 0
  p = x
  sub(/^--[A-Za-z-]+=/, "", p)
  if (p ~ /^-/ || (p in sopssub)) return 0   # 選項與子指令不是路徑
  if (substr(p, 1, 2) == "~/") p = home substr(p, 2)
  else if (user != "" && index(p, "~" user "/") == 1) p = home substr(p, length(user) + 2)
  else if (index(p, "$HOME/") == 1) p = home substr(p, 6)
  else if (index(p, "${HOME}/") == 1) p = home substr(p, 8)
  if (substr(p, 1, 1) != "/") { if (cwd == "") return 0; p = cwd "/" p }
  p = norm(p)
  return (p == secdir || index(p, secdir "/") == 1)
}
# 本段執行檔在 words[] 的位置；沒有則回 0
function cmdpos(   i, x, wn) {
  i = 1
  while (i <= nw) {
    x = words[i]
    if (isassign(x) || (x in kw)) { i++; continue }
    if (x ~ /^[0-9]*(>|>>|<|>&)$/) { i += 2; continue }   # redirect 與目標分開寫：> file
    if (x ~ /^[0-9]*[<>]/) { i++; continue }              # 2>/dev/null、>file、2>&1
    wn = base(x)
    if (wn in wrap) {
      i++
      while (i <= nw && (words[i] ~ /^-/ || isassign(words[i]))) {
        if (index(" " optval[wn] " ", " " words[i] " ") > 0) i++   # 帶值的選項：連值一起跳過
        i++
      }
      continue
    }
    break
  }
  return (i <= nw) ? i : 0
}
# 這一段會不會把 stdin 當指令執行：shell，或 source / .
function segshell(   i, b) {
  i = cmdpos(); if (!i) return 0
  b = base(words[i])
  return ((b in shells) || b == "source" || b == ".") ? 1 : 0
}
function check(   i, j, b, x, st, flag, k) {
  i = cmdpos()
  if (!i) return
  b = base(words[i])
  if (b in shells) {
    # bash script args：把腳本當成指令看。-c 的字串看不到（主動規避，non-goal）
    j = i + 1; flag = 0
    while (j <= nw && words[j] ~ /^[-+]/) { if (words[j] ~ /^-[A-Za-z]*c/) flag = 1; j++ }
    if (flag || j > nw) return
    i = j; b = base(words[i])
  }
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
  } else if (b == "security") {
    for (j = i + 1; j <= nw; j++) {
      x = words[j]
      # 全域選項 -h -i -l -p prompt -q -v 可以併寫；-p 隱含 -i
      if (x ~ /^-[hlqv]*[ip]/) { hit = "security -i 會從 stdin 讀指令，看不到實際執行的子指令"; break }
      if (x ~ /^-/) continue
      # 第一個非選項 word 是子指令；security 接受唯一前綴，所以用前綴比對
      for (k in secsub) if (index(k, x) == 1) hit = "security " k " 會讀出或匯出 Keychain 內容（secret 改用 agent-secret run 注入）"
      break
    }
  } else if (b == "sec") {
    x = (i + 1 <= nw) ? words[i + 1] : ""
    if (x == "show" || x == "export") hit = "sec " x " 會解密並輸出 ~/dotfile/secrets 的全部 secret"
    else if (x == "edit") hit = "sec edit 會把解密後的 secret 交給編輯器（EDITOR 可以是任何會印出內容的程式）"
  } else if (b == "agent-secret" || b == "agent-secret2") {
    x = (i + 1 <= nw) ? words[i + 1] : ""
    if (x == "edit") hit = b " edit 會把解密後的 secret 交給編輯器（EDITOR 可以是任何會印出內容的程式）"
  } else if (b == "sops") {
    for (j = i + 1; j <= nw; j++) {
      if (insecrets(words[j])) { hit = "sops 操作 ~/dotfile/secrets/ 底下的檔案會解密或開啟個人 secret（改用 agent-secret run 注入）"; break }
    }
  }
}
BEGIN {
  split("if then else elif do while until ! { time", a, " "); for (k in a) kw[a[k]] = 1
  split("command exec env nohup builtin sudo xargs", a, " "); for (k in a) wrap[a[k]] = 1
  split("sh bash zsh dash ksh", a, " "); for (k in a) shells[a[k]] = 1
  optval["env"] = "-u -C -P"
  optval["exec"] = "-a"
  optval["sudo"] = "-u -g -h -p -C -D -R -T -U -r -t"
  optval["xargs"] = "-I -n -P -L -s -E -d -a -J -R -S"
  split("find-generic-password find-internet-password dump-keychain export unlock-keychain", a, " "); for (k in a) secsub[a[k]] = 1
  split("decrypt encrypt edit rotate updatekeys filestatus exec-env exec-file publish keyservice groups set unset help completion", a, " "); for (k in a) sopssub[a[k]] = 1
  secdir = norm(home "/dotfile/secrets")
}
{ s = (NR == 1 ? "" : s "\n") $0 }
END {
  n = length(s); i = 1; sq = 0; dq = 0; bt = 0; sp = 0; nw = 0; w = ""; hasw = 0; hit = ""; nhd = 0
  arith = 0; lineshell = 0; lastsep = ""
  while (i <= n) {
    c = substr(s, i, 1)
    if (sq) { if (c == "\047") sq = 0; else w = w c; i++; continue }
    if (c == "\\") {
      nx = substr(s, i + 1, 1)
      if (nx != "\n") { w = w nx; hasw = 1 }
      i += 2; continue
    }
    # command substitution 在雙引號內也會執行：另起一段，結束時還原外層引號狀態
    if (c == "$" && substr(s, i + 1, 1) == "(") {
      endseg(); stack[++sp] = dq; dq = 0
      if (arith > 0) arith++; else if (substr(s, i + 2, 1) == "(") arith = 1   # $(( 開始算術展開
      i += 2; continue
    }
    if (c == "`") {
      endseg()
      if (bt) { bt = 0; if (sp > 0) dq = stack[sp--] } else { bt = 1; stack[++sp] = dq; dq = 0 }
      i++; continue
    }
    if (dq) { if (c == "\"") dq = 0; else { w = w c; hasw = 1 }; i++; continue }
    if (c == "\047") { sq = 1; hasw = 1; i++; continue }
    if (c == "\"") { dq = 1; hasw = 1; i++; continue }
    if (c == "<" && substr(s, i + 1, 1) == "<") {
      if (arith > 0) { w = w "<<"; hasw = 1; i += 2; continue }                     # 算術裡的位移
      if (substr(s, i + 2, 1) == "<") { w = w "<<<"; hasw = 1; i += 3; continue }   # here-string 不是 heredoc
      # heredoc：記下 delimiter，內文等這一行結束後再處理
      flushword(); i += 2; hs = 0; hq = 0; d = ""; gotd = 0
      if (substr(s, i, 1) == "-") { hs = 1; i++ }
      while (i <= n && (substr(s, i, 1) == " " || substr(s, i, 1) == "\t")) i++
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\047" || c == "\"") {
          q = c; i++
          while (i <= n && substr(s, i, 1) != q) { d = d substr(s, i, 1); i++ }
          i++; gotd = 1; hq = 1; continue
        }
        if (c == "\\") { d = d substr(s, i + 1, 1); i += 2; gotd = 1; hq = 1; continue }
        if (c ~ /[ \t\n;|&()<>]/) break
        d = d c; gotd = 1; i++
      }
      if (gotd) { hd[++nhd] = d; hdstrip[nhd] = hs; hdquoted[nhd] = hq }
      continue
    }
    if (c == " " || c == "\t") { flushword(); i++; continue }
    if (c == "#" && !hasw) { while (i <= n && substr(s, i, 1) != "\n") i++; continue }  # 註解到行尾
    if (c == "&" && i > 1 && substr(s, i - 1, 1) == ">") { w = w c; i++; continue }  # 2>&1 不是分段
    if (c == "\n" || c == ";" || c == "|" || c == "&" || c == "(") {
      openpipe = (c == "\n" && nw == 0 && !hasw && lastsep == "|")   # 這一行以 | 結尾，下游在後面
      endseg(); lastsep = c
      if (c == "(") {
        stack[++sp] = 0
        if (arith > 0) arith++; else if (substr(s, i + 1, 1) == "(") arith = 1   # (( 開始算術指令
      }
      if (c == "\n") {
        if (nhd > 0 && !lineshell && !openpipe) {
          # i 指在 heredoc 起始行結尾的換行：逐份找結束行，找到才跳過內文，停在結束行後面的換行
          for (k = 1; k <= nhd; k++) {
            j = i; body = ""; found = 0
            while (j <= n) {
              ls = j + 1; le = index(substr(s, ls), "\n")
              if (le == 0) { line = substr(s, ls); nxt = n + 1 } else { line = substr(s, ls, le - 1); nxt = ls + le - 1 }
              t = line; if (hdstrip[k]) sub(/^\t+/, "", t)
              if (ls > n + 1) break
              j = nxt
              if (t == hd[k]) { found = 1; break }
              body = body line "\n"
            }
            # 找不到結束行就不是 heredoc；沒加引號的 delimiter 內文含 command substitution 會執行
            if (!found || (!hdquoted[k] && body ~ /\$\(|`/)) break
            i = j
          }
        }
        nhd = 0; lineshell = 0
        if (i > n) break
        if (substr(s, i, 1) == "\n") { i++ }
        continue
      }
      i++; continue
    }
    if (c == ")") { endseg(); if (sp > 0) dq = stack[sp--]; if (arith > 0) arith--; i++; continue }
    w = w c; hasw = 1; i++
  }
  endseg()
  if (hit != "") print hit
}')

[ -z "$hit" ] && exit 0
jq -n --arg r "secret-guard: ${hit}，這個指令會把憑證印進 context。需要時由 Miyago 自己在 terminal 執行。" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
