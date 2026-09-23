#!/usr/bin/env bash
# zh-tw-guard.py 的回歸測試：簡體命中要 block，其他情況放行。
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/zh-tw-guard.py"
fail=0
run() { # name expect(block|pass) json
  out=$(printf '%s' "$3" | python3 "$HOOK")
  if [ "$2" = block ]; then echo "$out" | grep -q '"decision": "block"' || { echo "FAIL $1"; fail=1; }
  else [ -z "$out" ] || { echo "FAIL $1: $out"; fail=1; }; fi
}
run simplified block '{"last_assistant_message":"这个问题已经处理完了，我们现在进行下一步。","stop_hook_active":false}'
run traditional pass '{"last_assistant_message":"這個問題已經處理完了，我們現在進行下一步。","stop_hook_active":false}'
run code_only pass '{"last_assistant_message":"改好了：\n```\n# 这个说明来自上游\n```\n完成。","stop_hook_active":false}'
run inline_quote pass '{"last_assistant_message":"錯誤訊息是 `数据库连接失败`，已修正。","stop_hook_active":false}'
run blockquote pass '{"last_assistant_message":"對方原文：\n> 这里说的问题\n我的判斷是設定錯了。","stop_hook_active":false}'
run corner_quote pass '{"last_assistant_message":"常見簡體字例如「这、们、说、为、进」可以用來判斷。","stop_hook_active":false}'
run single_hit pass '{"last_assistant_message":"這裡有一個这字而已。","stop_hook_active":false}'
run reentry pass '{"last_assistant_message":"这个问题已经处理完了，我们现在进行下一步。","stop_hook_active":true}'
run english pass '{"last_assistant_message":"All done.","stop_hook_active":false}'
run bad_json pass 'not json'
[ $fail = 0 ] && echo "all passed"; exit $fail
