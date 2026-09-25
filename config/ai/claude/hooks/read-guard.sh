#!/bin/bash
# PreToolUse(Read)：大檔案沒帶 offset/limit 時擋下，要求先定位再讀區段，省 context。
# 不擋 image/PDF/notebook；READ_GUARD_MAX_LINES 可調門檻。
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
has_range=$(printf '%s' "$input" | jq -r '(.tool_input.offset != null) or (.tool_input.limit != null) or (.tool_input.pages != null)')
[ -z "$file" ] || [ ! -f "$file" ] || [ "$has_range" = "true" ] && exit 0

case "${file##*.}" in
  png|jpg|jpeg|gif|webp|bmp|svg|pdf|ipynb) exit 0 ;;
esac

max=${READ_GUARD_MAX_LINES:-400}
lines=$(wc -l <"$file" 2>/dev/null | tr -d ' ')
[ -z "$lines" ] || [ "$lines" -le "$max" ] && exit 0

jq -n --arg r "read-guard: ${file} 有 ${lines} 行（門檻 ${max}）。先用 rg -n 或 grep -n 找到相關行號，再用 offset/limit 只讀那一段；真的需要全文就分段讀。" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
