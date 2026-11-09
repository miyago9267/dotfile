#!/bin/bash
# secret-guard 的跨 runtime 轉接層：把各 host 的 PreToolUse 輸入轉成
# config/ai/claude/hooks/secret-guard.sh 要的 JSON（.tool_input.command 與 .cwd），
# 再把它的 deny 轉成該 host 的回傳格式。codex / opencode 只做格式轉換；agy 另外套用分級政策（見下）。
# guard 回 allow、updatedInput、systemMessage 一律不轉交。
#
# 用法：secret-guard-adapter.sh --host <codex|agy|opencode>   （hook JSON 由 stdin 進來）
#   codex    輸入輸出與 Claude 相同，原樣轉交。setup_codex.sh 目前直接掛 secret-guard.sh，
#            這個分支只在 Codex 的格式日後與 Claude 分岔時才需要。guard 的 ask 不轉交。
#   agy      輸入 {cwd, toolCall:{name, args}}；輸出 {"decision":"deny"|"force_ask","reason":…}，放行時無輸出。
#            agy 跑在 toolPermission: always-proceed，hook 是唯一的關卡。分級（取最嚴格：deny > force_ask > 放行）：
#              放行      一般檔案操作與版控（git add -A、commit、一般 push、專案內 rm、npm/bun install）；
#                        不跑 git-add-guard 與 auto-yes。
#              deny      commit-attribution-guard 的 deny（原 reason，讓 agy 改寫 message）；
#                        destructive-guard、ops-write-guard 回 ask 或 deny（force push、專案外 rm -rf、sudo、
#                        prod kubectl/gcloud 寫入等），reason 請 Miyago 複製指令自己在 terminal 執行。
#              force_ask secret-guard 回 deny 或 ask（讀出憑證、印出 secret），由 Miyago 在 agy 的 prompt 核准。
#            run_command 取 args 的 CommandLine；read_file 取 args 的 Path，組成 `cat <Path>` 只交給
#            secret-guard 判斷（同一份憑證路徑表），不跑其他 guard。
#            其他 guard 從 secret-guard.sh 所在目錄找，缺檔就略過。
#   opencode 輸入由 config/opencode/plugins/secret-guard.js 組成 {command, cwd}；輸出 deny 格式同 agy，由 plugin 轉成 throw
#
# 這層是防合作型 agent 的意外外洩，不是硬邊界：缺 jq、host 不認得、輸入不是預期格式、
# 找不到 secret-guard.sh 時一律無輸出並 exit 0（fail-open，與 secret-guard.sh 缺 jq 時一致）。
# SECRET_GUARD 可覆寫被呼叫的 secret-guard 路徑（測試用）；必須指向 secret-guard.sh 本身，不是 pre-bash.sh。
# shellcheck disable=SC2016  # jq 程式裡的 $ 是 jq 變數，不是 shell 展開
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

host=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host) host="${2:-}"; [ $# -ge 2 ] && shift; shift ;;
    --host=*) host="${1#--host=}"; shift ;;
    *) shift ;;
  esac
done

# 自己的實際位置（經 symlink 掛載時也要找得到 guard）
self="${BASH_SOURCE[0]}"
while [ -L "$self" ]; do
  link=$(readlink "$self")
  case "$link" in /*) self="$link" ;; *) self="$(dirname "$self")/$link" ;; esac
done
self_dir=$(cd "$(dirname "$self")" && pwd -P)
guard="${SECRET_GUARD:-$self_dir/../../claude/hooks/secret-guard.sh}"
[ -f "$guard" ] || exit 0

input=$(cat)

# 指令字串的鍵名：agy 的 run_command 與 OpenCode 的 bash 參數鍵名沒有文件，常見寫法都試。
# 值是陣列時（argv 形式）：["bash","-lc","…"] 取腳本字串，其餘以空白接起來。
norm='
def cmdstr:
  if type == "string" then .
  elif type == "array" and all(.[]; type == "string") then
    (if length >= 3 and (.[1] | test("^-[A-Za-z]*c$")) then .[2] else join(" ") end)
  else empty end;
def firststr(keys): . as $o | first(keys[] as $k | $o[$k]? | cmdstr | select(. != "")) // "";
def dirstr(keys): . as $o | first(keys[] as $k | $o[$k]? | select(type == "string" and . != "")) // "";
'
case "$host" in
  codex)
    filter='{cwd: (dirstr(["cwd"])), tool_input: {command: ((.tool_input // {}) | firststr(["command"]))}}' ;;
  agy)
    # read_file 的 Path 組成 cat 指令：~/ 與 $HOME/ 保留展開語意，其餘單引號包起來，不會被當成多段指令
    filter='def readcmd:
        if . == "" then ""
        elif startswith("~/") then "cat ~/" + (.[2:] | @sh)
        elif startswith("$HOME/") then "cat \"$HOME\"/" + (.[6:] | @sh)
        elif startswith("${HOME}/") then "cat \"$HOME\"/" + (.[8:] | @sh)
        else "cat " + @sh end;
      (.toolCall.args // {}) as $a
      | ((.toolCall | objects | .name | strings) // "") as $t
      | {cwd: (($a | dirstr(["Cwd", "cwd"])) as $c | if $c != "" then $c else dirstr(["cwd"]) end),
         tool_input: {command: (if $t == "read_file"
           then ($a | dirstr(["Path", "path", "AbsolutePath", "FilePath", "file_path"]) | readcmd)
           else ($a | firststr(["CommandLine", "commandLine", "command", "Command", "cmd"])) end)},
         kind: (if $t == "read_file" then "read" else "run" end)}' ;;
  opencode)
    filter='{cwd: (dirstr(["cwd"])),
         tool_input: {command: (firststr(["command"]) as $c | if $c != "" then $c else ((.args // {}) | firststr(["command", "cmd", "script"])) end)}}' ;;
  *)
    exit 0 ;;
esac

payload=$(printf '%s' "$input" | jq -c "$norm $filter" 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

if [ "$host" = agy ]; then
  # guard 的 deny 或 ask 取 reason；沒有命中、檔案不存在或輸出不是 JSON 時為空
  verdict() {
    [ -f "$1" ] || return 0
    printf '%s' "$payload" | bash "$1" 2>/dev/null | jq -r '.hookSpecificOutput? | objects
      | select(.permissionDecision == "deny" or .permissionDecision == "ask")
      | .permissionDecisionReason // "guard 要求人工確認"' 2>/dev/null | head -n 1
  }
  kind=$(printf '%s' "$payload" | jq -r '.kind' 2>/dev/null)
  payload=$(printf '%s' "$payload" | jq -c 'del(.kind)' 2>/dev/null) || exit 0
  gdir=$(dirname "$guard")
  reason=""
  if [ "$kind" = run ]; then
    reason=$(verdict "$gdir/commit-attribution-guard.sh")
    # destructive-guard 只放行專案內的相對路徑；agy 常寫絕對路徑，所以把嚴格位於 cwd 底下的絕對路徑
    # （含 ~/、$HOME/，收掉 . 與 ..）改寫成 ./相對路徑 再交給它。cwd 是 /、$HOME 或 $HOME 的上層時不改寫，
    # 指令裡有 cd / pushd 時也不改寫（之後的相對路徑不再以 cwd 為準）。只有 destructive-guard 看改寫後的指令。
    ws=$(printf '%s' "$payload" | jq -r '.tool_input.command' 2>/dev/null \
      | WS_CWD=$(printf '%s' "$payload" | jq -r '.cwd' 2>/dev/null) awk -v home="${HOME:-}" '
      function norm(p,   n, a, k, top, seg, out) {
        n = split(p, a, "/"); top = 0
        for (k = 1; k <= n; k++) {
          if (a[k] == "" || a[k] == ".") continue
          if (a[k] == "..") { if (top > 0) top--; continue }
          seg[++top] = a[k]
        }
        out = ""; for (k = 1; k <= top; k++) out = out "/" seg[k]
        return out == "" ? "/" : out
      }
      { s = (NR == 1 ? "" : s "\n") $0 }
      END {
        cwd = ENVIRON["WS_CWD"]; c = s
        if (substr(cwd, 1, 1) != "/") { printf "%s", c; exit }
        cwd = norm(cwd); h = (home == "") ? "" : norm(home)
        if (cwd == "/" || cwd == h || (h != "" && index(h, cwd "/") == 1) || c ~ /(^|[[:space:];&|(`])(cd|pushd)([[:space:]]|$)/) { printf "%s", c; exit }
        out = ""
        while (match(c, /[^[:space:]]+/)) {
          out = out substr(c, 1, RSTART - 1); t = substr(c, RSTART, RLENGTH); c = substr(c, RSTART + RLENGTH)
          tail = ""; if (match(t, /[;&|)]+$/)) { tail = substr(t, RSTART); t = substr(t, 1, RSTART - 1) }
          p = t; q1 = substr(p, 1, 1)
          if ((q1 == "\"" || q1 == "\047") && length(p) > 1 && substr(p, length(p)) == q1) p = substr(p, 2, length(p) - 2)
          if (h != "" && q1 != "\047" && index(p, "$HOME/") == 1) p = h substr(p, 6)
          else if (h != "" && q1 != "\047" && index(p, "${HOME}/") == 1) p = h substr(p, 8)
          else if (h != "" && q1 != "\"" && q1 != "\047" && index(p, "~/") == 1) p = h substr(p, 2)
          if (substr(p, 1, 1) == "/" && p !~ /["\047\\$`*?[]/) {
            p = norm(p)
            if (index(p, cwd "/") == 1) t = "./" substr(p, length(cwd) + 2)
          }
          out = out t tail
        }
        printf "%s", out c
      }')
    wspayload=$(printf '%s' "$payload" | jq -c --arg c "$ws" '.tool_input.command = $c' 2>/dev/null) || wspayload=$payload
    if [ -z "$reason" ]; then
      for g in destructive-guard.sh ops-write-guard.sh; do
        if [ "$g" = destructive-guard.sh ] && [ -n "$ws" ]; then r=$(payload=$wspayload verdict "$gdir/$g"); else r=$(verdict "$gdir/$g"); fi
        [ -n "$r" ] && { reason="${r} agy 不代為執行不可逆或高風險操作：請 Miyago 複製這個指令，自己在 terminal 執行。"; break; }
      done
    fi
  fi
  if [ -n "$reason" ]; then
    jq -n --arg r "$reason" '{decision:"deny",reason:$r}'
    exit 0
  fi
  reason=$(verdict "$guard")
  [ -n "$reason" ] || exit 0
  jq -n --arg r "${reason} Miyago 在 agy 的確認提示核准後，內容會進入 agent context。" '{decision:"force_ask",reason:$r}'
  exit 0
fi

out=$(printf '%s' "$payload" | bash "$guard" 2>/dev/null) || exit 0
reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput | select(.permissionDecision == "deny") | .permissionDecisionReason // "secret-guard: denied"' 2>/dev/null)
[ -n "$reason" ] || exit 0

case "$host" in
  codex)
    jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' ;;
  *)
    jq -n --arg r "$reason" '{decision:"deny",reason:$r}' ;;
esac
