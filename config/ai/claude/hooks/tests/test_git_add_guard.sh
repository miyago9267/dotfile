#!/usr/bin/env bash
# git-add-guard.sh 的回歸測試（characterization）：git add . / -A 回 deny，其餘無輸出。
# 指令只以 JSON 字串餵給 hook，不會被執行。HOOK 可用環境變數覆寫（teeth check 用）。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/git-add-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
fail=0; n=0
run() { # name expect(deny|none) command
  n=$((n + 1))
  out=$(jq -n --arg c "$3" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null); rc=$?
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  text=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
  ok=0
  if [ "$2" = none ]; then [ -z "$out" ] && ok=1; else [ "$dec" = "$2" ] && printf '%s' "$text" | grep -q 'git add guard' && ok=1; fi
  [ $rc = 0 ] || ok=0
  [ $ok = 1 ] || { echo "FAIL $1 expect=$2 rc=$rc dec=$dec out=$out"; fail=1; }
}

# --- 被攔 ---
run add_dot deny 'git add .'
run add_all_flag deny 'git add -A'
run add_dash_dash_dot deny 'git add -- .'
run add_dash_dash_all deny 'git add -- -A'
run add_dot_extra_spaces deny 'git   add   .'
run add_after_and deny 'cd repo && git add .'
run add_after_semicolon deny 'git status; git add -A'
run add_then_commit deny 'git add . && git commit -m "x"'
run add_piped deny 'echo x | git add -A'
run add_dot_semicolon deny 'git add .;'
# GAP: `.` 後面只認空白 ; & | 結尾，括號 / 引號收尾的寫法放行
run add_subshell none '(git add .)'
run add_dot_quoted none 'git add "."'
# GAP: 比對不分語境，echo 裡沒加引號的 git add . 也會被攔（誤攔）
run add_dot_inside_echo deny 'echo never run git add .'

# --- 放行：明確路徑 ---
run add_file none 'git add README.md'
run add_two_paths none 'git add src/a.ts tests/a.test.ts'
run add_dir none 'git add src/'
run add_dot_slash_path none 'git add ./src'
run add_dash_dash_file none 'git add -- README.md'
run add_patch none 'git add -p'

# --- near-miss：長得像但不是 `.` / `-A` ---
run add_dotfile none 'git add .gitignore'
run add_dot_env_example none 'git add .env.example'
run add_dot_dir none 'git add .github/workflows/ci.yml'
run add_flag_with_suffix none 'git add -Av'
run add_lowercase_a none 'git add -a'
run commit_all_flag none 'git commit -am "x"'
run status_dot none 'git status .'
run diff_dot none 'git diff .'
run other_add_dot none 'npm add .'
run mention_in_path none 'cat docs/git-add.md'

# GAP: 其他等價寫法放行（--all、路徑後再接 .、前面有 -C、-u .）
run add_long_all none 'git add --all'
run add_file_then_dot none 'git add a.txt .'
run add_dash_C none 'git -C repo add .'
run add_force_dot none 'git add -f .'
run add_update_dot none 'git add -u .'

# --- 空輸入 ---
run empty_command none ''
for raw in '{"tool_input":{}}' 'not json'; do # stdin 不是預期格式：無輸出、exit 0
  n=$((n + 1))
  out=$(printf '%s' "$raw" | bash "$HOOK" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL raw_input '$raw' rc=$rc out=$out"; fail=1; }
done

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
