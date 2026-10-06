#!/usr/bin/env bash
# setup_codex.sh 的 secret guard 註冊邏輯離線測試：只把 begin/end 標記之間的函式抽出來，
# 對暫存目錄裡的 hooks.json 執行。不執行 setup_codex.sh，也不碰 ~/.codex。
# SETUP 可用環境變數覆寫（teeth check 用）。
# shellcheck disable=SC2015,SC2016  # ok/bad 不會失敗，A && ok || bad 是安全的；grep 的 pattern 要字面的 $
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../../../../.." && pwd)"
SETUP=${SETUP:-"$ROOT/script/common/setup_codex.sh"}
GUARD="$ROOT/config/ai/claude/hooks/secret-guard.sh"
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
tmp=$(mktemp -d); trap '/bin/rm -rf "$tmp"' EXIT
fail=0; n=0
ok() { n=$((n + 1)); }
bad() { n=$((n + 1)); echo "FAIL $1"; fail=1; }

snippet=$(awk '/^# --- secret-guard registration: begin ---$/ { on = 1; next } /^# --- secret-guard registration: end ---$/ { on = 0 } on' "$SETUP")
[ -n "$snippet" ] || { echo "FAIL 在 $SETUP 找不到 secret-guard registration 區段"; exit 1; }
eval "$snippet"
declare -F register_secret_guard_hook >/dev/null || { echo "FAIL register_secret_guard_hook 未定義"; exit 1; }

CMD="bash '$GUARD'"

# 1. 既有 hooks.json（仿 live 的形狀：已有 shoal guard 的 PreToolUse）：追加一筆，其他不動
cat > "$tmp/hooks.json" <<'JSON'
{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"/x/experience-observe.py","timeout":5}]}],
"PreToolUse":[{"matcher":"^(apply_patch|spawn_agent)$","hooks":[{"type":"command","command":"python3 shoal_guard.py --host codex","timeout":10}]}]}}
JSON
before=$(jq -S 'del(.hooks.PreToolUse[1])' "$tmp/hooks.json")
register_secret_guard_hook "$tmp/hooks.json" "$GUARD"; rc=$?
[ $rc = 0 ] && ok || bad "register rc=$rc"
want=$(jq -cn --arg c "$CMD" '{matcher:"Bash",hooks:[{type:"command",command:$c,timeout:10}]}')
[ "$(jq -c '.hooks.PreToolUse[-1]' "$tmp/hooks.json")" = "$want" ] && ok || bad "entry shape: $(jq -c '.hooks.PreToolUse' "$tmp/hooks.json")"
[ "$(jq '.hooks.PreToolUse | length' "$tmp/hooks.json")" = 2 ] && ok || bad "PreToolUse length"
[ "$(jq -S 'del(.hooks.PreToolUse[1])' "$tmp/hooks.json")" = "$before" ] && ok || bad "existing entries changed"

# 2. 冪等：再跑一次不重複
register_secret_guard_hook "$tmp/hooks.json" "$GUARD"; rc=$?
{ [ $rc = 0 ] && [ "$(jq '.hooks.PreToolUse | length' "$tmp/hooks.json")" = 2 ]; } && ok || bad "idempotent rc=$rc"

# 3. 沒有 PreToolUse、沒有 hooks 鍵
echo '{"hooks":{"Stop":[]}}' > "$tmp/a.json"
register_secret_guard_hook "$tmp/a.json" "$GUARD"
[ "$(jq -c '.hooks.PreToolUse' "$tmp/a.json")" = "[$want]" ] && ok || bad "no PreToolUse key"
[ "$(jq -c '.hooks.Stop' "$tmp/a.json")" = "[]" ] && ok || bad "Stop key lost"
echo '{}' > "$tmp/b.json"
register_secret_guard_hook "$tmp/b.json" "$GUARD"
[ "$(jq -c '.hooks.PreToolUse' "$tmp/b.json")" = "[$want]" ] && ok || bad "empty object"

# 4. hooks.json 不存在：回 1，不建立檔案
register_secret_guard_hook "$tmp/missing.json" "$GUARD"; rc=$?
{ [ $rc = 1 ] && [ ! -e "$tmp/missing.json" ]; } && ok || bad "missing file rc=$rc"

# 5. JSON 無效：回 3，原檔不動、不留暫存檔
printf 'not json' > "$tmp/bad.json"
register_secret_guard_hook "$tmp/bad.json" "$GUARD" 2>/dev/null; rc=$?
{ [ $rc = 3 ] && [ "$(cat "$tmp/bad.json")" = 'not json' ]; } && ok || bad "invalid json rc=$rc"
[ -z "$(find "$tmp" -name '*.tmp.*')" ] && ok || bad "temp file left behind"

# 6. 缺 jq：回 2，原檔不動（在子 shell 裡把 PATH 指到空目錄）
mkdir -p "$tmp/emptybin"; echo '{}' > "$tmp/c.json"
# shellcheck disable=SC2123  # 故意在子 shell 把 PATH 換掉，模擬缺 jq
( PATH="$tmp/emptybin"; register_secret_guard_hook "$tmp/c.json" "$GUARD" ); rc=$?
{ [ $rc = 2 ] && [ "$(cat "$tmp/c.json")" = '{}' ]; } && ok || bad "no jq rc=$rc"

# 7. 註冊的指令真的能跑：以 Codex 的 PreToolUse 輸入餵進去，命中回 Codex 認得的 deny，放行時無輸出
cmd=$(jq -r '.hooks.PreToolUse[-1].hooks[0].command' "$tmp/hooks.json")
codex_in() { jq -cn --arg c "$1" '{session_id:"s",turn_id:"t",cwd:"/tmp/work",hook_event_name:"PreToolUse",tool_name:"Bash",tool_use_id:"u",tool_input:{command:$c}}'; }
out=$(codex_in 'gcloud auth print-access-token' | bash -c "$cmd" 2>/dev/null); rc=$?
{ [ $rc = 0 ] && [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput | select(.hookEventName == "PreToolUse") | .permissionDecision' 2>/dev/null)" = deny ]; } && ok || bad "registered command deny rc=$rc out=$out"
printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null | grep -q '^secret-guard: ' && ok || bad "registered command reason"
out=$(codex_in 'ls -la' | bash -c "$cmd" 2>/dev/null); rc=$?
{ [ $rc = 0 ] && [ -z "$out" ]; } && ok || bad "registered command allow rc=$rc out=$out"

# 8. setup_codex.sh 真的會呼叫它，且沒有動到不該動的設定
grep -q '^ensure_secret_guard_hook$' "$SETUP" && ok || bad "ensure_secret_guard_hook 沒有被呼叫"
grep -q 'register_secret_guard_hook "\$CODEX_DST/hooks.json" "\$SECRET_GUARD_SRC"' "$SETUP" && ok || bad "註冊目標不是 CODEX_DST/hooks.json"

# --- teeth check：註冊函式被換成什麼都不做時，這份測試必須失敗 ---
if [ -z "${TEETH_INNER:-}" ]; then
  n=$((n + 1))
  awk '/^# --- secret-guard registration: begin ---$/ { print; print "register_secret_guard_hook() { return 0; }"; skip = 1; next }
       /^# --- secret-guard registration: end ---$/ { skip = 0 } !skip' "$SETUP" > "$tmp/setup_noop.sh"
  inner=$(TEETH_INNER=1 SETUP="$tmp/setup_noop.sh" bash "$0" 2>&1); irc=$?
  { [ $irc != 0 ] && printf '%s' "$inner" | grep -q 'FAIL entry shape'; } || { echo "FAIL teeth_check rc=$irc"; fail=1; }
fi

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
