#!/bin/bash
# secret-guard 的跨 runtime 轉接層：把各 host 的 PreToolUse 輸入轉成
# config/ai/claude/hooks/secret-guard.sh 要的 JSON（.tool_input.command 與 .cwd），
# 再把它的 deny 轉成該 host 的回傳格式。判斷規則只在 secret-guard.sh 維護一份，這裡不做任何判斷。
#
# 用法：secret-guard-adapter.sh --host <codex|agy|opencode>   （hook JSON 由 stdin 進來）
#   codex    輸入輸出與 Claude 相同，原樣轉交。setup_codex.sh 目前直接掛 secret-guard.sh，
#            這個分支只在 Codex 的格式日後與 Claude 分岔時才需要。
#   agy      輸入 {cwd, toolCall:{name, args:{CommandLine, Cwd}}}；命中時輸出 {"decision":"deny","reason":…}
#   opencode 輸入由 config/opencode/plugins/secret-guard.js 組成 {command, cwd}；輸出同 agy，由 plugin 轉成 throw
#
# 這層是防合作型 agent 的意外外洩，不是硬邊界：缺 jq、host 不認得、輸入不是預期格式、
# 找不到 secret-guard.sh 時一律無輸出並 exit 0（fail-open，與 secret-guard.sh 缺 jq 時一致）。
# SECRET_GUARD 可覆寫被呼叫的 guard 路徑（測試用）。
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
    filter='(.toolCall.args // {}) as $a
      | {cwd: (($a | dirstr(["Cwd", "cwd"])) as $c | if $c != "" then $c else dirstr(["cwd"]) end),
         tool_input: {command: ($a | firststr(["CommandLine", "commandLine", "command", "Command", "cmd"]))}}' ;;
  opencode)
    filter='{cwd: (dirstr(["cwd"])),
         tool_input: {command: (firststr(["command"]) as $c | if $c != "" then $c else ((.args // {}) | firststr(["command", "cmd", "script"])) end)}}' ;;
  *)
    exit 0 ;;
esac

payload=$(printf '%s' "$input" | jq -c "$norm $filter" 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

out=$(printf '%s' "$payload" | bash "$guard" 2>/dev/null) || exit 0
reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput | select(.permissionDecision == "deny") | .permissionDecisionReason // "secret-guard: denied"' 2>/dev/null)
[ -n "$reason" ] || exit 0

case "$host" in
  codex)
    jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' ;;
  *)
    jq -n --arg r "$reason" '{decision:"deny",reason:$r}' ;;
esac
