#!/usr/bin/env bash
# script/git-hooks/pre-commit 的回歸測試。在暫存 git repo 內操作，測試指令以
# DOTFILE_HOOK_CLAUDE_CMD / DOTFILE_HOOK_SECRET_CMD 換成 stub（只寫 marker 檔），
# 不會跑真正耗時的整套測試。HOOK 可用環境變數覆寫（teeth check：換成永遠 exit 0
# 的空殼時本測試必須失敗）。
# shellcheck disable=SC2016,SC2034  # 條件字串交給 eval 展開；rc 由 eval 內的條件讀取
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/pre-commit"}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
R="$T/repo"; MARK="$T/marks"
fail=0; n=0

git init -q "$R"
git -C "$R" config user.email t@example.invalid
git -C "$R" config user.name t
: > "$MARK"

# stub：記下被呼叫，依 FAKE_RC 決定成敗
cat > "$T/stub" <<'EOF2'
#!/bin/bash
echo "$1" >> "$MARKS"
exit "${FAKE_RC:-0}"
EOF2
chmod +x "$T/stub"
export MARKS="$MARK"
export DOTFILE_HOOK_CLAUDE_CMD="$T/stub claude"
export DOTFILE_HOOK_SECRET_CMD="$T/stub secret"
unset DOTFILE_SKIP_TESTS

check() {
  local name=$1 c; shift; n=$((n + 1))
  for c in "$@"; do
    eval "$c" || { echo "FAIL $name: $c"; fail=1; return; }
  done
}
# stage <path> [內容]：寫檔並 git add
stage() { mkdir -p "$R/$(dirname "$1")"; printf '%s\n' "${2:-x$RANDOM}" > "$R/$1"; git -C "$R" add "$1"; }
# run_hook：在暫存 repo 內執行 hook；重置 marker 並清掉已 stage 的檔案
run_hook() { : > "$MARK"; (cd "$R" && bash "$HOOK") > "$T/out" 2> "$T/err"; rc=$?; }
reset() { git -C "$R" rm -rq --cached . 2> /dev/null; /bin/rm -rf "${R:?}"/*; }

# 1. 無關 commit 放行且不跑測試
stage README.md; run_hook
check unrelated_passes '[ $rc = 0 ]' "[ ! -s '$MARK' ]"
reset

# 2. 相關路徑觸發對應測試
stage config/ai/claude/hooks/foo.sh; run_hook
check claude_hooks_trigger '[ $rc = 0 ]' "[ \"\$(cat '$MARK')\" = claude ]"
reset
stage config/ai/shared/jev/x.py; run_hook
check jev_triggers_claude '[ $rc = 0 ]' "[ \"\$(cat '$MARK')\" = claude ]"
reset
stage script/utils/agent-secret2; run_hook
check agent_secret_trigger '[ $rc = 0 ]' "[ \"\$(cat '$MARK')\" = secret ]"
reset
stage script/utils/tests/test_agent_secret.sh; run_hook
check utils_tests_trigger '[ $rc = 0 ]' "[ \"\$(cat '$MARK')\" = secret ]"
reset
stage config/ai/claude/hooks/a.sh; stage script/utils/agent-secret; run_hook
check both_suites '[ $rc = 0 ]' "[ \"\$(sort '$MARK' | tr '\n' ' ')\" = 'claude secret ' ]"
reset

# 3. 測試失敗會擋，並印出哪一支與手動重跑方式
stage config/ai/claude/hooks/foo.sh; FAKE_RC=1 run_hook
check failure_blocks '[ $rc = 1 ]' "grep -q 'FAIL claude hooks' '$T/err'" \
  "grep -q '手動重跑' '$T/err'" "grep -q 'run-all.sh\|stub' '$T/err'"
reset
stage script/utils/agent-secret; FAKE_RC=1 run_hook
check secret_failure_blocks '[ $rc = 1 ]' "grep -q 'FAIL agent-secret' '$T/err'"
reset

# 4. 逃生門：放行、不跑測試、印一行提醒
stage config/ai/claude/hooks/foo.sh
: > "$MARK"; (cd "$R" && FAKE_RC=1 DOTFILE_SKIP_TESTS=1 bash "$HOOK") > "$T/out" 2> "$T/err"; rc=$?
check skip_env '[ $rc = 0 ]' "[ ! -s '$MARK' ]" "[ \"\$(wc -l < '$T/err' | tr -d ' ')\" = 1 ]" \
  "grep -q DOTFILE_SKIP_TESTS '$T/err'"
reset

# 5. settings.json：壞掉擋、合法放行（不呼叫任何測試）
stage config/ai/claude/settings.json '{ not json'; run_hook
check bad_json_blocks '[ $rc = 1 ]' "grep -q 'settings.json' '$T/err'" "[ ! -s '$MARK' ]"
reset
stage config/ai/claude/settings.json '{"a": 1}'; run_hook
check good_json_passes '[ $rc = 0 ]' "[ ! -s '$MARK' ]"
reset

# 6. 缺 jq 時放行並提示（PATH 只含 git 與基本工具，不含 jq）
mkdir -p "$T/nojq"
for b in git bash cat sed tail head tr sort wc dirname mkdir; do
  p=$(command -v "$b") && ln -sf "$p" "$T/nojq/$b"
done
stage config/ai/claude/settings.json '{ not json'
: > "$MARK"; (cd "$R" && PATH="$T/nojq" /bin/bash "$HOOK") > "$T/out" 2> "$T/err"; rc=$?
check missing_jq_allows '[ $rc = 0 ]' "grep -q '缺 jq' '$T/err'"
reset

# 7. 整合：真的用 core.hooksPath 讓 git commit 呼叫 hook
git -C "$R" config core.hooksPath "$(dirname "$HOOK")"
stage README.md; : > "$MARK"
git -C "$R" commit -qm unrelated > "$T/out" 2> "$T/err"; rc=$?
check commit_unrelated '[ $rc = 0 ]' "[ ! -s '$MARK' ]"
stage config/ai/claude/hooks/foo.sh; : > "$MARK"
git -C "$R" commit -qm relevant > "$T/out" 2> "$T/err"; rc=$?
check commit_runs_hook '[ $rc = 0 ]' "[ \"\$(cat '$MARK')\" = claude ]"
stage config/ai/claude/hooks/bar.sh; : > "$MARK"
FAKE_RC=1 git -C "$R" commit -qm blocked > "$T/out" 2> "$T/err"; rc=$?
check commit_blocked '[ $rc != 0 ]' "[ \"\$(git -C '$R' log --oneline | wc -l | tr -d ' ')\" = 2 ]"
: > "$MARK"
FAKE_RC=1 DOTFILE_SKIP_TESTS=1 git -C "$R" commit -qm skipped > "$T/out" 2> "$T/err"; rc=$?
check commit_skip '[ $rc = 0 ]' "[ \"\$(git -C '$R' log --oneline | wc -l | tr -d ' ')\" = 3 ]"

[ $fail = 0 ] && echo "all $n checks passed"
exit $fail
