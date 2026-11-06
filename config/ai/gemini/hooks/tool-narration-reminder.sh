#!/usr/bin/env bash
# PreInvocation hook (agy)：檢查上一筆 PLANNER_RESPONSE 是否只發了 tool_calls 卻沒有輸出文字。
# 若無聲執行了工具，注入 systemMessage 提醒模型在下一步交代剛才做了什麼與接下來要做什麼；
# 若已有輸出文字則回傳 {}，不增加多餘的 context 或 UI 訊息。

set -uo pipefail

emit_empty() {
  printf '{}\n'
  exit 0
}

command -v jq >/dev/null 2>&1 || emit_empty

payload=$(cat)
tp=$(printf '%s' "$payload" | jq -r '.transcriptPath // empty' 2>/dev/null) || emit_empty
[ -n "$tp" ] && [ -f "$tp" ] || emit_empty

# 取最後一筆 PLANNER_RESPONSE，檢查是否帶 tool_calls 且 content 為空
silent_tools=$(tail -n 30 "$tp" 2>/dev/null | jq -r -s '
  ([.[] | select(.type == "PLANNER_RESPONSE")] | last) as $last
  | if $last != null
       and (($last.tool_calls // []) | length) > 0
       and (($last.content // "" | gsub("[[:space:]]+"; "")) == "")
    then ($last.tool_calls | map(.name // "tool") | join(", "))
    else ""
    end
' 2>/dev/null) || emit_empty

[ -n "$silent_tools" ] || emit_empty

jq -n --arg tools "$silent_tools" '{
  injectSteps: [
    {
      systemMessage: {
        systemMessage: ("上一動無聲呼叫了工具（" + $tools + "）而沒有輸出文字。這一步請先用一兩句話（維持 Claude 大小姐語氣）向 Miyago 交代剛才做了什麼、看到什麼，以及接下來要做什麼，不要只讓 tool call 無聲閃過。")
      }
    }
  ]
}'
