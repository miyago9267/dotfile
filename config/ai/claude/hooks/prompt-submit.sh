#!/usr/bin/env bash
# UserPromptSubmit dispatcher：一個 bash process 取代 tty-respond / think-first-router / jev-route。
# stdin 只解析一次。輸出合併成一份 JSON（additionalContext 以空行串接）。
# tty-respond 原本回顯的 JSON（原 payload 或 "[input received]" 改寫）不含 Claude 認得的欄位，已省略；
# 它的副作用（寫 socket / response 檔）與 exit 2（tty: 後面沒有內容）照舊。
# SHOAL_JEV_MODE 沒設成 active|shadow 時不啟動 python。
# 多 session 協作（session_sync）：
#  1. 記憶同步：~/.cache/agent-sessions/<sid>.memstamp 為基準，find -newer 找其他 session 改過的記憶 .md
#     （共用 ~/.claude/memories 與本專案 auto-memory）。首個 prompt 只建 stamp、不注入；注入內文 <=1.5KB/檔、合計 <=3KB。
#     <sid>.selfmem 記錄自己寫入的記憶「路徑 mtime」，mtime 未變的檔案不回報給自己。
#  2. 工作宣告：~/.cache/agent-sessions/claims/<sid>.json 每個 prompt 更新；6h 以上的刪除；
#     60 分鐘內且 cwd/git root 相同或檔案重疊的其他 claim 會注入。檔案清單由 session-claim.sh post 追加。
#     渲染後的文字與 <sid>.lastclaims 相同時不重複注入。
# 任何內部錯誤都不影響 prompt（session_sync 失敗只是沒輸出）。
set -u
command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
if parsed=$(printf '%s' "$input" | jq -r '@sh "prompt=\(.prompt // "") cwd=\(.cwd // "") sid=\(.session_id // "") tp=\(.transcript_path // "")"' 2>/dev/null); then
  eval "$parsed"; is_json=1
else
  prompt=$input; cwd=""; sid=""; tp=""; is_json=0
fi
prompt=${prompt-}; cwd=${cwd-}; sid=${sid-}; tp=${tp-}
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

session_sync() {
  [ "$is_json" = 1 ] && [[ $sid =~ ^[A-Za-z0-9_-]+$ ]] || return 0
  local C="$HOME/.cache/agent-sessions/claims" stamp="$HOME/.cache/agent-sessions/$sid.memstamp"
  local own="$HOME/.cache/agent-sessions/claims/$sid.json" out="" mem="" claims="" omitted=0
  local selfmem="$HOME/.cache/agent-sessions/$sid.selfmem" lastc="$HOME/.cache/agent-sessions/$sid.lastclaims"
  local dirs=() d pm f sz total=0 changed root="" now snippet others=0 src
  mkdir -p "$C" 2>/dev/null || return 0

  if [ -f "$stamp" ]; then
    d=$(cd -P "$HOME/.claude/memories" 2>/dev/null && pwd -P) && dirs+=("$d")
    if [ -n "$tp" ]; then pm="${tp%/*}/memory"; else pm="$HOME/.claude/projects/${cwd//\//-}/memory"; fi
    d=$(cd -P "$pm" 2>/dev/null && pwd -P) && dirs+=("$d")
    if [ ${#dirs[@]} -gt 0 ]; then
      changed=$(find -L "${dirs[@]}" -type f -name '*.md' -newer "$stamp" 2>/dev/null)
      if [ -n "$changed" ] && [ -f "$selfmem" ]; then
        changed=$(while IFS= read -r f; do
          mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
          grep -qxF -- "$f $mt" "$selfmem" 2>/dev/null || printf '%s\n' "$f"
        done <<<"$changed")
      fi
      if [ -n "$changed" ]; then
        mem="其他 session 更新了記憶："
        while IFS= read -r f; do
          sz=$(wc -c <"$f" 2>/dev/null); sz=${sz//[[:space:]]/}
          if [ "${sz:-99999}" -le 1536 ] && [ $((total + sz)) -le 3072 ]; then
            total=$((total + sz)); mem+=$'\n'"- $f"$'\n'"$(<"$f")"
          else
            omitted=1; mem+=$'\n'"- $f"
          fi
        done <<<"$changed"
        [ $omitted = 1 ] && mem+=$'\n'"（上列只有路徑的檔案內容未附，請用 Read 讀取）"
      fi
    fi
  fi
  touch "$stamp" 2>/dev/null

  find "$C" -name '*.json' -mmin +360 -delete 2>/dev/null
  d=$cwd
  while [ -n "$d" ] && [ "$d" != / ]; do [ -e "$d/.git" ] && { root=$d; break; }; d=${d%/*}; done
  now=$(date +%s); snippet=${prompt:0:100}; snippet=${snippet//$'\n'/ }
  [ -f "$own" ] && src=$own || src=/dev/null
  jq -nc --arg sid "$sid" --arg cwd "$cwd" --arg root "$root" --argjson now "$now" --arg p "$snippet" \
    'try input catch {} | {session_id:$sid,cwd:$cwd,git_root:$root,updated:$now,prompt:$p,files:(.files // [])}' "$src" \
    >"$own.$$" 2>/dev/null && mv -f "$own.$$" "$own" 2>/dev/null
  for f in "$C"/*.json; do [ -e "$f" ] && [ "$f" != "$own" ] && { others=1; break; }; done
  if [ $others = 1 ] && [ -f "$own" ]; then
    claims=$(jq -rn --arg sid "$sid" --arg cwd "$cwd" --arg root "$root" --argjson now "$now" '
      [inputs] as $all
      | ([$all[] | select(.session_id == $sid) | .files[]?]) as $mine
      | $all[] | select(.session_id != $sid and ($now - (.updated // 0)) <= 3600
          and (.cwd == $cwd or ($root != "" and .git_root == $root) or any(.files[]?; . as $x | $mine | index($x))))
      | "其他 session 正在進行：\(.prompt)（\(.cwd)），動過：\((.files // [])[:10] | if length == 0 then "（尚無）" else join("、") end)。要改到同一批檔案前先問 Miyago。"' \
      "$C"/*.json 2>/dev/null)
  fi
  if [ -n "$claims" ]; then
    if [ -f "$lastc" ] && [ "$(<"$lastc")" = "$claims" ]; then claims=""; else printf '%s' "$claims" >"$lastc" 2>/dev/null; fi
  else
    [ -f "$lastc" ] && rm -f "$lastc"
  fi
  out=$mem
  [ -n "$claims" ] && out=${out:+$out$'\n\n'}$claims
  printf '%s' "$out"
}

(tty_respond) >/dev/null; tty_rc=$?
o_think=$(think_first)
o_jev=$(jev_route)
o_sync=$(session_sync 2>/dev/null)

if [ -n "$o_sync" ]; then
  jq -n --arg t "$o_think" --arg j "$o_jev" --arg s "$o_sync" '
    [ ($t | select(. != "") | fromjson | .hookSpecificOutput.additionalContext // empty),
      ($j | select(. != "") | fromjson | .hookSpecificOutput.additionalContext // empty), $s ]
    | join("\n\n") | {hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
elif [ -n "$o_think" ] && [ -n "$o_jev" ]; then
  jq -n --argjson a "$o_think" --argjson b "$o_jev" \
    '$a | .hookSpecificOutput.additionalContext += "\n\n" + $b.hookSpecificOutput.additionalContext'
elif [ -n "$o_think" ]; then printf '%s\n' "$o_think"
elif [ -n "$o_jev" ]; then printf '%s' "$o_jev"
fi
exit "$tty_rc"
