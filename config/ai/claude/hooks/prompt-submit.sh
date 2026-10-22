#!/usr/bin/env bash
# UserPromptSubmit dispatcher：一個 bash process 取代 tty-respond / think-first-router / jev-route。
# stdin 只解析一次。輸出合併成一份 JSON（additionalContext 以空行串接）。
# tty-respond 原本回顯的 JSON（原 payload 或 "[input received]" 改寫）不含 Claude 認得的欄位，已省略；
# 它的副作用（寫 socket / response 檔）與 exit 2（tty: 後面沒有內容）照舊。
# SHOAL_JEV_MODE 沒設成 active|shadow 時不啟動 python。
set -u
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
if parsed=$(printf '%s' "$input" | jq -r '@sh "prompt=\(.prompt // "") cwd=\(.cwd // "")"' 2>/dev/null); then
  eval "$parsed"; is_json=1
else
  prompt=$input; cwd=""; is_json=0
fi
prompt=${prompt-}; cwd=${cwd-}
while [[ $prompt == *$'\n' ]]; do prompt=${prompt%$'\n'}; done

# 路由順序：// 跳脫 > pty-bridge socket > ask-tty pending 檔 > tty:/res: 前綴 > 放行
tty_respond() {
  local ASK_DIR="$HOME/.cache/ask-tty" tty_input
  local SOCK="$ASK_DIR/bridge.sock" PID_FILE="$ASK_DIR/bridge.pid"
  [[ "$prompt" == //* ]] && return 0
  if [ -S "$SOCK" ] && [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    local STATE
    STATE=$(curl -s --unix-socket "$SOCK" http://localhost/state 2>/dev/null)
    if printf '%s' "$STATE" | jq -e '.status == "waiting"' >/dev/null 2>&1; then
      [ -z "$prompt" ] && return 0
      curl -s --unix-socket "$SOCK" -X POST -d "$prompt" http://localhost/input >/dev/null 2>&1
      return 0
    fi
  else
    [ -S "$SOCK" ] && rm -f "$SOCK" "$PID_FILE" 2>/dev/null
  fi
  if [ -f "$ASK_DIR/pending" ]; then
    [ -z "$prompt" ] && return 0
    echo "$prompt" > "$ASK_DIR/response"
    return 0
  fi
  if [[ "$prompt" == tty:* ]]; then tty_input="${prompt#tty:}"
  elif [[ "$prompt" == res:* ]]; then tty_input="${prompt#res:}"
  else return 0; fi
  [ -z "$tty_input" ] && { echo "Usage: tty:<your input>" >&2; return 2; }
  echo "$tty_input" > "$ASK_DIR/response"
  return 0
}

# 重任務提示；bash 的 regex 只會比 grep 寬（. 可跨行），命中後再用原本的 grep 確認
think_first() {
  [ -z "$prompt" ] && return 0
  local HEAVY='implement|refactor|debug|architect|architecture|migrat|rewrite|overhaul|integrat|build (a|the|out)|實作|實現|重構|重寫|除錯|修.{0,3}bug|設計|架構|遷移|整合|改造|重新設計|全面'
  local TRIVIAL='typo|rename|錯字|拼字|改個|改一下|微調|小修|換行|格式|formatting|lint|註解|comment'
  shopt -s nocasematch
  [[ $prompt =~ $HEAVY ]] || return 0
  shopt -u nocasematch
  printf '%s' "$prompt" | grep -iqE "$HEAVY" || return 0
  if printf '%s' "$prompt" | grep -iqE "$TRIVIAL" && [ "${#prompt}" -lt 80 ]; then return 0; fi
  jq -n --arg c 'Think-first protocol (heavy task detected): INTERNALLY, without narrating any of this in your reply, restate the task as a verifiable success condition and plan goal -> step -> verify, and raise reasoning depth (ultrathink-level) before acting. Keep the visible output concise -- results, decisions, risks, next step; do not recite the plan or your process. For large multi-file / migration / audit scope, recommend /effort xhigh or ultracode to Miyago before starting -- his call, do not switch silently.' \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
}

jev_route() {
  case "${SHOAL_JEV_MODE-}" in active|shadow) ;; *) return 0 ;; esac
  printf '%s' "$input" | python3 "$HOME/dotfile/config/ai/shared/jev/shoal_route.py"
}

(tty_respond) >/dev/null; tty_rc=$?
o_think=$(think_first)
o_jev=$(jev_route)

if [ -n "$o_think" ] && [ -n "$o_jev" ]; then
  jq -n --argjson a "$o_think" --argjson b "$o_jev" \
    '$a | .hookSpecificOutput.additionalContext += "\n\n" + $b.hookSpecificOutput.additionalContext'
elif [ -n "$o_think" ]; then printf '%s\n' "$o_think"
elif [ -n "$o_jev" ]; then printf '%s' "$o_jev"
fi
exit "$tty_rc"
