#!/usr/bin/env bash
# destructive-guard.sh 的回歸測試（characterization）：斷言現行行為，被攔的回 ask，其餘無輸出。
# 危險指令只以 JSON 字串餵給 hook，不會被執行。HOOK 可用環境變數覆寫（teeth check 用）。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/destructive-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
fail=0; n=0
run() { # name expect(ask|none) command [reason 子字串]
  n=$((n + 1))
  out=$(jq -n --arg c "$3" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null); rc=$?
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  text=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
  ok=0
  if [ "$2" = none ]; then [ -z "$out" ] && ok=1; else [ "$dec" = "$2" ] && ok=1; fi
  [ $rc = 0 ] || ok=0
  if [ $ok = 1 ] && [ -n "${4:-}" ] && ! printf '%s' "$text" | grep -qF -- "$4"; then ok=0; fi
  [ $ok = 1 ] || { echo "FAIL $1 expect=$2 rc=$rc dec=$dec out=$out"; fail=1; }
}

# --- rm -rf：目標全在 temp 才放行 ---
run rm_outside_temp ask 'rm -rf /Users/x/proj/build' 'temp 目錄'
run rm_home_tilde ask 'rm -rf ~/proj' 'temp 目錄'
run rm_relative ask 'rm -rf ./dist' 'temp 目錄'
run rm_fr_order ask 'rm -fr ./dist' 'temp 目錄'
run rm_split_flags ask 'rm -r -f ./dist' 'temp 目錄'
run rm_split_flags_rev ask 'rm -f -r ./dist' 'temp 目錄'
run rm_mixed_targets ask 'rm -rf /tmp/a /Users/x/b' '/Users/x/b'
run rm_chained_second_bad ask 'rm -rf /tmp/a && rm -rf ./b' 'temp 目錄'
run rm_after_cd ask 'cd /tmp && rm -rf ./x' 'temp 目錄'
run rm_tmp_dir_itself ask 'rm -rf /tmp' 'temp 目錄'
run rm_in_tmp none 'rm -rf /tmp/foo'
run rm_in_private_tmp none 'rm -rf /private/tmp/foo/bar'
run rm_in_var_folders none 'rm -rf /var/folders/ab/cd/T/x'
run rm_in_tmpdir_var none 'rm -rf $TMPDIR/x'
run rm_in_tmp_quoted none 'rm -rf "/tmp/x"'
run rm_all_targets_in_tmp none 'rm -rf /tmp/a /tmp/b'
# GAP: /tmp/ 前綴比對不正規化路徑，/tmp/../ 可以逃出 temp 仍被放行
run rm_tmp_dotdot_escape none 'rm -rf /tmp/../etc/x'
run rm_recursive_only none 'rm -r ./dist'
run rm_force_only none 'rm -f ./x.log'
run rm_plain none 'rm notes.txt'
run rm_in_word none 'echo harm -rf ./x'

# --- git reset --hard ---
run reset_hard ask 'git reset --hard HEAD~1' 'reset --hard'
run reset_hard_bare ask 'git reset --hard' 'reset --hard'
run reset_hard_dash_C ask 'git -C /repo reset --hard' 'reset --hard'
run reset_hard_dash_c ask 'git -c core.x=y reset --hard origin/main' 'reset --hard'
run reset_hard_git_dir ask 'git --git-dir=/r/.git reset --hard' 'reset --hard'
run reset_hard_no_pager ask 'git --no-pager reset --hard' 'reset --hard'
run reset_hard_after_semicolon ask 'cd r; git reset --hard' 'reset --hard'
run reset_soft none 'git reset --soft HEAD~1'
run reset_mixed none 'git reset HEAD file.txt'
run reset_in_word none 'echo git resets --hard'

# --- git clean -f ---
run clean_fd ask 'git clean -fd' 'clean -f'
run clean_fdx ask 'git -C r clean -fdx' 'clean -f'
run clean_dry_run none 'git clean -n'
run clean_dry_run_dir none 'git clean -nd'
# GAP: 長選項 --force 沒被 -[a-zA-Z]*f 比對到，git clean --force 直接放行
run clean_long_force none 'git clean --force -d'

# --- git push force ---
run push_force ask 'git push --force origin main' '改寫遠端歷史'
run push_force_end ask 'git push origin main --force' '改寫遠端歷史'
run push_force_eq ask 'git push --force=yes origin main' '改寫遠端歷史'
run push_force_lease ask 'git push --force-with-lease origin main' '改寫遠端歷史'
run push_short_f ask 'git push -f origin main' '改寫遠端歷史'
run push_short_f_end ask 'git push origin main -f' '改寫遠端歷史'
run push_plus_refspec ask 'git push origin +main' '改寫遠端歷史'
run push_plus_refspec_pair ask 'git push origin +HEAD:main' '改寫遠端歷史'
run push_force_dash_C ask 'git -C r push -f' '改寫遠端歷史'
run push_plain none 'git push origin main'
run push_upstream none 'git push -u origin main'
run push_colon_refspec_inline none 'git push origin HEAD:main'
run push_branch_with_f_prefix none 'git push origin -fix'
run push_branch_name_force none 'git push origin fix-force-x'
run push_plus_not_refspec none 'git push origin a+b'
run push_tags none 'git push --tags'

# --- git push delete ---
run push_delete ask 'git push origin --delete feature' '刪除遠端'
run push_delete_short ask 'git push -d origin feature' '刪除遠端'
run push_colon_delete ask 'git push origin :feature' '刪除遠端'
run push_delete_tag ask 'git push origin :refs/tags/v1' '刪除遠端'
run push_delete_dash_C ask 'git -C r push origin --delete feature' '刪除遠端'
run branch_delete_local none 'git branch -d feature'
run push_refspec_pair none 'git push origin feature:feature'

# --- DROP / TRUNCATE（不分大小寫）---
run drop_table_upper ask 'psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_table_lower ask 'mysql -e "drop table users"' 'DROP / TRUNCATE'
run drop_database_mixed ask 'psql -c "Drop Database app"' 'DROP / TRUNCATE'
run drop_schema ask 'psql -c "DROP SCHEMA public CASCADE"' 'DROP / TRUNCATE'
run drop_table_spaces ask 'psql -c "DROP   TABLE x"' 'DROP / TRUNCATE'
run truncate_table_upper ask 'psql -c "TRUNCATE TABLE logs"' 'DROP / TRUNCATE'
run truncate_table_lower ask 'psql -c "truncate table logs"' 'DROP / TRUNCATE'
run drop_in_prose none 'echo dropping the tables'
run select_only none 'psql -c "SELECT * FROM users"'
# GAP: TRUNCATE 沒帶 TABLE 關鍵字（PostgreSQL 合法）不會被攔
run truncate_without_table none 'psql -c "TRUNCATE logs"'
# GAP: DROP INDEX / VIEW 不在規則內
run drop_index none 'psql -c "DROP INDEX idx_users"'
# GAP: 比對沒有 anchor，commit message 裡的 "drop table" 字樣也會誤攔
run drop_table_in_commit_msg ask 'git commit -m "docs: drop table section"' 'DROP / TRUNCATE'

# --- sudo ---
run sudo_plain ask 'sudo ls' 'sudo'
run sudo_after_semicolon ask 'echo hi; sudo ls' 'sudo'
run sudo_after_and ask 'true && sudo ls' 'sudo'
run sudo_bare ask 'sudo' 'sudo'
run sudo_with_tmp_rm ask 'sudo rm -rf /tmp/x' 'sudo'
run pseudo_word none 'pseudo-tool --help'
run sudoers_word none 'cat /etc/sudoers'
run visudo_word none 'visudo -c'

# --- 一般指令與空輸入 ---
run ls_plain none 'ls -la'
run git_status none 'git status'
run empty_command none ''
for raw in '{"tool_input":{}}' 'not json'; do # stdin 不是預期格式：無輸出、exit 0
  n=$((n + 1))
  out=$(printf '%s' "$raw" | bash "$HOOK" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL raw_input '$raw' rc=$rc out=$out"; fail=1; }
done

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
