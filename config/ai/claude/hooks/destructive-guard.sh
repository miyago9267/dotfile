#!/bin/bash
# PreToolUse(Bash)：擋下不可逆的 local/git/DB 操作。
# SQL 的 DROP TABLE/DATABASE/SCHEMA 與 TRUNCATE：確定會送進資料庫 client 或直譯器執行時回 deny
# （bypassPermissions 模式下也擋，由 Miyago 自己在 terminal 執行）；只是搜尋、列印或提到字樣的指令不 deny。
# 其餘規則回 ask：一般模式會跳確認，bypassPermissions 模式下不擋（Miyago 的選擇）。
# 本機 git 的 reset --hard、clean 不擋（2026-10-10 Miyago 決定）；force push 與刪遠端 branch/tag 仍 ask。
# 取代原本的 safe-ops skill；kubectl/gcloud 由 ops-write-guard.sh 處理，git add 由 git-add-guard.sh 處理。
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# --- SQL：看字樣會不會被執行 ---
# awk 把指令切成 pipeline / simple command（認得引號、$'..'、$() 與 heredoc），`bash -c "..."` 這類帶空白的
# 字串參數、以及 pipe 或 heredoc 餵給 shell 的內容會當成指令再掃一次。每條 pipeline 分三種：
#   執行者：有資料庫 client（psql、mysql ...），或直譯器以 -c / -e / stdin 執行字串（python3 -c、node -e、python3 - <<EOF）
#   不執行：整條都是 echo、grep、rg、git、head、ls 這類只印字、只讀字或只動檔名的指令
#   其他：  不確定（測試 runner、自訂 script ...）
# 輸出 deny：執行者的 pipeline 出現 DROP TABLE/DATABASE/SCHEMA 或 TRUNCATE（不帶 TABLE 的 TRUNCATE 只認資料庫 client）
#      ask： 字樣出現在「其他」的 pipeline，或整條指令另有執行者（沿用改版前的行為）
#      askiv：執行者的 pipeline 出現 DROP INDEX / VIEW
sql_scan() {
  GUARD_CMD="$1" awk '
function enqueue(s) { if (qn < 300) queue[qn++] = s }
function base(w) { sub(/^.*\//, "", w); return w }
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
# s[i] 是 $( 的左括號：找到對應的右括號，內容排進 queue 另外掃，也留在外層 token 裡
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
  x = substr(s, i + 1, j - i - 1)
  enqueue(x); tok = tok " " x " "
  return j + 1
}
function sub_tick(s, i,    n, j, x) {
  n = length(s); j = i + 1
  while (j <= n && substr(s, j, 1) != "`") { if (substr(s, j, 1) == "\\") j++; j++ }
  x = substr(s, i + 1, j - i - 1)
  enqueue(x); tok = tok " " x " "
  return j + 1
}
function endtok() { if (intok) { cn[cur]++; ct[cur, cn[cur]] = tok; cw[cur, cn[cur]] = (tok ~ /[ \t\n]/) } tok = ""; intok = 0 }
function endcmd() { if (cn[cur] > 0) { cp[cur] = pipe; ncmd = cur; cur = ncmd + 1; cn[cur] = 0 } }
function scan(s,    n, i, c, d, j, x, np, pend, pp) {
  n = length(s); i = 1; tok = ""; intok = 0; np = 0
  pipe = ++npipe; cur = ncmd + 1; cn[cur] = 0
  while (i <= n) {
    c = substr(s, i, 1); d = substr(s, i + 1, 1)
    if (c == "\\") { if (d == "\n") { i += 2; continue } tok = tok d; intok = 1; i += 2; continue }
    if (c == "$" && d == "\047") {   # $'"'"'...'"'"'：反斜線可以跳脫單引號
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
# 把 command k 的參數（指令名之後）當成指令再掃：整串一次，帶空白的參數各一次
function rescan_args(k,    x, s) {
  s = ""
  for (x = cj[k] + 1; x <= cn[k]; x++) { s = s " " ct[k, x]; if (cw[k, x]) enqueue(ct[k, x]) }
  if (s != "") enqueue(s)
}
function analyze(k,    m, j, t, w, x, b, p, k2, pos, flagexec) {
  m = cn[k]; p = cp[k]
  for (j = 1; j <= m; j++) {
    t = ct[k, j]
    if ((t in KW) || t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    break
  }
  cj[k] = j
  if (j > m) { cnx[k] = 1; return }   # 只有變數指定
  w = base(ct[k, j]); cwd[k] = w
  if (w != "truncate") for (x = 1; x <= m; x++) txt[p] = txt[p] " " ct[k, x]   # coreutils 的 truncate 不是 SQL

  if (w == "xargs") {   # xargs 看它實際要跑的指令
    for (x = j + 1; x <= m; x++) {
      t = ct[k, x]
      if (t ~ /^-[nIPLdsE]$/) { x++; continue }
      if (t ~ /^-/) continue
      break
    }
    if (x <= m && (base(ct[k, x]) in NONEXEC)) { cnx[k] = 1; return }
  } else if (w == "find") {
    for (x = j + 1; x <= m; x++) if (ct[k, x] ~ /^-(exec|execdir|ok|okdir)$/) break
    if (x > m) { cnx[k] = 1; return }
  } else if (w in NONEXEC) {
    cnx[k] = 1
    # git -c alias.x="!cmd" 會執行 cmd
    if (w == "git") for (x = j + 1; x <= m; x++) if (ct[k, x] ~ /^alias\.[^=]*=!/) { t = ct[k, x]; sub(/^[^=]*=!/, "", t); enqueue(t) }
    return
  }
  ex[p] = 1
  for (x = j; x <= m; x++) {
    b = base(ct[k, x])
    if (b in CLIENT) cli[p] = 1
    if (b ~ /^(python[0-9.]*|node|nodejs|bun|deno|ruby|perl|php)$/) {
      # 直譯器：第一個位置參數之前有 -c / -e 這類旗標、位置參數是 - 或 eval、或完全沒有位置參數（讀 stdin）
      pos = 0; flagexec = 0
      for (k2 = x + 1; k2 <= m; k2++) {
        t = ct[k, k2]
        if (t ~ /^[0-9]*[<>]/) continue
        if (t ~ /^(-c|-e|-p|-E|-r|--eval|--print)$/) { flagexec = 1; break }
        if (t == "-" || t == "eval") { flagexec = 1; break }
        if (t ~ /^-/) continue
        pos = 1; break
      }
      if (flagexec || !pos) itp[p] = 1
      break
    }
  }
  if (w in SHELL) {
    pos = 0
    for (x = j + 1; x <= m; x++) { t = ct[k, x]; if (t ~ /^-/ || t ~ /^[0-9]*[<>]/) continue; pos = 1; break }
    if (!pos) {   # shell 從 stdin 讀指令：同一條 pipeline 前面印出來的字、heredoc 都是指令
      shin[p] = 1
      for (k2 = 1; k2 < k; k2++) if (cp[k2] == p && cnx[k2]) rescan_args(k2)
    }
  }
  for (x = j + 1; x <= m; x++) if (cw[k, x]) enqueue(ct[k, x])
}
BEGIN {
  n = split("echo printf git gh glab grep egrep fgrep rg ag sed awk gawk jq yq cat bat tee head tail wc sort uniq cut tr less more ls ll stat file mv cp mkdir touch cd pwd basename dirname diff test [ true false : man which type", a, " ")
  for (i = 1; i <= n; i++) NONEXEC[a[i]] = 1
  n = split("{ } if then else elif fi do done while until ! time function", a, " "); for (i = 1; i <= n; i++) KW[a[i]] = 1
  n = split("psql mysql mariadb sqlite3 sqlite sqlcmd clickhouse-client clickhouse duckdb cockroach pgcli mycli litecli usql mysqlsh sqlplus snowsql bq tsql isql osql trino presto impala-shell spanner-cli turso", a, " ")
  for (i = 1; i <= n; i++) CLIENT[a[i]] = 1
  n = split("bash sh zsh dash ksh", a, " "); for (i = 1; i <= n; i++) SHELL[a[i]] = 1

  dk = 0; dh = 0
  enqueue(ENVIRON["GUARD_CMD"])
  while (qh < qn || dk < ncmd || dh < nh) {
    if (qh < qn) { scan(queue[qh++]); continue }
    if (dk < ncmd) { dk++; analyze(dk); continue }
    dh++
    txt[hp[dh]] = txt[hp[dh]] " " hb[dh]
    if (shin[hp[dh]]) enqueue(hb[dh])
  }
  anyexec = 0
  for (p = 1; p <= npipe; p++) if (cli[p] || itp[p]) anyexec = 1
  deny = 0; ask = 0; askiv = 0
  for (p = 1; p <= npipe; p++) {
    if (txt[p] == "") continue
    t = tolower(txt[p]); gsub(/[\n\t\r]/, " ", t); gsub(/\/\*[^*]*\*\//, " ", t)
    hard = (t ~ /(^|[^a-z0-9_])drop +(table|database|schema)([^a-z0-9_]|$)/ || t ~ /(^|[^a-z0-9_-])truncate +table([^a-z0-9_]|$)/)
    if ((cli[p] || itp[p]) && hard) deny = 1
    if (cli[p] && t ~ /(^|[^a-z0-9_-])truncate +(only +)?["`]?[a-z_]/) deny = 1
    if ((cli[p] || itp[p]) && t ~ /(^|[^a-z0-9_])drop +(materialized +)?(index|view)([^a-z0-9_]|$)/) askiv = 1
    # 改版前的字面比對（沒有邊界）：不確定會不會執行、或整條指令另有執行者時維持 ask
    if (t ~ /drop +(table|database|schema)|truncate +table/ && (ex[p] || anyexec)) ask = 1
  }
  print (deny ? "deny" : (ask ? "ask" : (askiv ? "askiv" : "")))
}'
}
sql_literal() { printf '%s' "$cmd" | grep -qiE '(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)'; }
if [ ${#cmd} -gt 65536 ]; then
  # 指令過長不做完整解析（逐字掃描的成本隨長度平方成長）：字面命中就 ask
  sql=""
  sql_literal && sql=ask
elif sql=$(sql_scan "$cmd"); then
  :
else
  # 解析失敗時退回字面比對
  sql=""
  sql_literal && sql=ask
fi
if [ "$sql" = deny ]; then
  jq -n --arg r "destructive-guard：已擋下 DROP / TRUNCATE。這會永久刪除資料或結構、無法復原，agent 不代為執行；請 Miyago 確認目標資料庫後，自己在 terminal 執行。" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi

reason=""
sep='(^|[[:space:];&|`(])'
# 拿掉 git 全域參數（-C path、-c k=v、--git-dir= 等），讓 git -C x reset --hard 也比對得到
cmd=$(printf '%s' "$cmd" | sed -E ':a
s/(git)[[:space:]]+(-C|-c)[[:space:]]+[^[:space:];&|]+/\1/g
s/(git)[[:space:]]+(--git-dir|--work-tree|--namespace)=[^[:space:];&|]+/\1/g
s/(git)[[:space:]]+(--no-pager|--bare|-P)([[:space:]])/\1\3/g
ta')

# rm -rf / -fr，目標全部在 temp 目錄或專案內相對路徑才放行
if printf '%s' "$cmd" | grep -qE "${sep}rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|-r[[:space:]]+-f|-f[[:space:]]+-r)"; then
  targets=$(printf '%s' "$cmd" | grep -oE "${sep}rm[[:space:]]+[^;&|]*" | sed -E 's/^[^r]*rm[[:space:]]+//' | tr ' ' '\n' | grep -vE '^-|^$' || true)
  bad=$(printf '%s\n' "$targets" | grep -vE '^("|'"'"')?(/tmp/|/private/tmp/|\$TMPDIR|/var/folders/)' | grep -v '^$' || true)
  # 專案內的相對路徑（不含 ..、不是 . 或 * 本身、不是 .git）也放行；指令裡有 cd 到絕對路徑、~、$VAR 或 .. 時不適用
  if ! printf '%s' "$cmd" | grep -qE "${sep}cd[[:space:]]+[\"']?(/|~|\\$|\.\.)"; then
    bad=$(printf '%s\n' "$bad" | grep -vE '^("|'"'"')?(\./)?\.?[A-Za-z0-9_][^[:space:]]*$' || true)
    rel=$(printf '%s\n' "$targets" | grep -E '(^|/)\.\.(/|"|'"'"'|$)|^("|'"'"')?(\./)?\.git("|'"'"'|/|$)' || true)
    bad=$(printf '%s\n%s\n' "$bad" "$rel" | grep -v '^$' | sort -u || true)
  fi
  [ -n "$bad" ] && reason="rm -rf 目標不在專案內或 temp 目錄：$(printf '%s' "$bad" | head -3 | tr '\n' ' ')"
fi

if [ -z "$reason" ]; then
  if printf '%s' "$cmd" | grep -qE "${sep}git[[:space:]]+push([[:space:]][^;&|]*)?[[:space:]](--force([[:space:]]|=|$)|--force-with-lease|-f([[:space:]]|$)|\+[^[:space:]]+)"; then
    reason="force push 會改寫遠端歷史"
  elif printf '%s' "$cmd" | grep -qE "${sep}git[[:space:]]+push([[:space:]][^;&|]*)?[[:space:]](--delete|-d([[:space:]]|$)|:[^[:space:]]+)"; then
    reason="會刪除遠端分支或 tag"
  elif [ "$sql" = ask ]; then
    reason="DROP / TRUNCATE 會永久刪資料"
  elif [ "$sql" = askiv ]; then
    reason="DROP INDEX / VIEW 會移除資料庫結構（不刪資料，可由定義重建）"
  elif printf '%s' "$cmd" | grep -qE "${sep}sudo([[:space:]]|$)"; then
    reason="規則禁止 sudo/root"
  fi
fi

[ -z "$reason" ] && exit 0
jq -n --arg r "destructive-guard: ${reason}。先向 Miyago 說明 target、影響範圍與 rollback。" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
