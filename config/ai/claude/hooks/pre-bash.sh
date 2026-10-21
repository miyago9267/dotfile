#!/usr/bin/env bash
# PreToolUse(Bash) dispatcher：一個 bash process 依序跑六個 guard，取代六個獨立 hook。
# 每個 guard 是各自檔案裡的函式（檔案單獨執行時行為不變），在 subshell 內執行（fork，不另開 bash）。
# 原本六個 hook 平行執行、由 Claude 合併結果；這裡用同樣的優先序：
#   deny > ask > allow；同級取檔案順序第一個（auto-yes, git-add, commit-attribution, ops-write, destructive, secret）。
#   auto-yes 的 updatedInput 與 ops-write 的 systemMessage 與決定無關，會併入最後輸出。
set -u
command -v jq >/dev/null 2>&1 || exit 0
D=${BASH_SOURCE[0]}; case $D in */*) D=${D%/*} ;; *) D=. ;; esac
input=$(cat)
eval "$(printf '%s' "$input" | jq -r '"cmd=\(.tool_input.command // "" | @sh)\ncwd=\(.cwd // "" | @sh)"' 2>/dev/null)"
cmd=${cmd-}; cwd=${cwd-}
while [[ $cmd == *$'\n' ]]; do cmd=${cmd%$'\n'}; done
[ -z "$cmd" ] && exit 0
INPUT=$input CMD=$cmd

. "$D/auto-yes.sh"
. "$D/git-add-guard.sh"
. "$D/commit-attribution-guard.sh"
. "$D/ops-write-guard.sh"
. "$D/destructive-guard.sh"
. "$D/secret-guard.sh"

deny="" ask="" allow="" upd="" msgs=""
collect() { # output
  local o=$1
  [ -z "$o" ] && return 0
  case "$o" in
    *'"permissionDecision": "deny"'*) [ -z "$deny" ] && deny=$o ;;
    *'"permissionDecision": "ask"'*) [ -z "$ask" ] && ask=$o ;;
    *'"permissionDecision": "allow"'*) [ -z "$allow" ] && allow=$o
      case "$o" in *'"updatedInput"'*) [ -z "$upd" ] && upd=$o ;; esac ;;
    *) msgs=$o ;;   # 只有 systemMessage
  esac
}
collect "$(guard_auto_yes)"
collect "$(guard_git_add)"
collect "$(guard_commit_attribution)"
collect "$(guard_ops_write)"
collect "$(guard_destructive)"
collect "$(guard_secret)"

win=${deny:-${ask:-$allow}}
if [ -z "$win" ]; then
  [ -n "$msgs" ] && printf '%s\n' "$msgs"
  exit 0
fi
# 沒有要併入的東西時原樣輸出
if [ -z "$msgs" ] && { [ -z "$upd" ] || [ "$win" = "$upd" ] || [ -n "$deny" ]; }; then
  printf '%s\n' "$win"
  exit 0
fi
extra='{}'
[ -n "$msgs" ] && extra=$(printf '%s' "$msgs")
if [ -n "$upd" ] && [ "$win" != "$upd" ] && [ -z "$deny" ]; then
  jq -n --argjson w "$win" --argjson m "$extra" --argjson u "$upd" \
    '$w + $m | .hookSpecificOutput.updatedInput = $u.hookSpecificOutput.updatedInput'
else
  jq -n --argjson w "$win" --argjson m "$extra" '$w + $m'
fi
exit 0
