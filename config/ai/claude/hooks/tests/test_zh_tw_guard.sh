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
run subagent_simplified block '{"hook_event_name":"SubagentStop","last_assistant_message":"这个问题已经处理完了，我们现在进行下一步。","stop_hook_active":false}'
run subagent_english pass '{"hook_event_name":"SubagentStop","last_assistant_message":"All done. The fetch returned the page content without any issues here.","stop_hook_active":false}'
tr=$(mktemp)
printf '%s\n' '{"type":"user","message":{"role":"user","content":"hi"}}' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"这个问题已经处理完了，我们现在进行下一步。"}]}}' > "$tr"
run subagent_transcript block "{\"hook_event_name\":\"SubagentStop\",\"agent_transcript_path\":\"$tr\",\"stop_hook_active\":false}"
rm -f "$tr"

# 逐段檢查：message 以 jq-free 的 python 產生，避免跳脫問題
msg() { python3 -c 'import json,sys;print(json.dumps({"last_assistant_message":sys.argv[1],"stop_hook_active":False},ensure_ascii=False))' "$1"; }
run en_para_between_zh block "$(msg $'先處理第一步，已經完成。\n\nExport header wasn\'t matched by my sed and the fix is now applied to every file.\n\n接著處理第二步。')"
run ja_sentence block "$(msg '了解しました。では次に設定を確認します。')"
run zh_with_identifiers pass "$(msg $'這段說明提到 fooBar、baz_qux、src/app/main.ts 還有 zh-tw-guard.py，另外 getUserById 與 config.json 也有改。')"
run path_list pass "$(msg $'- config/ai/claude/hooks/zh-tw-guard.py\n- config/ai/claude/hooks/tests/test_zh_tw_guard.sh\n- a1b2c3d4e5f6\n- 9f8e7d6c5b4a')"
run en_table pass "$(msg $'結果如下：\n\n| name | value | description of the field | another column here |\n| --- | --- | --- | --- |\n| alpha | beta | gamma delta epsilon | zeta eta theta iota |\n\n完成。')"
run single_no pass "$(msg '這個助詞「の」表示所有，例如 A の B。')"
run kana_quoted pass "$(msg $'日文的「了解しました」是禮貌說法。\n\n行內寫法 `では次に設定を確認します` 也一樣。\n\n```\nでは次に設定を確認します。了解しました。\n```\n\n結束。')"
run furigana pass "$(msg $'値段（ねだん）は安いです。\n\n高い（たかい）と安い（やすい）を覚えましょう。')"
run mixed_zh_ja pass "$(msg $'**判斷線索**：に行く 前面固定用地點，而且助詞は、を、が 要分清楚，不會跟 から 混用。')"
run subagent_en_para pass '{"hook_event_name":"SubagentStop","last_assistant_message":"中文開頭。\n\nExport header wasn'"'"'t matched by my sed and the fix is now applied to every file.","stop_hook_active":false}'
run subagent_ja pass "$(python3 -c 'import json;print(json.dumps({"hook_event_name":"SubagentStop","last_assistant_message":"了解しました。では次に設定を確認します。","stop_hook_active":False},ensure_ascii=False))')"
run md_sources_list pass "$(msg $'這次查到的結論是新版本已經修正這個問題，影響範圍只限於舊設定。\n\nSources:\n- [Kubernetes Release Notes for Version One Point Two Three](https://example.com/a)\n- [Migration Guide Overview and Steps Here](https://example.com/b)\n- [Known Issues Tracker Summary Page](https://example.com/c)')"
run md_link_in_en block "$(msg $'The fix landed in the release, see [the upstream changelog entry for details](https://example.com/x) and then we verified every file.')"

# PostToolUse：假 transcript
pt=$(mktemp)
python3 - "$pt" <<'EOF'
import json, sys
def rec(blocks, mid="m1"):
    return json.dumps({"type": "assistant", "message": {"id": mid, "role": "assistant", "content": blocks}})
en = "Export header wasn't matched by my sed and the fix is now applied to every file."
lines = [
    '{"type":"user","message":{"role":"user","content":"hi"}}',
    rec([{"type": "text", "text": en}]),
    rec([{"type": "tool_use", "id": "toolu_A", "name": "Bash", "input": {}}]),
    rec([{"type": "tool_use", "id": "toolu_B", "name": "Bash", "input": {}}]),
]
open(sys.argv[1], "w").write("\n".join(lines) + "\n")
EOF
runpt() { # name expect(remind|quiet) json
  out=$(printf '%s' "$3" | python3 "$HOOK")
  if [ "$2" = remind ]; then echo "$out" | grep -q '"hookEventName": "PostToolUse"' && echo "$out" | grep -q additionalContext || { echo "FAIL $1: $out"; fail=1; }
  else [ -z "$out" ] || { echo "FAIL $1: $out"; fail=1; }; fi
}
runpt post_first remind "{\"hook_event_name\":\"PostToolUse\",\"transcript_path\":\"$pt\",\"tool_use_id\":\"toolu_A\"}"
runpt post_second quiet "{\"hook_event_name\":\"PostToolUse\",\"transcript_path\":\"$pt\",\"tool_use_id\":\"toolu_B\"}"
runpt post_no_id quiet "{\"hook_event_name\":\"PostToolUse\",\"transcript_path\":\"$pt\"}"
runpt post_unknown_id quiet "{\"hook_event_name\":\"PostToolUse\",\"transcript_path\":\"$pt\",\"tool_use_id\":\"toolu_Z\"}"
runpt post_bad_json quiet 'not json'
rm -f "$pt"
[ $fail = 0 ] && echo "all passed"; exit $fail
