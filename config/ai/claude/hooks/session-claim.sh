#!/usr/bin/env bash
# 多 session 工作宣告 hook，用法：session-claim.sh post|pre|end（stdin 為 hook JSON）。
#  post（PostToolUse Edit|Write|MultiEdit|NotebookEdit）：把被改的檔案追加到自己的 claim（去重、上限 50）；
#       改的是記憶目錄下的 .md 時，另記「路徑 mtime」到 <sid>.selfmem，讓 session_sync 不回報給自己。
#  pre（PreToolUse Edit|Write|MultiEdit）：目標檔案在其他 60 分鐘內活躍的 claim 時，用 additionalContext 提醒（不 deny、不 ask）。
#  end（SessionEnd）：刪除自己的 claim、memstamp、selfmem 與 lastclaims。
# claim 由 prompt-submit.sh 每個 prompt 建立/更新：~/.cache/agent-sessions/claims/<sid>.json。任何錯誤一律 exit 0。
set -u
command -v jq >/dev/null 2>&1 || exit 0
mode=${1-}
S="$HOME/.cache/agent-sessions"; C="$S/claims"
memdirs() {
  local d pm
  d=$(cd -P "$HOME/.claude/memories" 2>/dev/null && pwd -P) && echo "$d"
  if [ -n "$tp" ]; then pm="${tp%/*}/memory"; else pm="$HOME/.claude/projects/${cwd//\//-}/memory"; fi
  d=$(cd -P "$pm" 2>/dev/null && pwd -P) && echo "$d"
}
parsed=$(jq -r '@sh "sid=\(.session_id // "") cwd=\(.cwd // "") tp=\(.transcript_path // "") fp=\(.tool_input.file_path // .tool_input.notebook_path // "")"' 2>/dev/null) || exit 0
eval "$parsed"
[[ ${sid-} =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
own="$C/$sid.json"

case "$mode" in
  end) rm -f "$own" "$S/$sid.memstamp" "$S/$sid.selfmem" "$S/$sid.lastclaims" ;;
  post)
    [ -n "$fp" ] || exit 0
    mkdir -p "$C" 2>/dev/null || exit 0
    [ -f "$own" ] && src=$own || src=/dev/null
    jq -nc --arg sid "$sid" --arg cwd "$cwd" --arg f "$fp" --argjson now "$(date +%s)" '
      (try input catch {}) as $c
      | {session_id:$sid,cwd:($c.cwd // $cwd),git_root:($c.git_root // ""),updated:$now,prompt:($c.prompt // "")}
        + {files:((($c.files // []) | map(select(. != $f))) + [$f] | .[-50:])}' "$src" \
      >"$own.$$" 2>/dev/null && mv -f "$own.$$" "$own" 2>/dev/null
    case "$fp" in
      *.md)
        dir=$(cd -P "$(dirname "$fp")" 2>/dev/null && pwd -P) || exit 0
        rp="$dir/${fp##*/}"
        while IFS= read -r md; do
          if [ -n "$md" ] && [[ $rp == "$md"/* ]]; then
            mt=$(stat -c %Y "$rp" 2>/dev/null || stat -f %m "$rp" 2>/dev/null) || exit 0
            sm="$S/$sid.selfmem"
            { [ -f "$sm" ] && awk -v p="$rp " 'index($0, p) != 1' "$sm"; printf '%s %s\n' "$rp" "$mt"; } >"$sm.$$" 2>/dev/null && mv -f "$sm.$$" "$sm" 2>/dev/null
            break
          fi
        done <<<"$(memdirs)"
        ;;
    esac
    ;;
  pre)
    [ -n "$fp" ] || exit 0
    for f in "$C"/*.json; do [ -e "$f" ] && [ "$f" != "$own" ] && { found=1; break; }; done
    [ "${found-}" = 1 ] || exit 0
    msg=$(jq -rn --arg sid "$sid" --arg f "$fp" --argjson now "$(date +%s)" '
      [inputs | select(.session_id != $sid and ($now - (.updated // 0)) <= 3600 and (.files // [] | index($f)))]
      | first // empty | "注意：\($f) 已被另一個 session 動過（\(.prompt)，\(.cwd)）。要改之前先問 Miyago。"' \
      "$C"/*.json 2>/dev/null)
    [ -n "$msg" ] && jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
    ;;
esac
exit 0
