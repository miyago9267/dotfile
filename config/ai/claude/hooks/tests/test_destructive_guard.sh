#!/usr/bin/env bash
# destructive-guard.sh 的回歸測試：SQL 的 DROP TABLE/DATABASE/SCHEMA 與 TRUNCATE 回 deny（硬閘門），
# 其餘被攔的規則回 ask，沒被攔的無輸出。已知還存在的漏洞以 GAP 標註。
# 危險指令只以 JSON 字串餵給 hook，不會被執行。HOOK 可用環境變數覆寫（teeth check 用）。
# shellcheck disable=SC2016  # 測試指令是刻意不展開的字面字串
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/destructive-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
fail=0; n=0
run() { # name expect(ask|deny|none) command [reason 子字串]
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

# --- rm -rf：目標在 temp 或專案內相對路徑才放行 ---
run rm_outside_temp ask 'rm -rf /Users/x/proj/build' 'temp 目錄'
run rm_home_tilde ask 'rm -rf ~/proj' 'temp 目錄'
run rm_relative none 'rm -rf ./dist'
run rm_fr_order none 'rm -fr ./dist'
run rm_split_flags none 'rm -r -f ./dist'
run rm_split_flags_rev none 'rm -f -r ./dist'
run rm_relative_plain none 'rm -rf node_modules dist'
run rm_relative_dotdot ask 'rm -rf ../other' 'temp 目錄'
run rm_relative_nested_dotdot ask 'rm -rf a/../../b' 'temp 目錄'
run rm_cwd_itself ask 'rm -rf .' 'temp 目錄'
run rm_glob_all ask 'rm -rf *' 'temp 目錄'
run rm_dot_git ask 'rm -rf .git' 'temp 目錄'
run rm_env_var ask 'rm -rf $HOME/x' 'temp 目錄'
run rm_relative_after_cd_home ask 'cd ~ && rm -rf Documents' 'temp 目錄'
run rm_mixed_targets ask 'rm -rf /tmp/a /Users/x/b' '/Users/x/b'
run rm_chained_second_relative none 'rm -rf /tmp/a && rm -rf ./b'
run rm_chained_second_bad ask 'rm -rf /tmp/a && rm -rf ~/b' 'temp 目錄'
run rm_after_cd ask 'cd /tmp && rm -rf ./x' 'temp 目錄'
run rm_tmp_dir_itself ask 'rm -rf /tmp' 'temp 目錄'
run rm_in_tmp none 'rm -rf /tmp/foo'
run rm_in_private_tmp none 'rm -rf /private/tmp/foo/bar'
run rm_in_var_folders none 'rm -rf /var/folders/ab/cd/T/x'
run rm_in_tmpdir_var none 'rm -rf $TMPDIR/x'
run rm_in_tmp_quoted none 'rm -rf "/tmp/x"'
run rm_all_targets_in_tmp none 'rm -rf /tmp/a /tmp/b'
run rm_tmp_dotdot_escape ask 'rm -rf /tmp/../etc/x' 'temp 目錄'
run rm_recursive_only none 'rm -r ./dist'
run rm_force_only none 'rm -f ./x.log'
run rm_plain none 'rm notes.txt'
run rm_in_word none 'echo harm -rf ./x'

# --- git reset --hard ---
run reset_hard none 'git reset --hard HEAD~1'
run reset_hard_bare none 'git reset --hard'
run reset_hard_dash_C none 'git -C /repo reset --hard'
run reset_hard_dash_c none 'git -c core.x=y reset --hard origin/main'
run reset_hard_git_dir none 'git --git-dir=/r/.git reset --hard'
run reset_hard_no_pager none 'git --no-pager reset --hard'
run reset_hard_after_semicolon none 'cd r; git reset --hard'
run reset_soft none 'git reset --soft HEAD~1'
run reset_mixed none 'git reset HEAD file.txt'
run reset_in_word none 'echo git resets --hard'

# --- git clean -f ---
run clean_fd none 'git clean -fd'
run clean_fdx none 'git -C r clean -fdx'
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

# --- DROP TABLE/DATABASE/SCHEMA、TRUNCATE：deny（不分大小寫）---
run drop_table_upper deny 'psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_table_lower deny 'mysql -e "drop table users"' 'DROP / TRUNCATE'
run drop_database_mixed deny 'psql -c "Drop Database app"' 'DROP / TRUNCATE'
run drop_schema deny 'psql -c "DROP SCHEMA public CASCADE"' 'DROP / TRUNCATE'
run drop_table_spaces deny 'psql -c "DROP   TABLE x"' 'DROP / TRUNCATE'
run drop_table_if_exists deny 'psql -c "DROP TABLE IF EXISTS users"' 'DROP / TRUNCATE'
run truncate_table_upper deny 'psql -c "TRUNCATE TABLE logs"' 'DROP / TRUNCATE'
run truncate_table_lower deny 'psql -c "truncate table logs"' 'DROP / TRUNCATE'
run truncate_without_table deny 'psql -c "TRUNCATE logs"' 'DROP / TRUNCATE'
run truncate_only deny 'psql -c "truncate only logs"' 'DROP / TRUNCATE'
run truncate_bare_mysql deny "mysql -uroot -e 'truncate t;'" 'DROP / TRUNCATE'
run truncate_bare_no_semicolon deny "psql -c 'truncate users'" 'DROP / TRUNCATE'
run deny_reason_who deny 'psql -c "DROP TABLE users"' 'Miyago'
run deny_reason_where deny 'psql -c "DROP TABLE users"' 'terminal'
# 各種會真的執行到 SQL 的寫法
run drop_echo_piped_to_client deny 'echo "DROP TABLE users" | psql app' 'DROP / TRUNCATE'
run drop_unquoted_echo_piped deny 'echo DROP TABLE users | psql app' 'DROP / TRUNCATE'
run drop_heredoc_to_client deny $'psql app <<EOF\nDROP TABLE users;\nEOF' 'DROP / TRUNCATE'
run drop_heredoc_cat_piped deny $'cat <<EOF | psql app\nDROP TABLE users;\nEOF' 'DROP / TRUNCATE'
run truncate_heredoc_to_client deny $'psql app <<SQL\nTRUNCATE logs;\nSQL' 'DROP / TRUNCATE'
run drop_here_string deny 'psql app <<< "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_shell_dash_c deny 'bash -c "psql -c \"DROP TABLE users\""' 'DROP / TRUNCATE'
run drop_via_kubectl_exec deny 'kubectl exec db-0 -- psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_after_commit deny 'git commit -m "wip" && psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_after_semicolon deny 'cd r; psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_in_cmd_subst_of_echo deny 'echo "$(psql -c "DROP TABLE users")"' 'DROP / TRUNCATE'
run drop_in_backticks deny 'echo `psql -c "DROP TABLE users"`' 'DROP / TRUNCATE'
run drop_in_cmd_subst_arg deny 'psql -c "$(echo DROP TABLE users)"' 'DROP / TRUNCATE'
run drop_python_inline deny 'python3 -c "cur.execute(\"DROP TABLE users\")"' 'DROP / TRUNCATE'
# 資料庫 client：出現在指令的任何位置都算
run drop_sqlite deny 'sqlite3 app.db "DROP TABLE t"' 'DROP / TRUNCATE'
run drop_mariadb deny 'mariadb -e "drop table t"' 'DROP / TRUNCATE'
run drop_duckdb deny 'duckdb a.db "DROP TABLE t"' 'DROP / TRUNCATE'
run drop_cockroach deny 'cockroach sql -e "DROP DATABASE app"' 'DROP / TRUNCATE'
run drop_clickhouse deny 'clickhouse-client -q "DROP TABLE t"' 'DROP / TRUNCATE'
run drop_sqlcmd deny 'sqlcmd -Q "DROP TABLE t"' 'DROP / TRUNCATE'
run drop_pgcli deny 'pgcli -c "drop schema s"' 'DROP / TRUNCATE'
run drop_bq deny 'bq query "DROP TABLE ds.t"' 'DROP / TRUNCATE'
run drop_docker_exec_client deny 'docker exec db psql -U u -c "DROP DATABASE app"' 'DROP / TRUNCATE'
run drop_sudo_user_client deny 'sudo -u postgres psql -c "DROP DATABASE app"' 'DROP / TRUNCATE'
run drop_client_full_path deny '/opt/homebrew/bin/psql -c "DROP TABLE t"' 'DROP / TRUNCATE'
run drop_ssh_client deny "ssh db-host 'psql -c \"DROP TABLE t\"'" 'DROP / TRUNCATE'
run drop_multi_statement deny 'psql -c "select 1; drop table t"' 'DROP / TRUNCATE'
run drop_tab_between deny $'psql -c "DROP\tTABLE t"' 'DROP / TRUNCATE'
run drop_newline_between deny $'psql -c "DROP\nTABLE t"' 'DROP / TRUNCATE'
run drop_comment_between deny 'psql -c "DROP /* x */ TABLE t"' 'DROP / TRUNCATE'
run drop_quoted_ident deny "psql -c 'drop  table if exists \"T\"'" 'DROP / TRUNCATE'
run truncate_printf_piped deny "printf '%s' 'truncate table t' | mysql db" 'DROP / TRUNCATE'
run truncate_backtick_ident deny 'mysql -e "TRUNCATE `logs`"' 'DROP / TRUNCATE'
# 會執行字串的 shell：-c 的內容、pipe 或 heredoc 餵進去的內容都當成指令再判斷
run drop_sh_c_single deny "sh -c 'psql -c \"drop table t\"'" 'DROP / TRUNCATE'
run drop_eval_string deny "eval \"psql -c 'DROP TABLE t'\"" 'DROP / TRUNCATE'
run drop_eval_words deny 'eval psql -c "DROP TABLE t"' 'DROP / TRUNCATE'
run drop_echo_piped_to_shell deny "echo \"psql -c 'DROP TABLE t'\" | bash" 'DROP / TRUNCATE'
run drop_heredoc_to_shell deny $'bash <<EOF\npsql -c "DROP TABLE t"\nEOF' 'DROP / TRUNCATE'
run drop_here_string_to_shell deny "bash <<< \"psql -c 'DROP TABLE t'\"" 'DROP / TRUNCATE'
run drop_git_alias_bang deny "git -c alias.z='!psql -c \"drop table t\"' z" 'DROP / TRUNCATE'
run drop_ansi_c_quote deny "echo \$'it\\'s' ; psql -c 'DROP TABLE t' ; echo 'done'" 'DROP / TRUNCATE'
# 直譯器以 -c / -e / stdin 執行字串：刻意 deny（寫檔用的字串也一樣，直譯器確實可能執行它）
run drop_node_e deny "node -e \"require('fs').writeFileSync('a.sql', 'DROP TABLE IF EXISTS t;')\"" 'DROP / TRUNCATE'
run drop_bun_e deny "bun -e \"await Bun.write('a.sql', 'TRUNCATE TABLE t;')\"" 'DROP / TRUNCATE'
run drop_python_stdin_heredoc deny $'python3 - <<\'PY\'\nPath("f.sql").write_text("DROP TABLE IF EXISTS t;")\nPY' 'DROP / TRUNCATE'
run drop_python_heredoc_no_dash deny $'python3 <<PY\ncur.execute("drop table t")\nPY' 'DROP / TRUNCATE'
run drop_ruby_e deny "ruby -e 'db.execute(\"DROP TABLE t\")'" 'DROP / TRUNCATE'
# deny 優先於其他規則的 ask
run drop_beats_sudo deny 'sudo psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
run drop_beats_rm deny 'rm -rf ./dist && psql -c "DROP TABLE users"' 'DROP / TRUNCATE'
# 不誤擋：字樣只出現在不會執行的地方
run drop_table_in_commit_msg none 'git commit -m "docs: drop table section"'
run drop_table_in_commit_msg_semicolon none 'git commit -m "docs: drop table; truncate table notes"'
run drop_table_in_commit_heredoc none $'git commit -m "$(cat <<\'EOF\'\ndocs: explain DROP TABLE and TRUNCATE logs;\n\ndon\'t (ever) drop schema by hand\nEOF\n)"'
run drop_table_in_echo none 'echo "DROP TABLE users"'
run drop_table_in_echo_single none "echo 'drop table users; truncate table logs'"
run drop_table_in_printf none 'printf "%s\n" "DROP DATABASE app"'
run drop_table_in_echo_redirect none 'echo "DROP TABLE users;" > /tmp/x.sql'
run drop_table_in_grep none 'grep -ri "drop table" migrations/'
run drop_table_in_rg none 'rg -n "TRUNCATE TABLE" src'
run drop_table_in_cat_heredoc none $'cat > /tmp/m.sql <<EOF\nDROP TABLE users;\nEOF'
run drop_table_in_gh_body none 'gh pr create --title "x" --body "this migration will drop table users"'
run drop_table_in_comment none $'ls # then DROP TABLE users\nls'
run drop_in_prose none 'echo dropping the tables'
# 唯讀指令搜尋或提到字樣（含接了 head / wc / sort / xargs grep 的 pipeline）：不擋
run ro_rg_head none 'rg -n "drop table" src/ | head -20'
run ro_grep_wc none 'grep -rn "DROP TABLE" migrations/ | wc -l'
run ro_grep_sort none 'grep -rli "truncate table" . | sort'
run ro_cd_rg none 'cd ~/proj && rg -i "drop table" migrations'
run ro_git_log_head none 'git log --oneline --grep="drop table" | head -5'
run ro_find_xargs_grep none "find . -name '*.sql' | xargs grep -l \"DROP TABLE\""
run ro_xargs_flags_grep none 'ls migrations | xargs -n1 -I{} grep -c "DROP TABLE" {}'
run ro_awk none "awk '/DROP TABLE/{print FILENAME}' migrations/*.sql"
run ro_sed_print none "sed -n '/DROP TABLE/p' schema.sql"
run ro_sed_in_place none "sed -i '' 's/DROP TABLE IF EXISTS foo;//' migrations/001.sql"
run ro_jq none "jq -r '.[] | select(.sql | test(\"DROP TABLE\"))' log.json"
run ro_cat_grep none 'cat schema.sql | grep -c "DROP TABLE"'
run ro_ls_file none 'ls -la "docs/drop table notes.md"'
run ro_mv_file none 'mv "docs/drop table notes.md" docs/ddl.md'
run ro_head_file none 'head -20 "docs/drop table notes.md"'
run ro_git_add_file none 'git add "docs/drop table notes.md"'
run ro_echo_append none 'echo "DROP TABLE IF EXISTS t;" >> migrations/down.sql'
run ro_rg_bare_truncate_head none 'rg "truncate users" src/sql | head'
run ro_script_then_grep none 'bash tests/run.sh; grep -c "DROP TABLE" out.log'
run ro_write_test_then_run none $'cat > tests/test_guard.sh <<\'T\'\nrun deny \'psql -c "DROP TABLE x"\'\nT\nbash tests/test_guard.sh'
run ro_sql_piped_to_shell_is_not_sql ask 'echo "DROP TABLE t" | bash' 'DROP / TRUNCATE'
# 不確定會不會執行（測試 runner、自訂 script、xargs 接其他指令）：維持改版前的 ask，不 deny
run unsure_bun_test_name ask 'bun test -t "rejects drop table statements"' 'DROP / TRUNCATE'
run unsure_pytest_k ask 'pytest -k "drop table"' 'DROP / TRUNCATE'
run unsure_pytest_k_underscore none 'pytest -k "test_drop_table"'
run unsure_custom_script ask 'bun run q.ts "DROP TABLE logs"' 'DROP / TRUNCATE'
run unsure_python_module ask 'python3 -m pytest -k "drop table"' 'DROP / TRUNCATE'
run unsure_shell_c_grep ask "bash -c 'grep \"drop table\" f.sql'" 'DROP / TRUNCATE'
run unsure_find_exec ask "find . -name '*.sql' -exec grep -l 'DROP TABLE' {} +" 'DROP / TRUNCATE'
run unsure_drop_tables_plural ask 'bun test -t "drop tables"' 'DROP / TRUNCATE'
run unsure_backdrop_word ask 'bun run build --name "backdrop table"' 'DROP / TRUNCATE'
# 字樣不在 client 的 pipeline 裡，但同一條指令另有 client：ask
run unsure_echo_file_then_client ask 'echo "DROP TABLE t" > /tmp/x.sql && psql -f /tmp/x.sql' 'DROP / TRUNCATE'
run unsure_client_then_echo ask 'psql -c "select 1" && echo "DROP TABLE x"' 'DROP / TRUNCATE'
# 不帶 TABLE 的 TRUNCATE 沒有資料庫 client 時不擋（改版前也不擋）
run truncate_bare_script none 'bun run q.ts "TRUNCATE logs;"'
run truncate_bare_js_comment none "node -e \"console.log('abc'.slice(0,2)) // truncate users list\""
run truncate_coreutils_sqlish_path none 'truncate -s 0 logs/mysql.log'
run psql_select_dropped_columns none 'psql -c "SELECT dropped, truncated FROM t"'
run docker_compose_down none 'docker compose down -v'
run prisma_migrate none 'npx prisma migrate dev --name init'
run select_only none 'psql -c "SELECT * FROM users"'
run truncate_coreutils none 'truncate -s 0 app.log'
run truncate_coreutils_chained none 'cd logs && truncate -s 0 app.log'
run truncate_flag none 'bq head --truncate 5 ds.t'
run truncate_prose_no_sql_context none 'bun test -t "truncate long names"'
run truncate_function_call none 'psql -c "SELECT truncate_name(x) FROM t"'
# DROP INDEX / VIEW：不刪資料、可由定義重建，只 ask 不 deny
run drop_index ask 'psql -c "DROP INDEX idx_users"' 'DROP INDEX / VIEW'
run drop_view ask 'psql -c "drop view v_users"' 'DROP INDEX / VIEW'
run drop_materialized_view ask 'psql -c "DROP MATERIALIZED VIEW mv_users"' 'DROP INDEX / VIEW'
run drop_index_in_commit_msg none 'git commit -m "perf: drop index idx_users"'
# GAP: SQL 寫在檔案裡再餵給 client，hook 看不到內容
run drop_in_sql_file none 'psql -f migrations/drop_users.sql'
# GAP: 不帶 TABLE 的 TRUNCATE 只在有資料庫 client 時才攔，直譯器或自訂 script 內的不攔
run truncate_bare_no_sql_context none 'node -e "db.exec(\"TRUNCATE logs\")"'
# GAP: ORM / migration 工具的破壞性子指令沒有 SQL 字樣，hook 看不到
run orm_drop_not_covered none 'bunx drizzle-kit drop'
# 超過 64KB 的指令不做完整解析：字面命中就 ask（不放行、不 deny），而且要很快結束
big=$(printf 'ls -la /tmp/aaaa && %.0s' $(seq 1 4000))
run big_command_sql ask "${big}psql -c 'DROP TABLE t'" 'DROP / TRUNCATE'
run big_command_plain none "${big}ls"
start=$(date +%s)
run big_command_300kb ask "$big$big$big${big}psql -c 'DROP TABLE t'" 'DROP / TRUNCATE'
n=$((n + 1)); [ $(($(date +%s) - start)) -le 2 ] || { echo "FAIL big_command_300kb 太慢"; fail=1; }
# GAP: 其他會永久刪資料的 SQL（DROP COLUMN、沒有 WHERE 的 DELETE）不在規則內
run alter_drop_column none 'psql -c "ALTER TABLE users DROP COLUMN email"'
run delete_without_where none 'psql -c "DELETE FROM users"'

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
