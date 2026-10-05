#!/usr/bin/env bash
# agent-secret 的回歸測試。每個 case 在 subshell 內 source broker、覆寫 backend function 後執行；
# HOME 指向暫存目錄，不碰真實的 Keychain、sops 檔或 alias 表。值都是明顯的假字串。
# BROKER 可用環境變數覆寫（teeth check 用：換成永遠 exit 0 的空殼時本測試必須失敗）。
# shellcheck disable=SC2329,SC2016  # helper 以 eval 與 "$@" 間接呼叫；單引號內的 $ 是刻意不展開
# shellcheck disable=SC2030,SC2031  # locale 與環境的改動刻意只留在 subshell 內
# shellcheck disable=SC2034,SC2316,SC2059  # AS_VALUE 由 broker 讀取；export -f export 與遮蔽 printf 是刻意重現攻擊手法
set -u
BROKER=${BROKER:-"$(cd "$(dirname "$0")/.." && pwd)/agent-secret"}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
T=$(cd "$T" && pwd -P)
export FAKE_HOME="$T/home" CALLS="$T/calls" OUT="$T/out" ARGV="$T/argv"
KC_VAL='DUMMY-NOT-A-SECRET-KC'
SOPS_VAL='DUMMY-NOT-A-SECRET-SOPS'
PUT_VAL='DUMMY-NOT-A-SECRET-PUT'
PUT_HEX=$(printf '%s' "$PUT_VAL" | od -An -v -tx1 | tr -d ' \n')
TABLE="$FAKE_HOME/.config/agent-secret/aliases.tsv"
fail=0; n=0

mkdir -p "$T/bin" "$FAKE_HOME/.config/agent-secret" "$FAKE_HOME/dotfile/secrets"
chmod 700 "$FAKE_HOME/.config/agent-secret"

# 被注入的指令：把指定環境變數的值寫到 OUT、argv 寫到 ARGV
HELPER="$T/bin/show-tool"
cat > "$HELPER" <<EOF
#!/bin/bash -p
builtin printf '%s' "\${!1:-}" > "$OUT"
builtin printf '%s\n' "\$@" > "$ARGV"
builtin printf '%s\n' "\$PATH" > "$T/childpath"
builtin printf '%s\n' "\${BASH_ENV-unset}" > "$T/childbashenv"
builtin printf '%s|%s|%s|%s\n' "\${LC_ALL-unset}" "\${LANG-unset}" "\${LC_COLLATE-unset}" "\${LC_CTYPE-unset}" > "$T/childlocale"
EOF
chmod 755 "$HELPER"
cp "$HELPER" "$T/bin/other-tool"
ln -s /bin/sh "$T/bin/innocent-name"   # symlink 到 shell：basename 看不出來

write_table() { printf '%s\n' "$@" > "$TABLE"; chmod 600 "$TABLE"; }
default_table() {
  write_table \
    '# comment' \
    '' \
    "tok-sops|sops|MY_TOKEN|$HELPER" \
    "tok-kc|keychain-only|MY_TOKEN|$HELPER" \
    "tok-star|sops|MY_TOKEN|*" \
    "tok-multi|sops|MY_TOKEN|/nonexistent/x,$HELPER" \
    "tok-envlist|sops|MY_TOKEN|/usr/bin/env,$HELPER" \
    "tok-shlist|sops|MY_TOKEN|/bin/sh,$HELPER" \
    "foo-bar|sops|MY_TOKEN|$HELPER" \
    "abc|sops|MY_TOKEN|$HELPER"
}

# 在 subshell 內執行 broker。KC / SP 決定 stub 行為：found|notfound|error|empty
# broker 只接受 privileged shell，所以先 set -p；家目錄以覆寫 as_home 指到暫存目錄（HOME 不再有作用）。
# REAL_BACKEND=1 只 stub 最底層的執行檔；REAL_BACKEND=2 完全不 stub；REAL_BACKEND=3 以檔案模擬 Keychain；
# REAL_HOME=1 不覆寫 as_home。
# stdout 存 $T/stdout、stderr 存 $T/stderr，回傳 exit code。
broker() {
  : > "$CALLS"; rm -f "$OUT" "$ARGV"
  (
    set -p
    # shellcheck disable=SC1090
    source "$BROKER" || exit 97
    [ "${REAL_HOME:-0}" = 1 ] || as_home() { builtin printf '%s' "$FAKE_HOME"; }
    uname() { echo "${UNAME:-Darwin}"; }   # 預設模擬 macOS，測試在 Linux 上也跑同一組 case
    if [ "${REAL_BACKEND:-0}" = 0 ]; then
      backend_keychain() {
        echo "keychain $*" >> "$CALLS"
        case "$1" in
          put) echo "keychain-stdin $(cat)" >> "$T/putlog"; [ "${KC:-found}" = error ] && return 1; return 0 ;;
        esac
        case "${KC:-found}" in
          found) [ "$1" = get ] && AS_VALUE=$KC_VAL; return 0 ;;
          empty) AS_VALUE=""; return 0 ;;
          notfound) return 3 ;;
          *) return 1 ;;
        esac
      }
      backend_sops() {
        echo "sops $*" >> "$CALLS"
        case "${SP:-found}" in
          found) [ "$1" = get ] && AS_VALUE=$SOPS_VAL; return 0 ;;
          empty) AS_VALUE=""; return 0 ;;
          notfound) return 3 ;;
          *) return 1 ;;
        esac
      }
    elif [ "${REAL_BACKEND:-0}" = 1 ]; then
      _security() { echo "security $*" >> "$CALLS"; cat > "$T/security-stdin" 2>/dev/null; [ "${SEC_OUT:-}" ] && printf '%s' "$SEC_OUT"; return "${SEC_RC:-0}"; }
      _sops() { echo "sops-bin $*" >> "$CALLS"; [ "${SOPS_OUT:-}" ] && printf '%s' "$SOPS_OUT"; return "${SOPS_RC:-0}"; }
    fi
    if [ "${REAL_BACKEND:-0}" = 3 ]; then
      _sops() { echo "sops-bin $*" >> "$CALLS"; return 1; }
      _security() {
        echo "security $*" >> "$CALLS"
        local a="" w=0 prev="" x line f
        for x in "$@"; do [ "$prev" = -a ] && a=$x; [ "$x" = -w ] && w=1; prev=$x; done
        case "${1:-}" in
          -i)
            line=$(cat); printf '%s\n' "$line" > "$T/security-stdin"
            a=$(printf '%s\n' "$line" | sed -n 's/.* -a \([^ ]*\) .*/\1/p')
            [ -n "$a" ] || return 1
            printf '%s' "${line##* -X }" > "$T/kcstore/$a"; return 0 ;;
          find-generic-password)
            [ -f "$T/kcstore/$a" ] || return 44
            [ "$w" = 1 ] && xxd -r -p < "$T/kcstore/$a"
            return 0 ;;
          delete-generic-password)
            [ -f "$T/kcstore/$a" ] || return 44
            rm -f "$T/kcstore/$a"; return 0 ;;
          dump-keychain)
            [ "${DUMP_RC:-0}" = 0 ] || return "$DUMP_RC"
            cat "$T/kcdecoys"
            for f in "$T/kcstore"/*; do [ -f "$f" ] && kc_item "${f##*/}" agent-secret genp; done
            return 0 ;;
        esac
        return 1
      }
    fi
    [ "${STAT_UID:-}" ] && as_stat() { echo "$STAT_UID 600"; }
    "$@"
  ) > "$T/stdout" 2> "$T/stderr" < "${STDIN:-/dev/null}"
}

check() { # name condition...
  n=$((n + 1))
  local name=$1; shift
  if ! "$@"; then echo "FAIL $name"; fail=1; fi
}
ok_rc() { [ "$rc" = 0 ]; }
bad_rc() { [ "$rc" != 0 ]; }
out_is() { [ -f "$OUT" ] && [ "$(cat "$OUT")" = "$1" ]; }
not_run() { [ ! -e "$OUT" ]; }
called() { grep -q -- "$1" "$CALLS"; }
not_called() { ! grep -q -- "$1" "$CALLS"; }
stderr_has() { grep -q -- "$1" "$T/stderr"; }
no_dummy() { ! grep -rq 'DUMMY-NOT-A-SECRET' "$@"; }
all() { local c; for c in "$@"; do eval "$c" || return 1; done; }

# 預期成功：exit 0、helper 拿到值
expect_ok() { check "$1" all ok_rc "out_is '$2'"; }
# 預期 fail closed：exit 非 0、helper 沒被執行
expect_deny() { check "$1" all bad_rc not_run; }

default_table

# --- 解析順序 ---
KC=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok keychain_hit "$KC_VAL"
check keychain_hit_no_sops not_called '^sops get'
check keychain_hit_logs_backend stderr_has 'alias=tok-sops backend=keychain'
check keychain_hit_stderr_no_value no_dummy "$T/stderr" "$T/stdout"
check keychain_hit_argv_no_value no_dummy "$ARGV" "$CALLS"

KC=notfound SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok notfound_falls_to_sops "$SOPS_VAL"
check notfound_falls_logs_backend stderr_has 'alias=tok-sops backend=sops'
check notfound_falls_argv_no_value no_dummy "$ARGV" "$CALLS" "$T/stderr"

KC=error SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny keychain_error_no_fallthrough
check keychain_error_no_sops_call not_called '^sops'

KC=notfound SP=notfound broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny sops_missing_key_fails
KC=notfound SP=error broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny sops_decrypt_error_fails

# --- keychain-only ---
KC=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_ok keychain_only_hit "$KC_VAL"
KC=notfound SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny keychain_only_never_sops
check keychain_only_never_sops_call not_called '^sops'
KC=error SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny keychain_only_error
check keychain_only_error_no_sops not_called '^sops'
UNAME=Linux KC=found SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny keychain_only_linux_fail_closed
check keychain_only_linux_no_backend all "not_called '^keychain'" "not_called '^sops'"

# --- A2：Linux 走 sops，不呼叫 Keychain ---
UNAME=Linux KC=found SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok linux_sops_works "$SOPS_VAL"
check linux_no_keychain_call not_called '^keychain'
check linux_logs_backend stderr_has 'backend=sops'
UNAME=Linux SP=found STDIN=/dev/null broker as_main put tok-sops; rc=$?
check linux_put_refused all bad_rc "not_called '^keychain'"

# --- 值為空 ---
KC=empty broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny empty_keychain_value
KC=notfound SP=empty broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny empty_sops_value

# --- 指令檢查 ---
broker as_main run tok-sops -- "$T/bin/other-tool" MY_TOKEN; rc=$?
expect_deny command_mismatch
check command_mismatch_no_backend all "not_called '^keychain'" "not_called '^sops'"
broker as_main run tok-sops -- /bin/ls; rc=$?
expect_deny command_mismatch_ls
broker as_main run tok-multi -- "$HELPER" MY_TOKEN; rc=$?
expect_ok allowlist_second_entry "$KC_VAL"
(cd "$T/bin" && broker as_main run tok-sops -- ./show-tool MY_TOKEN); rc=$?
expect_ok relative_path_resolved "$KC_VAL"
(cd "$T" && broker as_main run tok-sops -- bin/../bin/show-tool MY_TOKEN); rc=$?
expect_ok dotdot_path_normalized "$KC_VAL"
PATH="$T/bin:$PATH" broker as_main run tok-sops -- show-tool MY_TOKEN; rc=$?
expect_ok bare_name_via_path "$KC_VAL"
PATH="$T/bin:$PATH" broker as_main run tok-sops -- other-tool MY_TOKEN; rc=$?
expect_deny bare_name_mismatch
broker as_main run tok-sops -- no-such-command-xyz; rc=$?
expect_deny command_not_found
broker as_main run tok-star -- "$HELPER" MY_TOKEN; rc=$?
expect_ok star_allows_plain_tool "$KC_VAL"
# 2026-10-05 起 * 不再套用內建拒絕清單（與簡易模式一致）：原本的 star_denies_* 改成檔尾的 star_allows_* 與 listed_denies_*
broker as_main run tok-star -- sh -c 'printf %s "$MY_TOKEN"'; rc=$?
check star_allows_sh_c all ok_rc "[ \"\$(cat '$T/stdout')\" = '$KC_VAL' ]"
broker as_main run tok-envlist -- /usr/bin/env; rc=$?
check explicit_allow_of_env_still_denied all bad_rc "no_dummy '$T/stdout'"
broker as_main run tok-envlist -- "$HELPER" MY_TOKEN; rc=$?
expect_ok explicit_list_other_entry_ok "$KC_VAL"

# --- alias 驗證：含 regex 字元、前綴、保留字 ---
for a in 'a.c' '.*' 'abc|x' 'ab[c]' '^abc' 'abc$' 'Abc' '-abc' 'abc def' '' 'tok-sops|sops' 'sops' '../x'; do
  broker as_main run "$a" -- "$HELPER" MY_TOKEN; rc=$?
  check "alias_rejected_[$a]" all bad_rc not_run "not_called '^keychain'" "not_called '^sops'"
done
broker as_main run foo -- "$HELPER" MY_TOKEN; rc=$?
expect_deny alias_prefix_not_matched
broker as_main run ab -- "$HELPER" MY_TOKEN; rc=$?
expect_deny alias_prefix_not_matched_2
broker as_main run unknown-alias -- "$HELPER" MY_TOKEN; rc=$?
expect_deny alias_unknown

# --- 表的內容：重複列、欄位不合法 ---
write_table "dup|sops|MY_TOKEN|$HELPER" "dup|sops|MY_TOKEN|$HELPER"
broker as_main run dup -- "$HELPER" MY_TOKEN; rc=$?
expect_deny duplicate_rows
check duplicate_rows_no_backend not_called '^keychain'
write_table "dup|sops|MY_TOKEN|$HELPER" "other|sops|MY_TOKEN|$HELPER" "dup|keychain-only|OTHER_TOKEN|*"
broker as_main run dup -- "$HELPER" MY_TOKEN; rc=$?
expect_deny duplicate_rows_different_content
for e in my_token 1TOKEN 'MY-TOKEN' 'A=B' PATH HOME SHELL IFS ENV BASH_ENV LD_PRELOAD LD_LIBRARY_PATH \
  DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH NODE_OPTIONS PYTHONPATH GIT_SSH_COMMAND PS4 ''; do
  write_table "bad|sops|$e|$HELPER"
  broker as_main run bad -- "$HELPER" "${e:-MY_TOKEN}"; rc=$?
  check "env_name_rejected_[$e]" all bad_rc not_run "not_called '^keychain'"
done
write_table "bad|vault|MY_TOKEN|$HELPER"
broker as_main run bad -- "$HELPER" MY_TOKEN; rc=$?
expect_deny invalid_tier
write_table "bad|sops|MY_TOKEN"
broker as_main run bad -- "$HELPER" MY_TOKEN; rc=$?
expect_deny too_few_fields
write_table "bad|sops|MY_TOKEN|$HELPER|extra"
broker as_main run bad -- "$HELPER" MY_TOKEN; rc=$?
expect_deny too_many_fields
for c in '' 'show-tool' 'bin/show-tool' "$HELPER," ",$HELPER" "*,$HELPER"; do
  write_table "bad|sops|MY_TOKEN|$c"
  PATH="$T/bin:$PATH" broker as_main run bad -- "$HELPER" MY_TOKEN; rc=$?
  check "allowed_commands_rejected_[$c]" all bad_rc not_run
done

# --- 表的存在、權限、擁有者 ---
default_table
rm -f "$TABLE"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny table_missing
default_table; chmod 666 "$TABLE"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny table_world_writable
chmod 620 "$TABLE"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny table_group_writable
default_table; chmod 777 "$FAKE_HOME/.config/agent-secret"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny table_dir_writable
chmod 700 "$FAKE_HOME/.config/agent-secret"
STAT_UID=0 broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny table_wrong_owner
# 環境變數不能換表或換後端：指到一張會放行的表也沒用
printf '%s\n' "tok-env|sops|MY_TOKEN|$HELPER" > "$T/evil.tsv"; chmod 600 "$T/evil.tsv"
AGENT_SECRET_ALIASES="$T/evil.tsv" MIYAGO_VAULT_ALIASES="$T/evil.tsv" AS_TABLE="$T/evil.tsv" \
  broker as_main run tok-env -- "$HELPER" MY_TOKEN; rc=$?
expect_deny env_cannot_override_table
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok table_ok_after_restore "$KC_VAL"

# --- 用法錯誤 ---
broker as_main run tok-sops "$HELPER" MY_TOKEN; rc=$?
expect_deny usage_missing_separator
broker as_main run tok-sops --; rc=$?
expect_deny usage_missing_command
broker as_main; rc=$?
check usage_no_mode bad_rc
broker as_main lock; rc=$?
check usage_unknown_mode bad_rc

# --- put ---
printf '%s\n' "$PUT_VAL" > "$T/in"; : > "$T/putlog"
SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?
check put_ok all ok_rc "called '^keychain put tok-sops sops$'" "grep -q '^keychain-stdin $PUT_VAL$' '$T/putlog'"
check put_value_not_in_args no_dummy "$CALLS" "$T/stderr" "$T/stdout"
SP=notfound STDIN="$T/in" broker as_main put tok-kc; rc=$?
check put_keychain_only_passes_tier all ok_rc "called '^keychain put tok-kc keychain-only$'"
SP=found STDIN="$T/in" broker as_main put tok-sops; rc=$?
check put_refused_when_in_sops all bad_rc "not_called '^keychain put'"
SP=found STDIN="$T/in" broker as_main put tok-kc; rc=$?
check put_keychain_only_refused_when_in_sops all bad_rc "not_called '^keychain put'"
SP=error STDIN="$T/in" broker as_main put tok-sops; rc=$?
check put_refused_when_sops_state_unknown all bad_rc "not_called '^keychain put'"
SP=notfound KC=error STDIN="$T/in" broker as_main put tok-sops; rc=$?
check put_backend_error bad_rc
SP=notfound STDIN=/dev/null broker as_main put tok-sops; rc=$?
check put_empty_value all bad_rc "not_called '^keychain put'"
head -c 1025 /dev/zero | tr '\0' 'D' > "$T/long"
SP=notfound STDIN="$T/long" broker as_main put tok-sops; rc=$?
check put_too_long all bad_rc "not_called '^keychain put'"
printf 'DUMMY\tTAB\n' > "$T/ctl"
SP=notfound STDIN="$T/ctl" broker as_main put tok-sops; rc=$?
check put_control_char all bad_rc "not_called '^keychain put'"
printf 'DUMMY-LINE-1\nDUMMY-LINE-2\n' > "$T/multi"
SP=notfound STDIN="$T/multi" broker as_main put tok-sops; rc=$?
check put_multiline all bad_rc "not_called '^keychain put'"
SP=notfound STDIN="$T/in" broker as_main put unknown-alias; rc=$?
check put_unknown_alias all bad_rc "not_called '^keychain put'"
SP=notfound STDIN="$T/in" broker as_main put 'a.c'; rc=$?
check put_bad_alias all bad_rc "not_called '^keychain put'"

# --- 真實的 backend function（只 stub 最底層的 security / sops 執行檔）---
REAL_BACKEND=1 SEC_RC=0 STDIN="$T/in" broker as_main put tok-kc; rc=$?
check real_put_ok ok_rc
check real_put_argv_is_only_dash_i all "called '^security -i$'" "[ \"\$(grep -c '^security' '$CALLS')\" = 1 ]"
check real_put_argv_no_value all "no_dummy '$CALLS'" "! grep -q '$PUT_HEX' '$CALLS'"
check real_put_stdin_line grep -qx "add-generic-password -U -s agent-secret -a tok-kc -T \"\" -X $PUT_HEX" "$T/security-stdin"
REAL_BACKEND=1 SEC_RC=0 STDIN="$T/in" broker as_main put tok-sops; rc=$?
check real_put_sops_tier_no_T all ok_rc "grep -qx 'add-generic-password -U -s agent-secret -a tok-sops -X $PUT_HEX' '$T/security-stdin'"
REAL_BACKEND=1 SEC_RC=45 STDIN="$T/in" broker as_main put tok-sops; rc=$?
check real_put_security_error bad_rc
head -c 1024 /dev/zero | tr '\0' 'D' > "$T/max"
REAL_BACKEND=1 SEC_RC=0 STDIN="$T/max" broker as_main put tok-sops; rc=$?
check real_put_max_len_line_fits all ok_rc "[ \"\$(wc -c < '$T/security-stdin')\" -lt 3000 ]" "! grep -q '\\*' '$T/security-stdin'"

REAL_BACKEND=1 SEC_RC=0 SEC_OUT="$KC_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok real_keychain_found "$KC_VAL"
check real_keychain_get_argv called '^security find-generic-password -s agent-secret -a tok-sops -w$'
check real_keychain_found_no_sops not_called '^sops-bin'
REAL_BACKEND=1 SEC_RC=44 SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check real_exit44_no_sops_file all bad_rc not_run   # sops 檔不存在：fail closed
printf '%s\n' 'tok-sops: ENC[AES256_GCM,data:FAKE,type:str]' 'abc: ENC[AES256_GCM,data:FAKE,type:str]' 'sops:' '    age: []' \
  > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
REAL_BACKEND=1 SEC_RC=44 SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok real_exit44_falls_to_sops "$SOPS_VAL"
check real_sops_argv called "^sops-bin -d --extract \[\"tok-sops\"\] $FAKE_HOME/dotfile/secrets/agent.enc.yaml$"
for code in 1 36 51 128 255; do   # 36=-25308 互動不允許、51=-25293 驗證失敗、128=使用者取消
  REAL_BACKEND=1 SEC_RC=$code SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
  check "real_security_rc_${code}_fail_closed" all bad_rc not_run "not_called '^sops-bin'"
done
REAL_BACKEND=1 SEC_RC=44 SOPS_RC=1 SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny real_sops_decrypt_error
REAL_BACKEND=1 SEC_RC=44 SOPS_OUT="$SOPS_VAL" broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny real_keychain_only_exit44
check real_keychain_only_exit44_no_sops not_called '^sops-bin'
REAL_BACKEND=1 UNAME=Linux SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok real_linux_sops "$SOPS_VAL"
check real_linux_no_security not_called '^security'
# sops exists：只比對明文 key，不解密
REAL_BACKEND=1 broker eval 'as_paths; backend_sops exists tok-sops'; rc=$?
check real_sops_exists_yes all ok_rc "not_called '^sops-bin'"
REAL_BACKEND=1 broker eval 'as_paths; backend_sops exists tok'; rc=$?
check real_sops_exists_prefix_no all '[ "$rc" = 3 ]'
REAL_BACKEND=1 broker eval 'as_paths; backend_sops exists tok-kc'; rc=$?
check real_sops_exists_no all '[ "$rc" = 3 ]'
REAL_BACKEND=1 SEC_RC=44 STDIN="$T/in" broker as_main put tok-sops; rc=$?
check real_put_refused_when_in_sops_file all bad_rc "not_called '^security'"
rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"

# --- list / doctor ---
KC=found SP=found broker as_main list; rc=$?
check list_ok all ok_rc "grep -q '^tok-sops	sops	keychain=yes	sops=yes	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'" "grep -q '^tok-kc	keychain-only	' '$T/stdout'"
check list_no_value no_dummy "$T/stdout" "$T/stderr"
check list_never_reads_value all "not_called ' get '" "not_called ' put '"
UNAME=Linux KC=found SP=notfound broker as_main list; rc=$?
check list_linux all ok_rc "grep -q '^tok-sops	sops	keychain=n/a	sops=no	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'" "not_called '^keychain'"
KC=found SP=found broker as_main doctor; rc=$?
check doctor_flags_both_backends all bad_rc "grep -q '兩個 backend 都有: tok-sops' '$T/stdout'" "grep -q 'keychain-only 的 alias 出現在 sops: tok-kc' '$T/stdout'"
check doctor_no_value all "no_dummy '$T/stdout' '$T/stderr'" "not_called ' get '"
KC=found SP=notfound broker as_main doctor; rc=$?
check doctor_clean all ok_rc "grep -qx ok '$T/stdout'"
chmod 666 "$TABLE"
KC=found SP=notfound broker as_main doctor; rc=$?
check doctor_flags_table_perms all bad_rc "grep -q 'alias 表.*可寫' '$T/stdout'"
chmod 600 "$TABLE"
write_table "dup|sops|MY_TOKEN|$HELPER" "dup|sops|MY_TOKEN|$HELPER" "bad|sops|PATH|$HELPER"
KC=notfound SP=notfound broker as_main doctor; rc=$?
check doctor_flags_duplicates_and_invalid all bad_rc "grep -q '重複列: dup' '$T/stdout'" "grep -q '列不合法: bad' '$T/stdout'"
rm -f "$TABLE"
broker as_main doctor; rc=$?
check doctor_table_missing all bad_rc "grep -q 'alias 表不存在' '$T/stdout'"
broker as_main list; rc=$?
check list_table_missing_still_lists_simple all ok_rc "grep -q 'alias 表不存在' '$T/stdout'" "grep -q '^# simple' '$T/stdout'"

# === 呼叫端環境的隔離（review finding F1）===
# 這一段經由帶 -p shebang 的入口檔執行（不是 source 進測試 shell），環境由測試刻意弄髒。
default_table
REAL_OS=$(/usr/bin/uname -s 2>/dev/null || /bin/uname -s)
REAL_UID=$(/usr/bin/id -u)
if [ "$REAL_OS" = Darwin ]; then FAKE_OS=Linux; EXP_VAL=$KC_VAL; EXP_BACKEND=keychain
else FAKE_OS=Darwin; EXP_VAL=$SOPS_VAL; EXP_BACKEND=sops; fi
printf '%s\n' 'other-key: ENC[AES256_GCM,data:FAKE,type:str]' > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"

# 入口檔：與正式入口相同的 shebang；家目錄與最底層的執行檔以覆寫 function 替換
ENTRY="$T/bin/entry-tool"
cat > "$ENTRY" <<EOF
#!/bin/bash -p
# shellcheck disable=SC1090
source "$BROKER" || exit 97
as_home() { builtin printf '%s' "$FAKE_HOME"; }
_security() {
  builtin echo "security \$*" >> "$CALLS"
  if [[ \${1:-} == -i ]]; then /bin/cat > "$T/security-stdin"; return 0; fi
  builtin printf '%s' "$KC_VAL"
  return 0
}
_sops() { builtin echo "sops-bin \$*" >> "$CALLS"; builtin printf '%s' "$SOPS_VAL"; return 0; }
as_main "\$@"
EOF
chmod 755 "$ENTRY"
entry() {
  : > "$CALLS"
  /bin/rm -f "$OUT" "$ARGV" "$T/childpath" "$T/childbashenv" "$T/security-stdin"
  "$ENTRY" "$@" > "$T/stdout" 2> "$T/stderr" < "${STDIN:-/dev/null}"
}
absent() { [ ! -e "$1" ]; }

# --- BASH_ENV 與匯出的函式 ---
cat > "$T/benv" <<EOF
export() { builtin echo "export \$*" >> "$T/capture"; builtin export "\$@"; }
exec() { builtin echo "exec \$*" >> "$T/capture"; builtin exec "\$@"; }
printf() { builtin echo "printf \$*" >> "$T/capture"; builtin printf "\$@"; }
builtin echo sourced >> "$T/benv-marker"
EOF
# 對照組：同樣的手法對一般的 bash 確實有效（否則下面的測試沒有鑑別力）
BASH_ENV="$T/benv" /bin/bash -c 'export PROBE=DUMMY-NOT-A-SECRET-CONTROL'
check control_bash_env_hijacks_plain_bash all "grep -q DUMMY-NOT-A-SECRET-CONTROL '$T/capture'" "[ -s '$T/benv-marker' ]"
/bin/rm -f "$T/capture" "$T/benv-marker"
# shellcheck disable=SC1091
( source "$T/benv"; export -f export exec printf; /bin/bash -c 'export PROBE=DUMMY-NOT-A-SECRET-CONTROL' )
check control_exported_function_hijacks_plain_bash all "grep -q DUMMY-NOT-A-SECRET-CONTROL '$T/capture'"
/bin/rm -f "$T/capture" "$T/benv-marker"

BASH_ENV="$T/benv" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok bash_env_run_still_works "$EXP_VAL"
check bash_env_not_sourced all "absent '$T/benv-marker'" "absent '$T/capture'"
check bash_env_not_passed_to_child all "grep -qx unset '$T/childbashenv'"
STDIN="$T/in" BASH_ENV="$T/benv" entry put tok-sops; rc=$?
check bash_env_put_not_sourced all "absent '$T/benv-marker'" "absent '$T/capture'"

# shellcheck disable=SC1091
( source "$T/benv"; /bin/rm -f "$T/capture" "$T/benv-marker"; export -f export exec printf
  entry run tok-sops -- "$HELPER" MY_TOKEN ); rc=$?
expect_ok exported_functions_run_still_works "$EXP_VAL"
check exported_functions_capture_no_value all "! grep -q DUMMY-NOT-A-SECRET '$T/capture'" "! grep -q '^printf\\|^exec' '$T/capture'"
# shellcheck disable=SC1091
( source "$T/benv"; /bin/rm -f "$T/capture" "$T/benv-marker"; export -f export exec printf
  STDIN="$T/in" entry put tok-sops ); rc=$?
check exported_functions_put_capture_no_value all "! grep -q 'DUMMY-NOT-A-SECRET\\|$PUT_HEX' '$T/capture'"
/bin/rm -f "$T/capture" "$T/benv-marker"

# 正式入口本身（真實家目錄；alias 不存在或表不存在都會在取值前失敗）
BASH_ENV="$T/benv" "$BROKER" run zz-no-such-alias-for-test -- /bin/ls > "$T/stdout" 2> "$T/stderr"; rc=$?
check real_entry_bash_env_not_sourced all bad_rc "absent '$T/benv-marker'" "absent '$T/capture'" "grep -q '^agent-secret: ' '$T/stderr'"
# shellcheck disable=SC1091
( source "$T/benv"; /bin/rm -f "$T/capture" "$T/benv-marker"; export -f export exec printf
  "$BROKER" run zz-no-such-alias-for-test -- /bin/ls > "$T/stdout" 2> "$T/stderr" ); rc=$?
check real_entry_exported_functions_not_imported all bad_rc "! grep -q '^printf' '$T/capture'" "grep -q '^agent-secret: ' '$T/stderr'"
/bin/rm -f "$T/capture" "$T/benv-marker"

# --- 不是 privileged 模式就拒絕 ---
/bin/bash "$BROKER" run tok-sops -- "$HELPER" MY_TOKEN > "$T/stdout" 2> "$T/stderr"; rc=$?
check direct_bash_refused all bad_rc "grep -q 'privileged' '$T/stderr'"
/bin/bash "$BROKER" doctor > "$T/stdout" 2> "$T/stderr"; rc=$?
check direct_bash_doctor_refused all bad_rc "grep -q 'privileged' '$T/stderr'" "[ ! -s '$T/stdout' ]"
/bin/rm -f "$OUT"
/bin/bash "$ENTRY" run tok-sops -- "$HELPER" MY_TOKEN > "$T/stdout" 2> "$T/stderr"; rc=$?
check direct_bash_entry_refused all bad_rc not_run "grep -q 'privileged' '$T/stderr'"
# shellcheck disable=SC1090
( source "$BROKER" && echo loaded ) > "$T/stdout" 2> "$T/stderr"; rc=$?
check plain_source_refused all bad_rc "! grep -q loaded '$T/stdout'" "grep -q 'privileged' '$T/stderr'"
# shellcheck disable=SC1090
( set -p; printf() { builtin printf "$@"; }; source "$BROKER" && echo loaded ) > "$T/stdout" 2> "$T/stderr"; rc=$?
check shadowed_builtin_refused all bad_rc "! grep -q loaded '$T/stdout'" "grep -q '遮蔽' '$T/stderr'"

# --- PATH 前置假程式 ---
mkdir "$T/fake"
for f in cat od tr awk stat id uname readlink dirname security sops; do
  cat > "$T/fake/$f" <<EOF
#!/bin/sh
echo "$f \$*" >> "$T/fakelog"
case $f in
  cat|od|tr|awk) /bin/cat >> "$T/fakelog" ;;
  stat) echo "$REAL_UID 600" ;;
  id) echo "$REAL_UID" ;;
  uname) echo "$FAKE_OS" ;;
esac
exit 0
EOF
  chmod 755 "$T/fake/$f"
done
FAKE_PATH="$T/fake:$PATH"
printf '%s\n' "$FAKE_PATH" > "$T/expectpath"
PATH="$FAKE_PATH" /bin/sh -c 'uname; stat x; echo DUMMY-NOT-A-SECRET-CONTROL | cat' > "$T/stdout" 2>/dev/null
check control_fake_path_hijacks_plain_sh all "grep -qx '$FAKE_OS' '$T/stdout'" "grep -q DUMMY-NOT-A-SECRET-CONTROL '$T/fakelog'"
/bin/rm -f "$T/fakelog"

PATH="$FAKE_PATH" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok fake_path_run_ok "$EXP_VAL"
check fake_path_run_no_fake_called absent "$T/fakelog"
check fake_path_tier_unaffected stderr_has "alias=tok-sops backend=$EXP_BACKEND"
check fake_path_restored_for_child cmp -s "$T/expectpath" "$T/childpath"
PATH="$FAKE_PATH" entry run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
if [ "$REAL_OS" = Darwin ]; then expect_ok fake_uname_cannot_change_platform "$KC_VAL"
else expect_deny fake_uname_cannot_change_platform; fi
check fake_path_keychain_only_no_fake_called absent "$T/fakelog"
PATH="$FAKE_PATH" entry run tok-sops -- show-tool MY_TOKEN; rc=$?
expect_deny fake_path_bare_name_not_in_caller_path
PATH="$T/bin:$FAKE_PATH" entry run tok-sops -- show-tool MY_TOKEN; rc=$?
expect_ok fake_path_bare_name_uses_caller_path "$EXP_VAL"
check fake_path_bare_name_no_fake_called absent "$T/fakelog"

chmod 666 "$TABLE"
PATH="$FAKE_PATH" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check fake_stat_id_cannot_pass_bad_perms all bad_rc not_run "absent '$T/fakelog'" "not_called '^security'"
chmod 600 "$TABLE"

STDIN="$T/in" PATH="$FAKE_PATH" entry put tok-sops; rc=$?
if [ "$REAL_OS" = Darwin ]; then
  check fake_path_put_ok all ok_rc "grep -qx 'add-generic-password -U -s agent-secret -a tok-sops -X $PUT_HEX' '$T/security-stdin'"
else
  check fake_path_put_refused_off_macos all bad_rc "absent '$T/security-stdin'"
fi
check fake_path_put_no_fake_called absent "$T/fakelog"
PATH="$FAKE_PATH" entry list; rc=$?
check fake_path_list_no_fake_called all ok_rc "absent '$T/fakelog'"
PATH="$FAKE_PATH" entry doctor; rc=$?
check fake_path_doctor_no_fake_called absent "$T/fakelog"

# 真正的 _security / _sops（不 stub）用的是絕對路徑：help 不碰任何 Keychain 項目或加密檔
PATH="$FAKE_PATH" REAL_BACKEND=2 broker eval 'as_paths; _security help >/dev/null 2>&1; _sops --help >/dev/null 2>&1; true'; rc=$?
check real_security_sops_ignore_path all ok_rc "absent '$T/fakelog'"

# --- HOME 換不了表 ---
mkdir -p "$T/evilhome/.config/agent-secret"; chmod 700 "$T/evilhome/.config/agent-secret"
printf '%s\n' 'tok-evil|sops|MY_TOKEN|*' "tok-sops|sops|MY_TOKEN|/nonexistent/only" > "$T/evilhome/.config/agent-secret/aliases.tsv"
chmod 600 "$T/evilhome/.config/agent-secret/aliases.tsv"
HOME="$T/evilhome" entry run tok-evil -- "$HELPER" MY_TOKEN; rc=$?
expect_deny home_env_cannot_swap_table
check home_env_cannot_swap_table_no_backend not_called '^security'
HOME="$T/evilhome" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok home_env_still_uses_account_home_table "$EXP_VAL"
# 真正的 as_home：HOME 被改掉時仍回帳號資料庫裡的家目錄（用 dscl / getent 當獨立對照）
if [ "$REAL_OS" = Darwin ]; then
  ORACLE=$(/usr/bin/dscl . -read "/Users/$(/usr/bin/id -un)" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')
else
  ORACLE=$(getent passwd "$REAL_UID" | cut -d: -f6)
fi
printf '%s' "${ORACLE%/}" > "$T/oracle"
HOME="$T/evilhome" REAL_HOME=1 broker as_home; rc=$?
check as_home_ignores_home_env all ok_rc "[ -s '$T/oracle' ]" "cmp -s '$T/oracle' '$T/stdout'"
HOME="$T/evilhome" REAL_HOME=1 REAL_BACKEND=2 broker eval 'as_paths; builtin printf "%s" "$AS_TABLE"'; rc=$?
printf '%s' "${ORACLE%/}/.config/agent-secret/aliases.tsv" > "$T/oracle"
check table_path_derived_from_account_home all ok_rc "cmp -s '$T/oracle' '$T/stdout'"

# --- 其他會影響 shell 行為的變數 ---
(cd "$T" && CDPATH=/usr entry run tok-sops -- bin/show-tool MY_TOKEN); rc=$?
expect_ok cdpath_ignored "$EXP_VAL"
GLOBIGNORE='*' ENV="$T/benv" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok env_and_globignore_ignored "$EXP_VAL"
check env_var_not_sourced absent "$T/benv-marker"
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml" "$TABLE"

# === 簡易模式（Miyago 2026-10-05）：大寫名稱不需要登記，取得值的指令沒有限制 ===
default_table
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
stdout_is() { [ "$(cat "$T/stdout")" = "$1" ]; }

# --- 解析順序與 sops tier 相同 ---
KC=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_keychain_hit "$KC_VAL"
check simple_keychain_hit_no_sops not_called '^sops get'
check simple_logs_mode stderr_has 'name=MY_SIMPLE backend=keychain mode=simple'
check simple_no_value_in_logs no_dummy "$T/stderr" "$T/stdout" "$ARGV" "$CALLS"
KC=notfound SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_notfound_falls_to_sops "$SOPS_VAL"
check simple_falls_logs_backend stderr_has 'name=MY_SIMPLE backend=sops mode=simple'
KC=error SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny simple_keychain_error_no_fallthrough
check simple_keychain_error_no_sops_call not_called '^sops'
KC=notfound SP=notfound broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny simple_missing_everywhere
KC=notfound SP=error broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny simple_sops_error
KC=empty broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny simple_empty_value
UNAME=Linux KC=found SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_linux_uses_sops "$SOPS_VAL"
check simple_linux_no_keychain_call not_called '^keychain'
REAL_BACKEND=1 SEC_RC=0 SEC_OUT="$KC_VAL" broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_real_backend_found "$KC_VAL"
check simple_real_backend_argv called '^security find-generic-password -s agent-secret -a MY_SIMPLE -w$'
for code in 1 36 51 128; do
  REAL_BACKEND=1 SEC_RC=$code SOPS_OUT="$SOPS_VAL" broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  check "simple_real_security_rc_${code}_fail_closed" all bad_rc not_run "not_called '^sops-bin'"
done

# --- 名稱：格式不合或撞到拒絕清單 ---
for nm in My_Token MY-TOKEN 1ABC _ABC A.B 'A B' 'A=B' 'ABC|x' 'A*'; do
  broker as_main run "$nm" -- "$HELPER" MY_SIMPLE; rc=$?
  check "simple_name_rejected_[$nm]" all bad_rc not_run "not_called '^keychain'" "not_called '^sops'"
done
for nm in PATH HOME SHELL IFS ENV BASH_ENV LD_PRELOAD DYLD_INSERT_LIBRARIES NODE_OPTIONS PYTHONPATH GIT_SSH_COMMAND; do
  broker as_main run "$nm" -- "$HELPER" "$nm"; rc=$?
  check "simple_denylisted_name_[$nm]" all bad_rc not_run "not_called '^keychain'" "not_called '^sops'"
  STDIN="$T/in" SP=notfound broker as_main put "$nm"; rc=$?
  check "simple_put_denylisted_name_[$nm]" all bad_rc "not_called '^keychain'"
done

# --- 指令沒有限制：sh -c、env、直譯器都可以 ---
broker as_main run MY_SIMPLE -- sh -c 'printf %s "$MY_SIMPLE"'; rc=$?
check simple_sh_c_gets_value all ok_rc "stdout_is '$KC_VAL'"
broker as_main run MY_SIMPLE -- /bin/sh -c 'printf %s "$MY_SIMPLE"'; rc=$?
check simple_abs_sh_c_gets_value all ok_rc "stdout_is '$KC_VAL'"
broker as_main run MY_SIMPLE -- env; rc=$?
check simple_env_allowed all ok_rc "grep -qx 'MY_SIMPLE=$KC_VAL' '$T/stdout'"
broker as_main run MY_SIMPLE -- "$T/bin/other-tool" MY_SIMPLE; rc=$?
expect_ok simple_any_tool "$KC_VAL"
broker as_main run MY_SIMPLE -- no-such-command-xyz; rc=$?
expect_deny simple_command_not_found
check simple_command_not_found_no_backend not_called '^keychain'
broker as_main run MY_SIMPLE -- "$TABLE"; rc=$?
expect_deny simple_command_not_executable
broker as_main run MY_SIMPLE "$HELPER" MY_SIMPLE; rc=$?
expect_deny simple_usage_missing_separator

# --- alias 表不存在、空的、權限不對：簡易模式都不讀它 ---
/bin/rm -f "$TABLE"
broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_works_without_table "$KC_VAL"
STDIN="$T/in" SP=notfound broker as_main put MY_SIMPLE; rc=$?
check simple_put_works_without_table all ok_rc "called '^keychain put MY_SIMPLE simple$'"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny registered_still_needs_table
write_table '# only comments' ''
broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_works_with_empty_table "$KC_VAL"
default_table; chmod 666 "$TABLE"
broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_ignores_table_perms "$KC_VAL"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny registered_still_checks_table_perms
chmod 600 "$TABLE"

# --- put / rm ---
: > "$T/putlog"
STDIN="$T/in" SP=notfound broker as_main put MY_SIMPLE; rc=$?
check simple_put_ok all ok_rc "called '^keychain put MY_SIMPLE simple$'" "grep -q '^keychain-stdin $PUT_VAL$' '$T/putlog'"
check simple_put_value_not_in_args no_dummy "$CALLS" "$T/stderr" "$T/stdout"
STDIN="$T/in" SP=found broker as_main put MY_SIMPLE; rc=$?
check simple_put_refused_when_in_sops all bad_rc "not_called '^keychain put'"
STDIN="$T/in" SP=notfound UNAME=Linux broker as_main put MY_SIMPLE; rc=$?
check simple_put_refused_off_macos all bad_rc "not_called '^keychain'" "grep -q 'edit' '$T/stderr'"
STDIN=/dev/null SP=notfound broker as_main put MY_SIMPLE; rc=$?
check simple_put_empty_value all bad_rc "not_called '^keychain put'"
STDIN="$T/long" SP=notfound broker as_main put MY_SIMPLE; rc=$?
check simple_put_too_long all bad_rc "not_called '^keychain put'"
STDIN="$T/multi" SP=notfound broker as_main put MY_SIMPLE; rc=$?
check simple_put_multiline all bad_rc "not_called '^keychain put'"
REAL_BACKEND=1 SEC_RC=0 STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check simple_real_put_normal_acl all ok_rc "grep -qx 'add-generic-password -U -s agent-secret -a MY_SIMPLE -X $PUT_HEX' '$T/security-stdin'" "! grep -q -- '-T' '$T/security-stdin'"
check simple_real_put_argv_no_value all "called '^security -i$'" "no_dummy '$CALLS'" "! grep -q '$PUT_HEX' '$CALLS'"
broker as_main rm tok-sops; rc=$?
check rm_registered_alias_refused all bad_rc "not_called '^keychain'"
broker as_main rm tok-kc; rc=$?
check rm_registered_keychain_only_refused all bad_rc "not_called '^keychain'"
broker as_main rm PATH; rc=$?
check rm_denylisted_name_refused all bad_rc "not_called '^keychain'"
broker as_main rm 'A B'; rc=$?
check rm_bad_name_refused all bad_rc "not_called '^keychain'"
broker as_main rm; rc=$?
check rm_usage bad_rc
UNAME=Linux broker as_main rm MY_SIMPLE; rc=$?
check rm_refused_off_macos all bad_rc "not_called '^keychain'"
KC=notfound broker as_main rm MY_SIMPLE; rc=$?
check rm_missing_item_fails all bad_rc "called '^keychain delete MY_SIMPLE'"
KC=error broker as_main rm MY_SIMPLE; rc=$?
check rm_backend_error_fails bad_rc

# --- put 之後 list 看得到、rm 之後看不到（假的 Keychain 儲存，走真正的 backend function）---
kc_item() { # <account> <service> <class>：仿 security dump-keychain（不帶 -d）的一個項目
  printf 'keychain: "/fake/login.keychain-db"\nversion: 512\nclass: "%s"\nattributes:\n    0x00000007 <blob>="%s"\n    0x00000008 <blob>=<NULL>\n    "acct"<blob>="%s"\n    "cdat"<timedate>=0x32303236  "2026"\n    "svce"<blob>="%s"\n    "type"<uint32>=<NULL>\n' "$3" "$2" "$1" "$2"
}
/bin/rm -rf "$T/kcstore"; mkdir "$T/kcstore"
{ kc_item OTHER_SERVICE_NAME some-other-service genp
  kc_item TEST_SERVICE_NAME agent-secret-test genp
  kc_item LOOKALIKE_SERVICE agent-secret2 genp
  kc_item INET_CLASS_NAME agent-secret inet
  kc_item tok-lower agent-secret genp
  kc_item PATH agent-secret genp
  printf 'keychain: "/fake/login.keychain-db"\nversion: 512\nclass: "genp"\nattributes:\n    "acct"<blob>=0x41420A  "AB\\012"\n    "svce"<blob>="agent-secret"\n'
} > "$T/kcdecoys"
REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_empty all ok_rc "! grep -q '	simple	' '$T/stdout'" "grep -q '^# simple' '$T/stdout'" "grep -q '^# registered' '$T/stdout'"
REAL_BACKEND=3 STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check store_put_ok ok_rc
printf '%s\n' 'DUMMY-NOT-A-SECRET-SECOND' > "$T/in2"
REAL_BACKEND=3 STDIN="$T/in2" broker as_main put SECOND_NAME_2; rc=$?
check store_put_second_ok ok_rc
REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_shows_put all ok_rc "grep -qx 'MY_SIMPLE	simple	keychain=yes	sops=no' '$T/stdout'" "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=no' '$T/stdout'"
check store_list_only_simple_names all "[ \"\$(grep -c '	simple	' '$T/stdout')\" = 2 ]" "! grep -q 'OTHER_SERVICE_NAME\|TEST_SERVICE_NAME\|LOOKALIKE_SERVICE\|INET_CLASS_NAME\|^PATH\|^AB' '$T/stdout'"
check store_list_keeps_registered_rows all "grep -q '^tok-sops	sops	keychain=no	sops=no	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'" "grep -q '^tok-kc	keychain-only	keychain=no	sops=no	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'"
check store_list_no_value all "no_dummy '$T/stdout' '$T/stderr'" "! grep -q '$PUT_HEX' '$T/stdout'"
check store_list_reads_attributes_only all "called '^security dump-keychain$'" "not_called ' -w'" "not_called 'dump-keychain -d'" "not_called 'dump-keychain .*-d'" "not_called '^sops-bin'"
REAL_BACKEND=3 broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok store_run_gets_put_value "$PUT_VAL"
REAL_BACKEND=3 broker as_main doctor; rc=$?
check store_doctor_counts_simple all "grep -q '^INFO 簡易模式 2 個名稱' '$T/stdout'" "grep -q '沒有限制' '$T/stdout'" "no_dummy '$T/stdout'"
REAL_BACKEND=3 broker as_main rm MY_SIMPLE; rc=$?
check store_rm_ok all ok_rc "called '^security delete-generic-password -s agent-secret -a MY_SIMPLE$'"
REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_after_rm all ok_rc "! grep -q '^MY_SIMPLE' '$T/stdout'" "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=no' '$T/stdout'"
REAL_BACKEND=3 broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny store_run_after_rm_fails
REAL_BACKEND=3 broker as_main rm MY_SIMPLE; rc=$?
check store_rm_again_fails bad_rc
REAL_BACKEND=3 broker as_main rm tok-sops; rc=$?
check store_rm_registered_refused all bad_rc "not_called '^security'"
# 加密檔裡的大寫 key 也算簡易模式的名稱（key 是明文，不解密）
printf '%s\n' 'SOPS_ONLY: ENC[AES256_GCM,data:FAKE,type:str]' 'SECOND_NAME_2: ENC[AES256_GCM,data:FAKE,type:str]' 'tok-sops: ENC[AES256_GCM,data:FAKE,type:str]' 'sops:' '    age: []' \
  > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_sops_names all ok_rc "grep -qx 'SOPS_ONLY	simple	keychain=no	sops=yes' '$T/stdout'" "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=yes' '$T/stdout'" "not_called '^sops-bin'"
REAL_BACKEND=3 UNAME=Linux broker as_main list; rc=$?
check store_list_linux all ok_rc "grep -qx 'SOPS_ONLY	simple	keychain=n/a	sops=yes' '$T/stdout'" "not_called '^security'"
REAL_BACKEND=3 broker as_main doctor; rc=$?
check store_doctor_warns_both_backends all "grep -q '^WARN 簡易模式的名稱兩個 backend 都有: SECOND_NAME_2' '$T/stdout'" "grep -q '^INFO 簡易模式 2 個名稱' '$T/stdout'"
REAL_BACKEND=3 STDIN="$T/in" broker as_main put SOPS_ONLY; rc=$?
check store_put_refused_when_in_sops_file all bad_rc "not_called '^security -i'"
DUMP_RC=1 REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_enumeration_error_fails all bad_rc "grep -q '^tok-sops	sops' '$T/stdout'"
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml" "$TABLE"
REAL_BACKEND=3 broker as_main list; rc=$?
check list_without_table_shows_simple all ok_rc "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=no' '$T/stdout'" "grep -q 'alias 表不存在' '$T/stdout'"
default_table

# --- allowed_commands 為 *：真的沒有限制；列出路徑的 alias 不變 ---
cat > "$T/bin/npx" <<EOF
#!/bin/bash -p
builtin printf '%s' "\${MY_TOKEN:-}" > "$OUT"
builtin printf '%s\n' "\$@" > "$ARGV"
EOF
chmod 755 "$T/bin/npx"
PATH="$T/bin:$PATH" broker as_main run tok-star -- npx some-package --flag; rc=$?
expect_ok star_npx_form "$KC_VAL"
check star_npx_argv_no_value no_dummy "$ARGV"
broker as_main run tok-star -- env JEV_ENABLE=1 "$HELPER" MY_TOKEN; rc=$?
expect_ok star_env_wrapper_form "$KC_VAL"
for c in sh /bin/sh bash zsh "$T/bin/innocent-name"; do
  broker as_main run tok-star -- "$c" -c 'printf %s "$MY_TOKEN"'; rc=$?
  check "star_allows_${c##*/}_c" all ok_rc "stdout_is '$KC_VAL'"
done
broker as_main run tok-star -- printenv MY_TOKEN; rc=$?
check star_allows_printenv all ok_rc "stdout_is '$KC_VAL'"
broker as_main run tok-star -- /usr/bin/env; rc=$?
check star_allows_env all ok_rc "grep -qx 'MY_TOKEN=$KC_VAL' '$T/stdout'"
broker as_main run tok-star -- no-such-command-xyz; rc=$?
expect_deny star_command_not_found
KC=error broker as_main run tok-star -- sh -c 'printf %s "$MY_TOKEN"'; rc=$?
check star_still_fails_closed_on_backend_error all bad_rc "! grep -q DUMMY '$T/stdout'"
# 列出明確路徑：不符即拒；shell 與直譯器即使列在清單內也拒
for c in sh /bin/sh bash env /usr/bin/env printenv python3 "$T/bin/innocent-name"; do
  broker as_main run tok-sops -- "$c" -c 'printf %s "$MY_TOKEN"'; rc=$?
  check "listed_denies_${c##*/}" all bad_rc not_run "not_called '^keychain'" "no_dummy '$T/stdout' '$T/stderr'"
done
broker as_main run tok-shlist -- /bin/sh -c 'printf %s "$MY_TOKEN"'; rc=$?
check listed_shell_in_list_still_denied all bad_rc "not_called '^keychain'" "no_dummy '$T/stdout'"
broker as_main run tok-shlist -- "$HELPER" MY_TOKEN; rc=$?
expect_ok listed_other_entry_ok "$KC_VAL"
# keychain-only 加明確路徑（真實表裡 claude-eval 的組合）
KC=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_ok keychain_only_listed_path_ok "$KC_VAL"
for c in sh env "$T/bin/other-tool" "$T/bin/npx"; do
  broker as_main run tok-kc -- "$c" -c 'printf %s "$MY_TOKEN"'; rc=$?
  check "keychain_only_listed_denies_${c##*/}" all bad_rc not_run "not_called '^keychain'" "not_called '^sops'"
done
KC=notfound SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny keychain_only_listed_never_sops
REAL_BACKEND=1 SEC_RC=0 STDIN="$T/in" broker as_main put tok-kc; rc=$?
check keychain_only_put_still_uses_empty_acl all ok_rc "grep -qx 'add-generic-password -U -s agent-secret -a tok-kc -T \"\" -X $PUT_HEX' '$T/security-stdin'"
KC=found SP=notfound broker as_main doctor; rc=$?
check doctor_star_is_info_not_problem all ok_rc "grep -q '^INFO allowed_commands 是 \\*：沒有指令限制.*tok-star' '$T/stdout'" "! grep -q '^PROBLEM' '$T/stdout'"

# --- 呼叫端環境的隔離對簡易模式同樣成立（經由帶 -p shebang 的入口檔）---
/bin/rm -f "$TABLE" "$T/capture" "$T/benv-marker" "$T/fakelog"
printf '%s\n' 'other-key: ENC[AES256_GCM,data:FAKE,type:str]' > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
BASH_ENV="$T/benv" entry run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_bash_env_run_works "$EXP_VAL"
check simple_bash_env_not_sourced all "absent '$T/benv-marker'" "absent '$T/capture'"
# shellcheck disable=SC1091
( source "$T/benv"; /bin/rm -f "$T/capture" "$T/benv-marker"; export -f export exec printf
  entry run MY_SIMPLE -- "$HELPER" MY_SIMPLE ); rc=$?
expect_ok simple_exported_functions_run_works "$EXP_VAL"
check simple_exported_functions_no_capture all "! grep -q DUMMY-NOT-A-SECRET '$T/capture'" "! grep -q '^printf\\|^exec' '$T/capture'"
/bin/rm -f "$T/capture" "$T/benv-marker"
PATH="$FAKE_PATH" entry run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_fake_path_run_ok "$EXP_VAL"
check simple_fake_path_no_fake_called absent "$T/fakelog"
check simple_fake_path_backend_unaffected stderr_has "name=MY_SIMPLE backend=$EXP_BACKEND mode=simple"
check simple_fake_path_restored_for_child cmp -s "$T/expectpath" "$T/childpath"
STDIN="$T/in" PATH="$FAKE_PATH" entry put MY_SIMPLE; rc=$?
if [ "$REAL_OS" = Darwin ]; then
  check simple_fake_path_put_ok all ok_rc "grep -qx 'add-generic-password -U -s agent-secret -a MY_SIMPLE -X $PUT_HEX' '$T/security-stdin'"
else
  check simple_fake_path_put_refused_off_macos all bad_rc "absent '$T/security-stdin'"
fi
check simple_fake_path_put_no_fake_called absent "$T/fakelog"
PATH="$FAKE_PATH" entry list; rc=$?
check simple_fake_path_list_no_fake_called all ok_rc "absent '$T/fakelog'"
PATH="$FAKE_PATH" entry rm MY_SIMPLE; rc=$?
check simple_fake_path_rm_no_fake_called absent "$T/fakelog"
HOME="$T/evilhome" entry run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok simple_home_env_ignored "$EXP_VAL"
/bin/bash "$BROKER" run MY_SIMPLE -- "$HELPER" MY_SIMPLE > "$T/stdout" 2> "$T/stderr"; rc=$?
check simple_direct_bash_refused all bad_rc "grep -q 'privileged' '$T/stderr'"
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"

# === alias 表裡的大寫名稱列不會變成簡易模式（finding A1）===
write_table \
  "tok-sops|sops|MY_TOKEN|$HELPER" \
  "UPPER_ROW|keychain-only|UPPER_ROW|$HELPER" \
  "BAD_ROW|nonsense" \
  "ONLY_NAME"
for nm in UPPER_ROW BAD_ROW ONLY_NAME; do
  broker as_main run "$nm" -- /bin/sh -c 'printf %s "$UPPER_ROW$BAD_ROW$ONLY_NAME"'; rc=$?
  check "table_upper_row_run_refused_[$nm]" all bad_rc "not_called '^keychain'" "not_called '^sops'" "no_dummy '$T/stdout'" "grep -q '小寫' '$T/stderr'"
  broker as_main run "$nm" -- "$HELPER" "$nm"; rc=$?
  check "table_upper_row_run_helper_refused_[$nm]" all bad_rc not_run "not_called '^keychain'" "not_called '^sops'"
  STDIN="$T/in" SP=notfound broker as_main put "$nm"; rc=$?
  check "table_upper_row_put_refused_[$nm]" all bad_rc "not_called '^keychain'" "not_called '^sops'" "grep -q '小寫' '$T/stderr'"
  broker as_main rm "$nm"; rc=$?
  check "table_upper_row_rm_refused_[$nm]" all bad_rc "not_called '^keychain'" "not_called '^sops'" "grep -q '小寫' '$T/stderr'"
done
REAL_BACKEND=1 SEC_RC=0 STDIN="$T/in" broker as_main put UPPER_ROW; rc=$?
check table_upper_row_put_no_security_call all bad_rc "not_called '^security'"
# 同一張表：不在表內的大寫名稱與小寫 alias 照常
broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok table_upper_row_other_simple_name_ok "$KC_VAL"
broker as_main run UPPER -- "$HELPER" UPPER; rc=$?
expect_ok table_upper_row_prefix_not_matched "$KC_VAL"
broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok table_upper_row_registered_alias_ok "$KC_VAL"
# 表的權限不對時，比對照做（不可信的表只會造成拒絕，不會造成放行）
chmod 666 "$TABLE"
broker as_main run UPPER_ROW -- "$HELPER" UPPER_ROW; rc=$?
expect_deny table_upper_row_refused_even_with_bad_perms
chmod 600 "$TABLE"
default_table

# === 名稱分類不受呼叫端 locale 影響（finding A2）===
printf '%s\n' 'other-key: ENC[AES256_GCM,data:FAKE,type:str]' > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
for loc in en_US.US-ASCII en_US.UTF-8 zh_TW.UTF-8 cs_CZ.UTF-8; do
  ( export LC_ALL="$loc" LANG="$loc"; unset LC_COLLATE; export LC_CTYPE="$loc"
    printf '%s|%s|unset|%s\n' "$loc" "$loc" "$loc" > "$T/expectlocale"
    entry run TOK -- "$HELPER" TOK ); rc=$?
  expect_ok "locale_${loc}_upper_name_is_simple" "$EXP_VAL"
  check "locale_${loc}_restored_for_child" cmp -s "$T/expectlocale" "$T/childlocale"
  ( export LC_ALL="$loc" LANG="$loc"; entry run tok_x -- "$HELPER" tok_x ); rc=$?
  check "locale_${loc}_lower_underscore_not_simple" all bad_rc not_run "not_called '^security'" "grep -q '名稱不合法' '$T/stderr'"
  ( export LC_ALL="$loc" LANG="$loc"; entry run Tok -- "$HELPER" Tok ); rc=$?
  check "locale_${loc}_mixed_case_rejected" all bad_rc not_run "not_called '^security'"
  ( export LC_ALL="$loc" LANG="$loc"; entry run tok-sops -- "$HELPER" MY_TOKEN ); rc=$?
  expect_ok "locale_${loc}_registered_alias_ok" "$EXP_VAL"
  ( export LC_ALL="$loc" LANG="$loc"; entry run TOK-SOPS -- "$HELPER" MY_TOKEN ); rc=$?
  check "locale_${loc}_upper_alias_not_registered" all bad_rc not_run "not_called '^security'"
done
( unset LC_ALL LANG LC_COLLATE LC_CTYPE; printf '%s\n' 'unset|unset|unset|unset' > "$T/expectlocale"
  entry run MY_SIMPLE -- "$HELPER" MY_SIMPLE ); rc=$?
expect_ok locale_unset_run_ok "$EXP_VAL"
check locale_unset_stays_unset_for_child cmp -s "$T/expectlocale" "$T/childlocale"
( unset LC_ALL LC_CTYPE; export LANG=zh_TW.UTF-8 LC_COLLATE=en_US.US-ASCII; printf '%s\n' 'unset|zh_TW.UTF-8|en_US.US-ASCII|unset' > "$T/expectlocale"
  entry run tok-sops -- "$HELPER" MY_TOKEN ); rc=$?
expect_ok locale_partial_registered_ok "$EXP_VAL"
check locale_partial_restored_for_child cmp -s "$T/expectlocale" "$T/childlocale"
( export LC_ALL=en_US.US-ASCII; PATH="$FAKE_PATH" entry list ); rc=$?
check locale_list_ok all ok_rc "absent '$T/fakelog'"
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"

# === list：已登記的列顯示注入的環境變數名稱與指令限制 ===
write_table \
  "one-path|sops|ONE_TOKEN|/opt/homebrew/bin/gh" \
  "multi-path|keychain-only|MULTI_TOKEN|/usr/local/bin/a-tool,/opt/homebrew/bin/b-tool,$HELPER" \
  "any-cmd|sops|ANY_TOKEN|*" \
  "bad-env|sops|PATH|/bin/ls" \
  "bad-fields|sops" \
  "UPPER_ROW|sops|UPPER_ROW|*"
KC=found SP=notfound broker as_main list; rc=$?
check list_cols_single_path all ok_rc "grep -qx 'one-path	sops	keychain=yes	sops=no	env=ONE_TOKEN	cmds=/opt/homebrew/bin/gh' '$T/stdout'"
check list_cols_multi_path grep -qx "multi-path	keychain-only	keychain=yes	sops=no	env=MULTI_TOKEN	cmds=/usr/local/bin/a-tool,/opt/homebrew/bin/b-tool,$HELPER" "$T/stdout"
check list_cols_star grep -qxF 'any-cmd	sops	keychain=yes	sops=no	env=ANY_TOKEN	cmds=*' "$T/stdout"
check list_cols_invalid_rows all "grep -qx 'bad-env	sops	INVALID' '$T/stdout'" "grep -qx 'bad-fields	sops	INVALID' '$T/stdout'" "grep -qx 'UPPER_ROW	sops	INVALID' '$T/stdout'"
check list_cols_invalid_rows_no_metadata all "! grep -q 'env=PATH' '$T/stdout'" "! grep -q 'env=UPPER_ROW' '$T/stdout'"
check list_cols_field_count all "[ \"\$(grep -c '	env=' '$T/stdout')\" = 3 ]" "[ \"\$(awk -F'\t' '/^(one-path|multi-path|any-cmd)\t/ && NF != 6' '$T/stdout' | wc -l | tr -d ' ')\" = 0 ]"
check list_cols_no_value all "no_dummy '$T/stdout' '$T/stderr'" "not_called ' get '"
UNAME=Linux KC=found SP=found broker as_main list; rc=$?
check list_cols_linux all ok_rc "grep -qxF 'any-cmd	sops	keychain=n/a	sops=yes	env=ANY_TOKEN	cmds=*' '$T/stdout'" "not_called '^keychain'"
REAL_BACKEND=3 STDIN="$T/in" broker as_main put LIST_SIMPLE_NAME; rc=$?
REAL_BACKEND=3 broker as_main list; rc=$?
check list_cols_simple_row_unchanged all ok_rc "grep -qx 'LIST_SIMPLE_NAME	simple	keychain=yes	sops=no' '$T/stdout'" "[ \"\$(grep -c '	simple	.*env=' '$T/stdout')\" = 0 ]"
REAL_BACKEND=3 broker as_main rm LIST_SIMPLE_NAME; rc=$?
default_table

# === 經由 agent-secret2 這個 symlink 名稱執行，行為與原名相同 ===
/bin/ln -s "$BROKER" "$T/bin/agent-secret2"
"$BROKER" > "$T/usage-direct.out" 2> "$T/usage-direct.err"; rc_direct=$?
"$T/bin/agent-secret2" > "$T/stdout" 2> "$T/stderr"; rc=$?
check symlink_name_usage all bad_rc "[ '$rc' = '$rc_direct' ]" "grep -q '^usage: agent-secret run' '$T/stderr'" "! grep -q 'privileged' '$T/stderr'" "cmp -s '$T/usage-direct.err' '$T/stderr'" "[ ! -s '$T/stdout' ]"
"$T/bin/agent-secret2" run 'not a valid name' -- /bin/ls > "$T/stdout" 2> "$T/stderr"; rc=$?
check symlink_name_validates_names all bad_rc "grep -q '名稱不合法' '$T/stderr'" "! grep -q 'privileged' '$T/stderr'"
BASH_ENV="$T/benv" "$T/bin/agent-secret2" > /dev/null 2>&1
check symlink_name_bash_env_not_sourced all "absent '$T/benv-marker'"
/bin/bash "$T/bin/agent-secret2" > "$T/stdout" 2> "$T/stderr"; rc=$?
check symlink_name_direct_bash_refused all bad_rc "grep -q 'privileged' '$T/stderr'"

# === doctor：keychain-only 加 * 沒有任何讀取限制（2026-10-05 實測 keychain-only 不會跳確認視窗）===
write_table \
  "kc-star|keychain-only|KC_STAR_TOKEN|*" \
  "kc-listed|keychain-only|KC_LISTED_TOKEN|$HELPER" \
  "sops-star|sops|SOPS_STAR_TOKEN|*" \
  "sops-listed|sops|SOPS_LISTED_TOKEN|$HELPER"
KC=found SP=notfound broker as_main doctor; rc=$?
check doctor_keychain_only_star_warns all "grep -q '^WARN keychain-only 且 allowed_commands 是 \\*：沒有任何讀取限制.*production 項目請列出明確的絕對路徑: kc-star$' '$T/stdout'" "grep -q '不會跳確認視窗' '$T/stdout'"
check doctor_keychain_only_star_not_a_problem all ok_rc "! grep -q '^PROBLEM' '$T/stdout'" "grep -qx ok '$T/stdout'"
check doctor_keychain_only_star_single_line all "[ \"\$(grep -c 'kc-star' '$T/stdout')\" = 1 ]"
check doctor_sops_star_stays_info all "grep -q '^INFO allowed_commands 是 \\*：沒有指令限制.*: sops-star$' '$T/stdout'" "! grep -q '^WARN.*sops-star' '$T/stdout'"
check doctor_listed_paths_no_hint all "! grep -q 'kc-listed' '$T/stdout'" "! grep -q 'sops-listed' '$T/stdout'"
check doctor_no_confirmation_claim all "! grep -q '視窗同意\\|永遠允許\\|在場' '$T/stdout' '$T/stderr'"
"$BROKER" > /dev/null 2> "$T/stderr"
check usage_states_no_confirmation all "grep -q '不會跳確認視窗' '$T/stderr'" "! grep -q '視窗同意\\|永遠允許\\|在場' '$T/stderr'"
default_table

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
