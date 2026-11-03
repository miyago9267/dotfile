#!/usr/bin/env bash
# prompt-submit.sh 的 session_sync 與 session-claim.sh 測試：記憶同步、claim 注入、過期清理、post 追加、end 清理。
# HOME 全指到 mktemp 目錄，不碰真實 ~/.cache 與記憶目錄。
set -u
D=$(cd "$(dirname "$0")/.." && pwd)
PS="$D/prompt-submit.sh"; SC="$D/session-claim.sh"
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; unset SHOAL_JEV_MODE
S="$HOME/.cache/agent-sessions"; C="$S/claims"
SHARED="$HOME/.claude/memories"; PROJ="$T/proj/memory"
mkdir -p "$SHARED" "$PROJ" "$T/repo/.git"
fail=0
ok() { [ "$2" = 1 ] || { echo "FAIL $1"; fail=1; }; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
prompt() { # sid text [cwd]
  jq -n --arg s "$1" --arg p "$2" --arg c "${3:-$T/repo}" --arg t "$T/proj/x.jsonl" \
    '{session_id:$s,prompt:$p,cwd:$c,transcript_path:$t}' | bash "$PS" 2>/dev/null
}
has() { printf '%s' "$2" | grep -qF -- "$3"; }

# 1. 首個 prompt：建立 stamp、不注入
out=$(prompt A "hello"); ok first_no_inject "$([ -z "$out" ] && echo 1)"
ok stamp_created "$([ -f "$S/A.memstamp" ] && echo 1)"
ok claim_created "$([ -f "$C/A.json" ] && echo 1)"

# 2. 無變更：無輸出
out=$(prompt A "again"); ok nochange_silent "$([ -z "$out" ] && echo 1)"

# 3. 檔案變更：注入路徑與內容，之後不重複
touch -t 202001010000 "$S/A.memstamp"
echo "fact-one" >"$PROJ/a.md"; echo "ignore" >"$PROJ/b.txt"
out=$(prompt A "x" | ctx)
has "" "$out" "其他 session 更新了記憶：" && has "" "$out" "$PROJ/a.md" && has "" "$out" "fact-one" && ok changed_inject 1 || ok changed_inject 0
has "" "$out" "b.txt" && ok non_md_ignored 0
out=$(prompt A "x"); ok no_repeat "$([ -z "$out" ] && echo 1)"

# 3b. 共用記憶目錄（symlink 解析）
mkdir -p "$T/real"; rm -rf "$SHARED"; ln -s "$T/real" "$SHARED"
touch -t 202001010000 "$S/A.memstamp"; echo "shared-note" >"$T/real/s.md"
out=$(prompt A "x" | ctx); has "" "$out" "shared-note" && ok shared_symlink 1 || ok shared_symlink 0

# 4. cap：大檔只列路徑；合計超過 3KB 後只列路徑
touch -t 202001010000 "$S/A.memstamp"
head -c 2000 /dev/zero | tr '\0' 'b' >"$PROJ/big.md"
for i in 1 2 3; do head -c 1400 /dev/zero | tr '\0' "$i" >"$PROJ/m$i.md"; done
out=$(prompt A "x" | ctx)
has "" "$out" "$PROJ/big.md" && ok cap_lists_big 1 || ok cap_lists_big 0
has "" "$out" "bbbbbbbb" && ok cap_big_no_content 0
n=$(printf '%s' "$out" | grep -c '^[123]\{100\}'); ok cap_total "$([ "$n" = 2 ] && echo 1)"
has "" "$out" "Read" && ok cap_read_hint 1 || ok cap_read_hint 0

# 5. 其他 session claim 注入（同 git root）
printf '%s' "{\"session_id\":\"B\",\"cwd\":\"$T/repo/sub\",\"git_root\":\"$T/repo\",\"updated\":$(date +%s),\"prompt\":\"fixing login\",\"files\":[\"$T/repo/a.ts\"]}" >"$C/B.json"
out=$(prompt A "x" | ctx)
has "" "$out" "其他 session 正在進行：fixing login" && has "" "$out" "$T/repo/a.ts" && has "" "$out" "先問 Miyago" && ok claim_inject 1 || ok claim_inject 0
# 不相干（不同 cwd、無重疊）不注入
printf '%s' "{\"session_id\":\"E\",\"cwd\":\"$T/other\",\"git_root\":\"$T/other\",\"updated\":$(date +%s),\"prompt\":\"unrelated\",\"files\":[]}" >"$C/E.json"
out=$(prompt A "x" | ctx); has "" "$out" "unrelated" && ok unrelated_skipped 0
# 檔案重疊（不同 cwd）注入
echo "{\"session_id\":\"A\",\"tool_input\":{\"file_path\":\"/x/shared.ts\"}}" | bash "$SC" post
printf '%s' "{\"session_id\":\"F\",\"cwd\":\"$T/far\",\"git_root\":\"\",\"updated\":$(date +%s),\"prompt\":\"overlap-one\",\"files\":[\"/x/shared.ts\"]}" >"$C/F.json"
out=$(prompt A "x" | ctx); has "" "$out" "overlap-one" && ok overlap_inject 1 || ok overlap_inject 0
# 超過 60 分鐘但未滿 6h：不注入也不刪
printf '%s' "{\"session_id\":\"G\",\"cwd\":\"$T/repo\",\"git_root\":\"$T/repo\",\"updated\":$(( $(date +%s) - 7200 )),\"prompt\":\"old-two-hours\",\"files\":[]}" >"$C/G.json"
out=$(prompt A "x" | ctx); has "" "$out" "old-two-hours" && ok idle_not_injected 0
ok idle_kept "$([ -f "$C/G.json" ] && echo 1)"

# 6. 過期 claim 清理（>6h）
printf '%s' "{\"session_id\":\"H\",\"cwd\":\"$T/repo\",\"updated\":1,\"prompt\":\"ancient\",\"files\":[]}" >"$C/H.json"
touch -t 202001010000 "$C/H.json"
prompt A "x" >/dev/null; ok stale_deleted "$([ ! -e "$C/H.json" ] && echo 1)"

# 7. PostToolUse 追加：去重、上限 50、NotebookEdit 用 notebook_path
rm -f "$C/A.json"
for i in 1 2; do echo '{"session_id":"P","cwd":"/c","tool_input":{"file_path":"/f/one.ts"}}' | bash "$SC" post; done
echo '{"session_id":"P","tool_input":{"notebook_path":"/f/nb.ipynb"}}' | bash "$SC" post
ok post_dedup "$([ "$(jq -c .files "$C/P.json")" = '["/f/one.ts","/f/nb.ipynb"]' ] && echo 1)"
for i in $(seq 1 60); do echo "{\"session_id\":\"P\",\"tool_input\":{\"file_path\":\"/f/n$i.ts\"}}" | bash "$SC" post; done
ok post_cap "$([ "$(jq '.files|length' "$C/P.json")" = 50 ] && [ "$(jq -r '.files[-1]' "$C/P.json")" = /f/n60.ts ] && echo 1)"
# prompt 更新 claim 時保留 files
prompt P "keep files" >/dev/null; ok prompt_keeps_files "$([ "$(jq '.files|length' "$C/P.json")" = 50 ] && echo 1)"

# 8. PreToolUse 警告：目標在其他活躍 claim -> additionalContext，不含 permissionDecision
out=$(echo '{"session_id":"Z","tool_input":{"file_path":"/x/shared.ts"}}' | bash "$SC" pre)
has "" "$out" "overlap-one" && ok pre_warn 1 || ok pre_warn 0
ok pre_no_decision "$([ -z "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty')" ] && [ "$(printf '%s' "$out" | jq -r .hookSpecificOutput.hookEventName)" = PreToolUse ] && echo 1)"
out=$(echo '{"session_id":"Z","tool_input":{"file_path":"/x/none.ts"}}' | bash "$SC" pre); ok pre_silent "$([ -z "$out" ] && echo 1)"
out=$(echo '{"session_id":"F","tool_input":{"file_path":"/x/shared.ts"}}' | bash "$SC" pre); ok pre_skip_own "$([ -z "$out" ] && echo 1)"

# 9. SessionEnd：刪 claim 與 memstamp
touch "$S/P.memstamp"
echo '{"session_id":"P"}' | bash "$SC" end; rc=$?
ok end_rc "$([ $rc = 0 ] && echo 1)"
ok end_cleanup "$([ ! -e "$C/P.json" ] && [ ! -e "$S/P.memstamp" ] && echo 1)"

# 10. 壞輸入不失敗
echo 'not json' | bash "$SC" post; ok bad_input_rc "$([ $? = 0 ] && echo 1)"
printf 'plain text' | bash "$PS" >/dev/null 2>&1; ok plain_prompt_rc "$([ $? = 0 ] && echo 1)"

# 11. 工作宣告只在渲染內容改變時注入（時間戳變動不算）
rm -f "$C"/*.json "$S"/*.selfmem "$S"/*.lastclaims
printf '%s' "{\"session_id\":\"X\",\"cwd\":\"$T/repo\",\"git_root\":\"$T/repo\",\"updated\":$(date +%s),\"prompt\":\"claim-x\",\"files\":[]}" >"$C/X.json"
out=$(prompt N "n1" | ctx); has "" "$out" "claim-x" && ok claim_first_inject 1 || ok claim_first_inject 0
out=$(prompt N "n2" | ctx); ok same_block_silent "$([ -z "$out" ] && echo 1)"
printf '%s' "{\"session_id\":\"X\",\"cwd\":\"$T/repo\",\"git_root\":\"$T/repo\",\"updated\":$(( $(date +%s) - 60 )),\"prompt\":\"claim-x\",\"files\":[]}" >"$C/X.json"
out=$(prompt N "n3" | ctx); ok new_timestamp_silent "$([ -z "$out" ] && echo 1)"
printf '%s' "{\"session_id\":\"X\",\"cwd\":\"$T/repo\",\"git_root\":\"$T/repo\",\"updated\":$(date +%s),\"prompt\":\"claim-y\",\"files\":[]}" >"$C/X.json"
out=$(prompt N "n4" | ctx); has "" "$out" "claim-y" && ok changed_block_inject 1 || ok changed_block_inject 0
out=$(prompt N "n5" | ctx); ok changed_block_once "$([ -z "$out" ] && echo 1)"
rm -f "$C/X.json"; prompt N "n6" >/dev/null; ok block_gone_clears_record "$([ ! -e "$S/N.lastclaims" ] && echo 1)"
printf '%s' "{\"session_id\":\"X\",\"cwd\":\"$T/repo\",\"git_root\":\"$T/repo\",\"updated\":$(date +%s),\"prompt\":\"claim-y\",\"files\":[]}" >"$C/X.json"
out=$(prompt N "n7" | ctx); has "" "$out" "claim-y" && ok reappear_inject 1 || ok reappear_inject 0

# 12. 自己寫入的記憶不回報給自己；之後別人再改同一檔要回報
rm -f "$C/X.json"
prompt M "m1" >/dev/null
echo "self-note" >"$PROJ/self.md"; touch -t 202406010000 "$PROJ/self.md"
echo "{\"session_id\":\"M\",\"cwd\":\"$T/repo\",\"transcript_path\":\"$T/proj/x.jsonl\",\"tool_input\":{\"file_path\":\"$PROJ/self.md\"}}" | bash "$SC" post
echo "{\"session_id\":\"M\",\"cwd\":\"$T/repo\",\"tool_input\":{\"file_path\":\"$T/repo/notes.md\"}}" | bash "$SC" post
ok non_memory_md_not_recorded "$(grep -qF notes.md "$S/M.selfmem" 2>/dev/null || echo 1)"
touch -t 202001010000 "$S/M.memstamp"
out=$(prompt M "m2" | ctx); ok self_not_injected "$(has "" "$out" "self.md" || echo 1)"
touch -t 202001010000 "$S/M.memstamp"; echo "other-edit" >"$PROJ/self.md"
out=$(prompt M "m3" | ctx); has "" "$out" "self.md" && ok other_write_inject 1 || ok other_write_inject 0
echo '{"session_id":"M"}' | bash "$SC" end
ok end_clears_selfmem "$([ ! -e "$S/M.selfmem" ] && echo 1)"
echo '{"session_id":"N"}' | bash "$SC" end
ok end_clears_lastclaims "$([ ! -e "$S/N.lastclaims" ] && echo 1)"

[ $fail = 0 ] && echo "all passed"; exit $fail
