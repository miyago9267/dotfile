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
EF="$FAKE_HOME/.config/agent-secret/secrets.env"
fail=0; n=0
REAL_OS=$(/usr/bin/uname -s 2>/dev/null || /bin/uname -s)
REAL_UID=$(/usr/bin/id -u)
WIN_UNAME=MINGW64_NT-10.0-26200   # 模擬 Git for Windows 的 bash；本機儲存區是 Credential Manager
case "$REAL_OS" in MINGW*|MSYS*) WIN=1 ;; *) WIN=0 ;; esac
if [ $WIN = 1 ]; then
  # Git Bash 的 chmod 改不了 group/other 位元，stat 的 mode 是合成的。權限類的 case 改成記下 chmod 要求的
  # mode，再以覆寫的 as_stat 回報；as_perm_problem 之後的判斷照跑。
  MODES="$T/modes"; mkdir "$MODES"
  chmod() {
    command chmod "$@" 2>/dev/null
    local m=$1 f; shift
    for f in "$@"; do printf '%s' "$m" > "$MODES/$(printf '%s' "$f" | tr '/' '_')"; done
  }
  cat > "$T/winstat.sh" <<EOF
as_stat() {
  local k; k=\$(builtin printf '%s' "\$1" | /usr/bin/tr '/' '_')
  if [[ -f "$MODES/\$k" ]]; then builtin printf '%s %s\n' "\$EUID" "\$(/usr/bin/cat "$MODES/\$k")"
  else /usr/bin/stat -L -c '%u %a' -- "\$1" 2>/dev/null; fi
}
EOF
fi

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
# REAL_HOME=1 不覆寫 as_home。UNAME 是 Windows 的值時走 Credential Manager 那一側：
# REAL_BACKEND=0 stub backend_wincred（KC 同樣決定行為，names 印 WC_LIST）；REAL_BACKEND=1 stub 最底層的
# _wincred（印 WC_OUT，以 printf %b 解讀跳脫，回傳 WC_RC）；REAL_BACKEND=3 以檔案模擬不分大小寫的 target。
# FAKE_PS 指到一個檔案時，as_ps_bin 回傳它（測真正的 _wincred 啟動流程，不啟動 PowerShell）。
# stdout 存 $T/stdout、stderr 存 $T/stderr，回傳 exit code。
broker() {
  : > "$CALLS"; rm -f "$OUT" "$ARGV" "$T/wincred-stdin"
  (
    set -p
    # Windows 的 chmod 包裝只給測試本身用；chmod 在 broker 的遮蔽檢查清單內，source 前先拿掉
    [ $WIN = 1 ] && unset -f chmod
    # shellcheck disable=SC1090
    source "$BROKER" || exit 97
    # shellcheck disable=SC1091
    [ $WIN = 1 ] && source "$T/winstat.sh"
    [ "${REAL_HOME:-0}" = 1 ] || as_home() { builtin printf '%s' "$FAKE_HOME"; }
    uname() { echo "${UNAME:-Darwin}"; }   # 預設模擬 macOS，測試在 Linux 上也跑同一組 case
    [ "${FAKE_PS:-}" ] && as_ps_bin() { builtin printf '%s' "$FAKE_PS"; }
    if [ "${REAL_BACKEND:-0}" = 0 ]; then
      backend_wincred() {
        echo "wincred $*" >> "$CALLS"
        case "$1" in
          put) echo "wincred-stdin $(cat)" >> "$T/putlog"; [ "${KC:-found}" = error ] && return 1; return 0 ;;
          names)
            [ "${KC:-found}" = error ] && return 1
            if [ "${2:-}" = all ]; then printf '%s' "${WC_LIST:-}"; else printf '%s' "${WC_LIST:-}" | sed -n 's/^simple\///p'; fi
            return 0 ;;
        esac
        case "${KC:-found}" in
          found) [ "$1" = get ] && AS_VALUE=$KC_VAL; return 0 ;;
          empty) AS_VALUE=""; return 0 ;;
          notfound) return 3 ;;
          *) return 1 ;;
        esac
      }
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
      _sops() { echo "sops-bin $*" >> "$CALLS"; printf '%s|%s\n' "${SOPS_EDITOR-unset}" "${EDITOR-unset}" > "$T/sopsenv"; [ "${SOPS_OUT:-}" ] && printf '%s' "$SOPS_OUT"; return "${SOPS_RC:-0}"; }
      _wincred(){ echo "wincred-ps $*" >> "$CALLS"; cat > "$T/wincred-stdin" 2>/dev/null; printf '%b' "${WC_OUT:-}"; return "${WC_RC:-0}"; }
    fi
    if [ "${REAL_BACKEND:-0}" = 3 ]; then
      # 以檔案模擬 Credential Manager：target 不分大小寫（檔名轉小寫），.name 記下建立時的寫法；
      # 讀到的名稱與要求的寫法不同就回錯誤，names 只列寫法合法的項目（與 broker 內的 C# 相同）。
      _wincred() {
        echo "wincred-ps $*" >> "$CALLS"
        local op=$1 t=${2:-} f v
        f="$T/wcstore/$(printf '%s' "$t" | tr 'A-Z/' 'a-z_')"
        case "$op" in
          names)
            [ "${DUMP_RC:-0}" = 0 ] || return "$DUMP_RC"
            for f in "$T/wcstore"/*.name; do
              [ -f "$f" ] && sed -n 's/^agent-secret\///p' "$f" | grep -E '^(simple/[A-Z][A-Z0-9_]*|alias/[a-z0-9][a-z0-9-]*)$'
            done
            printf 'AS-WINCRED-END\n'; return 0 ;;
          put)
            v=$(cat)
            if [ -f "$f.name" ] && [ "$(cat "$f.name")" != "$t" ]; then return 1; fi
            printf '%s\n' "$t" > "$f.name"; printf '%s' "$v" > "$f.val"
            printf 'AS-WINCRED-OK\n'; return 0 ;;
        esac
        [ -f "$f.name" ] || { printf 'AS-WINCRED-NOT-FOUND\n'; return 3; }
        [ "$(cat "$f.name")" = "$t" ] || return 1
        case "$op" in
          get) cat "$f.val"; return 0 ;;
          exists) printf 'AS-WINCRED-OK\n'; return 0 ;;
          delete) rm -f "$f.name" "$f.val"; printf 'AS-WINCRED-OK\n'; return 0 ;;
        esac
        return 1
      }
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
absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
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
UNAME=Linux SP=notfound STDIN=/dev/null broker as_main put tok-sops; rc=$?
check linux_put_empty_refused all bad_rc "not_called '^keychain'" "absent '$EF'"

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
check list_ok all ok_rc "grep -q '^tok-sops	sops	keychain=yes	sops=yes	envfile=n/a	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'" "grep -q '^tok-kc	keychain-only	' '$T/stdout'"
check list_no_value no_dummy "$T/stdout" "$T/stderr"
check list_never_reads_value all "not_called ' get '" "not_called ' put '"
UNAME=Linux KC=found SP=notfound broker as_main list; rc=$?
check list_linux all ok_rc "grep -q '^tok-sops	sops	keychain=n/a	sops=no	envfile=no	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'" "not_called '^keychain'"
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
# LOW：這個平台上最底層 stub 在 CALLS 裡留下的前綴（macOS 是 security，Windows 是 PowerShell 啟動函式）
if [ "$REAL_OS" = Darwin ]; then FAKE_OS=Linux; EXP_VAL=$KC_VAL; EXP_BACKEND=keychain; LOW='^security'
elif [ $WIN = 1 ]; then FAKE_OS=Linux; EXP_VAL=$KC_VAL; EXP_BACKEND=wincred; LOW='^wincred-ps'
else FAKE_OS=Darwin; EXP_VAL=$SOPS_VAL; EXP_BACKEND=sops; LOW='^security'; fi
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
_wincred() {
  builtin echo "wincred-ps \$*" >> "$CALLS"
  case \${1:-} in
    get) builtin printf '%s' "$KC_VAL" ;;
    put) /bin/cat > "$T/wincred-stdin"; builtin printf 'AS-WINCRED-OK\n' ;;
    names) builtin printf 'AS-WINCRED-END\n' ;;
    *) builtin printf 'AS-WINCRED-OK\n' ;;
  esac
  return 0
}
$([ $WIN = 1 ] && printf 'source "%s"' "$T/winstat.sh")
as_main "\$@"
EOF
chmod 755 "$ENTRY"
entry() {
  : > "$CALLS"
  /bin/rm -f "$OUT" "$ARGV" "$T/childpath" "$T/childbashenv" "$T/security-stdin" "$T/wincred-stdin"
  "$ENTRY" "$@" > "$T/stdout" 2> "$T/stderr" < "${STDIN:-/dev/null}"
}

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
/bin/rm -f "$EF"

# shellcheck disable=SC1091
( source "$T/benv"; /bin/rm -f "$T/capture" "$T/benv-marker"; export -f export exec printf
  entry run tok-sops -- "$HELPER" MY_TOKEN ); rc=$?
expect_ok exported_functions_run_still_works "$EXP_VAL"
check exported_functions_capture_no_value all "! grep -q DUMMY-NOT-A-SECRET '$T/capture'" "! grep -q '^printf\\|^exec' '$T/capture'"
# shellcheck disable=SC1091
( source "$T/benv"; /bin/rm -f "$T/capture" "$T/benv-marker"; export -f export exec printf
  STDIN="$T/in" entry put tok-sops ); rc=$?
check exported_functions_put_capture_no_value all "! grep -q 'DUMMY-NOT-A-SECRET\\|$PUT_HEX' '$T/capture'"
/bin/rm -f "$EF"
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
# 遮蔽檢查清單是兩側的聯集：envfile 用的 mkdir mktemp chmod mv rm，Credential Manager 用的 iconv base64 cygpath env
for f in mkdir mktemp chmod mv rm iconv base64 cygpath env security sops; do
  # shellcheck disable=SC1090
  # function 關鍵字：呼叫端 shell 若有同名 alias（mv -i 這類），名稱不會被 alias 展開
  # Windows 主機上測試自己的 chmod 包裝要先拿掉，否則清單會先在 chmod 停下
  ( set -p; [ $WIN = 1 ] && unset -f chmod; eval "function $f { :; }"; source "$BROKER" && echo loaded ) > "$T/stdout" 2> "$T/stderr"; rc=$?
  check "shadowed_guard_name_refused_[$f]" all bad_rc "! grep -q loaded '$T/stdout'" "grep -q '$f 被函式遮蔽' '$T/stderr'"
done

# --- PATH 前置假程式 ---
mkdir "$T/fake"
for f in cat od tr awk stat id uname readlink dirname security sops iconv base64 cygpath env; do
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
if [ "$EXP_BACKEND" != sops ]; then expect_ok fake_uname_cannot_change_platform "$KC_VAL"
else expect_deny fake_uname_cannot_change_platform; fi
check fake_path_keychain_only_no_fake_called absent "$T/fakelog"
PATH="$FAKE_PATH" entry run tok-sops -- show-tool MY_TOKEN; rc=$?
expect_deny fake_path_bare_name_not_in_caller_path
PATH="$T/bin:$FAKE_PATH" entry run tok-sops -- show-tool MY_TOKEN; rc=$?
expect_ok fake_path_bare_name_uses_caller_path "$EXP_VAL"
check fake_path_bare_name_no_fake_called absent "$T/fakelog"

chmod 666 "$TABLE"
PATH="$FAKE_PATH" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check fake_stat_id_cannot_pass_bad_perms all bad_rc not_run "absent '$T/fakelog'" "not_called '$LOW'"
chmod 600 "$TABLE"

STDIN="$T/in" PATH="$FAKE_PATH" entry put tok-sops; rc=$?
if [ "$REAL_OS" = Darwin ]; then
  check fake_path_put_ok all ok_rc "grep -qx 'add-generic-password -U -s agent-secret -a tok-sops -X $PUT_HEX' '$T/security-stdin'"
elif [ $WIN = 1 ]; then
  check fake_path_put_ok_windows all ok_rc "[ \"\$(cat '$T/wincred-stdin')\" = '$PUT_VAL' ]" "called '^wincred-ps put agent-secret/alias/tok-sops$'" "no_dummy '$CALLS'"
else
  check fake_path_put_off_macos_writes_envfile all ok_rc "absent '$T/security-stdin'" "grep -qx 'tok-sops=$PUT_VAL' '$EF'"
fi
/bin/rm -f "$EF"
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
check home_env_cannot_swap_table_no_backend not_called "$LOW"
HOME="$T/evilhome" entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok home_env_still_uses_account_home_table "$EXP_VAL"
# 真正的 as_home：HOME 被改掉時仍回帳號資料庫裡的家目錄（用 dscl / getent 當獨立對照）
PS_BIN=/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
if [ "$REAL_OS" = Darwin ]; then
  ORACLE=$(/usr/bin/dscl . -read "/Users/$(/usr/bin/id -un)" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')
elif [ $WIN = 1 ]; then
  # Git Bash 沒有 getent；改問 .NET（SHGetFolderPath），與 broker 用的 cygpath 是不同的實作
  ORACLE=$(cygpath -u "$("$PS_BIN" -NoProfile -NonInteractive -Command "[Environment]::GetFolderPath('UserProfile')" | tr -d '\r')")
else
  ORACLE=$(getent passwd "$REAL_UID" | cut -d: -f6)
fi
printf '%s' "${ORACLE%/}" > "$T/oracle"
# UNAME 用真實的平台：as_home 在 Windows 走另一條路
HOME="$T/evilhome" UNAME="$REAL_OS" REAL_HOME=1 broker as_home; rc=$?
check as_home_ignores_home_env all ok_rc "[ -s '$T/oracle' ]" "cmp -s '$T/oracle' '$T/stdout'"
HOME="$T/evilhome" UNAME="$REAL_OS" REAL_HOME=1 REAL_BACKEND=2 broker eval 'as_paths; builtin printf "%s" "$AS_TABLE"'; rc=$?
printf '%s' "${ORACLE%/}/.config/agent-secret/aliases.tsv" > "$T/oracle"
check table_path_derived_from_account_home all ok_rc "cmp -s '$T/oracle' '$T/stdout'"
if [ $WIN = 1 ]; then
  # 回歸（2026-10-10 實測的漏洞）：bash 由原生行程啟動時，Git for Windows 的 ~name 會跟著呼叫端的 HOME 走
  # （nsswitch.conf 的 db_home: env）。as_home 必須仍然回真正的家目錄；對照組確認 ~name 真的被帶走。
  printf '%s' "${ORACLE%/}" > "$T/oracle"
  cat > "$T/home-probe" <<EOF
#!/bin/bash -p
# shellcheck disable=SC1090
source "$BROKER" || exit 97
as_home > "$T/probe-home"
n=\$(/usr/bin/id -un); builtin eval "h=~\$n"; builtin printf '%s' "\$h" > "$T/probe-tilde"
EOF
  EVIL_W=$(cygpath -w "$T/evilhome")
  cat > "$T/home-probe.ps1" <<EOF
\$env:HOME='$EVIL_W'; \$env:USERPROFILE='$EVIL_W'; \$env:HOMEDRIVE='Z:'; \$env:HOMEPATH='\\evil'
& '$(cygpath -w /usr/bin/bash.exe)' -p '$(cygpath -w "$T/home-probe")'
exit \$LASTEXITCODE
EOF
  /bin/rm -f "$T/probe-home" "$T/probe-tilde"
  "$PS_BIN" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(cygpath -w "$T/home-probe.ps1")" > "$T/stdout" 2> "$T/stderr"; rc=$?
  check control_native_parent_home_hijacks_tilde all ok_rc "[ -s '$T/probe-tilde' ]" "! cmp -s '$T/oracle' '$T/probe-tilde'"
  check as_home_ignores_home_env_from_native_parent all ok_rc "cmp -s '$T/oracle' '$T/probe-home'"
fi

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
check simple_put_off_macos_writes_envfile all ok_rc "not_called '^keychain'" "grep -qx 'MY_SIMPLE=$PUT_VAL' '$EF'"
/bin/rm -f "$EF"
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
check store_list_shows_put all ok_rc "grep -qx 'MY_SIMPLE	simple	keychain=yes	sops=no	envfile=n/a' '$T/stdout'" "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=no	envfile=n/a' '$T/stdout'"
check store_list_only_simple_names all "[ \"\$(grep -c '	simple	' '$T/stdout')\" = 2 ]" "! grep -q 'OTHER_SERVICE_NAME\|TEST_SERVICE_NAME\|LOOKALIKE_SERVICE\|INET_CLASS_NAME\|^PATH\|^AB' '$T/stdout'"
check store_list_keeps_registered_rows all "grep -q '^tok-sops	sops	keychain=no	sops=no	envfile=n/a	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'" "grep -q '^tok-kc	keychain-only	keychain=no	sops=no	envfile=n/a	env=MY_TOKEN	cmds=$HELPER$' '$T/stdout'"
check store_list_no_value all "no_dummy '$T/stdout' '$T/stderr'" "! grep -q '$PUT_HEX' '$T/stdout'"
check store_list_reads_attributes_only all "called '^security dump-keychain$'" "not_called ' -w'" "not_called 'dump-keychain -d'" "not_called 'dump-keychain .*-d'" "not_called '^sops-bin'"
REAL_BACKEND=3 broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok store_run_gets_put_value "$PUT_VAL"
REAL_BACKEND=3 broker as_main doctor; rc=$?
check store_doctor_counts_simple all "grep -q '^INFO 簡易模式 2 個名稱' '$T/stdout'" "grep -q '沒有限制' '$T/stdout'" "no_dummy '$T/stdout'"
REAL_BACKEND=3 broker as_main rm MY_SIMPLE; rc=$?
check store_rm_ok all ok_rc "called '^security delete-generic-password -s agent-secret -a MY_SIMPLE$'"
REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_after_rm all ok_rc "! grep -q '^MY_SIMPLE' '$T/stdout'" "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=no	envfile=n/a' '$T/stdout'"
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
check store_list_sops_names all ok_rc "grep -qx 'SOPS_ONLY	simple	keychain=no	sops=yes	envfile=n/a' '$T/stdout'" "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=yes	envfile=n/a' '$T/stdout'" "not_called '^sops-bin'"
REAL_BACKEND=3 UNAME=Linux broker as_main list; rc=$?
check store_list_linux all ok_rc "grep -qx 'SOPS_ONLY	simple	keychain=n/a	sops=yes	envfile=no' '$T/stdout'" "not_called '^security'"
REAL_BACKEND=3 broker as_main doctor; rc=$?
check store_doctor_warns_both_backends all "grep -q '^WARN 簡易模式的名稱兩個 backend 都有: SECOND_NAME_2' '$T/stdout'" "grep -q '^INFO 簡易模式 2 個名稱' '$T/stdout'"
REAL_BACKEND=3 STDIN="$T/in" broker as_main put SOPS_ONLY; rc=$?
check store_put_refused_when_in_sops_file all bad_rc "not_called '^security -i'"
DUMP_RC=1 REAL_BACKEND=3 broker as_main list; rc=$?
check store_list_enumeration_error_fails all bad_rc "grep -q '^tok-sops	sops' '$T/stdout'"
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml" "$TABLE"
REAL_BACKEND=3 broker as_main list; rc=$?
check list_without_table_shows_simple all ok_rc "grep -qx 'SECOND_NAME_2	simple	keychain=yes	sops=no	envfile=n/a' '$T/stdout'" "grep -q 'alias 表不存在' '$T/stdout'"
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
  command -v "$c" >/dev/null 2>&1 || continue   # 這台機器沒裝的 shell 跳過（Git Bash 沒有 zsh）
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
elif [ $WIN = 1 ]; then
  check simple_fake_path_put_ok_windows all ok_rc "[ \"\$(cat '$T/wincred-stdin')\" = '$PUT_VAL' ]" "called '^wincred-ps put agent-secret/simple/MY_SIMPLE$'" "no_dummy '$CALLS'"
else
  check simple_fake_path_put_off_macos_writes_envfile all ok_rc "absent '$T/security-stdin'" "grep -qx 'MY_SIMPLE=$PUT_VAL' '$EF'"
fi
/bin/rm -f "$EF"
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
  check "locale_${loc}_lower_underscore_not_simple" all bad_rc not_run "not_called '$LOW'" "grep -q '名稱不合法' '$T/stderr'"
  ( export LC_ALL="$loc" LANG="$loc"; entry run Tok -- "$HELPER" Tok ); rc=$?
  check "locale_${loc}_mixed_case_rejected" all bad_rc not_run "not_called '$LOW'"
  ( export LC_ALL="$loc" LANG="$loc"; entry run tok-sops -- "$HELPER" MY_TOKEN ); rc=$?
  expect_ok "locale_${loc}_registered_alias_ok" "$EXP_VAL"
  ( export LC_ALL="$loc" LANG="$loc"; entry run TOK-SOPS -- "$HELPER" MY_TOKEN ); rc=$?
  check "locale_${loc}_upper_alias_not_registered" all bad_rc not_run "not_called '$LOW'"
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
check list_cols_single_path all ok_rc "grep -qx 'one-path	sops	keychain=yes	sops=no	envfile=n/a	env=ONE_TOKEN	cmds=/opt/homebrew/bin/gh' '$T/stdout'"
check list_cols_multi_path grep -qx "multi-path	keychain-only	keychain=yes	sops=no	envfile=n/a	env=MULTI_TOKEN	cmds=/usr/local/bin/a-tool,/opt/homebrew/bin/b-tool,$HELPER" "$T/stdout"
check list_cols_star grep -qxF 'any-cmd	sops	keychain=yes	sops=no	envfile=n/a	env=ANY_TOKEN	cmds=*' "$T/stdout"
check list_cols_invalid_rows all "grep -qx 'bad-env	sops	INVALID' '$T/stdout'" "grep -qx 'bad-fields	sops	INVALID' '$T/stdout'" "grep -qx 'UPPER_ROW	sops	INVALID' '$T/stdout'"
check list_cols_invalid_rows_no_metadata all "! grep -q 'env=PATH' '$T/stdout'" "! grep -q 'env=UPPER_ROW' '$T/stdout'"
check list_cols_field_count all "[ \"\$(grep -c '	env=' '$T/stdout')\" = 3 ]" "[ \"\$(awk -F'\t' '/^(one-path|multi-path|any-cmd)\t/ && NF != 7' '$T/stdout' | wc -l | tr -d ' ')\" = 0 ]"
check list_cols_no_value all "no_dummy '$T/stdout' '$T/stderr'" "not_called ' get '"
UNAME=Linux KC=found SP=found broker as_main list; rc=$?
check list_cols_linux all ok_rc "grep -qxF 'any-cmd	sops	keychain=n/a	sops=yes	envfile=no	env=ANY_TOKEN	cmds=*' '$T/stdout'" "not_called '^keychain'"
REAL_BACKEND=3 STDIN="$T/in" broker as_main put LIST_SIMPLE_NAME; rc=$?
REAL_BACKEND=3 broker as_main list; rc=$?
check list_cols_simple_row_unchanged all ok_rc "grep -qx 'LIST_SIMPLE_NAME	simple	keychain=yes	sops=no	envfile=n/a' '$T/stdout'" "[ \"\$(grep -c '	simple	.*env=' '$T/stdout')\" = 0 ]"
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

# === edit：sops 的 --config 與 editor 解析（broker 把 PATH 換成系統目錄，editor 要用呼叫端 PATH 找）===
mkdir -p "$FAKE_HOME/.age" "$T/edbin"
: > "$FAKE_HOME/.age/key.txt"; : > "$FAKE_HOME/dotfile/secrets/.sops.yaml"
printf '#!/bin/sh\n' > "$T/edbin/as-fake-editor"; chmod 755 "$T/edbin/as-fake-editor"
rm -f "$T/sopsenv"
( unset EDITOR SOPS_EDITOR; cd /; REAL_BACKEND=1 broker as_main edit ); rc=$?
check edit_passes_sops_config all ok_rc "called '^sops-bin --config $FAKE_HOME/dotfile/secrets/.sops.yaml $FAKE_HOME/dotfile/secrets/agent.enc.yaml\$'"
check edit_unset_editor_stays_unset all "grep -qx 'unset|unset' '$T/sopsenv'"
rm -f "$T/sopsenv"
( unset SOPS_EDITOR; EDITOR='' REAL_BACKEND=1 broker as_main edit ); rc=$?
check edit_empty_editor_left_alone all ok_rc "grep -qx 'unset|' '$T/sopsenv'"
rm -f "$T/sopsenv"
( unset SOPS_EDITOR; PATH="$T/edbin:$PATH" EDITOR='as-fake-editor -f' REAL_BACKEND=1 broker as_main edit ); rc=$?
check edit_editor_resolved_from_caller_path all ok_rc "grep -qx 'unset|$T/edbin/as-fake-editor -f' '$T/sopsenv'"
rm -f "$T/sopsenv"
( PATH="$T/edbin:$PATH" SOPS_EDITOR=as-fake-editor EDITOR=/usr/bin/vi REAL_BACKEND=1 broker as_main edit ); rc=$?
check edit_sops_editor_resolved_abs_kept all ok_rc "grep -qx '$T/edbin/as-fake-editor|/usr/bin/vi' '$T/sopsenv'"
rm -f "$T/sopsenv"
( unset SOPS_EDITOR; EDITOR=as-no-such-editor-xyz REAL_BACKEND=1 broker as_main edit ); rc=$?
check edit_unresolvable_editor_dies all bad_rc "grep -q 'as-no-such-editor-xyz' '$T/stderr'" "not_called '^sops-bin'" "absent '$T/sopsenv'"
( EDITOR=/usr/bin/vi SOPS_EDITOR=as-no-such-editor-xyz REAL_BACKEND=1 broker as_main edit ); rc=$?
check edit_unresolvable_sops_editor_dies all bad_rc "grep -q 'SOPS_EDITOR' '$T/stderr'" "not_called '^sops-bin'"
rm -f "$FAKE_HOME/.age/key.txt" "$FAKE_HOME/dotfile/secrets/.sops.yaml"; rmdir "$FAKE_HOME/.age"
# === Windows：Git for Windows 的 bash（uname 為 MINGW* / MSYS*）以 Credential Manager 當本機儲存區 ===
# 平台以 UNAME stub 成 Windows，所以這一段在 macOS 與 Linux 上也跑；標明「真實 Windows」的區塊才需要 cygpath。
W=$WIN_UNAME
TAB=$'\t'
NF='AS-WINCRED-NOT-FOUND\n'; WOK='AS-WINCRED-OK\n'; WEND='AS-WINCRED-END\n'   # 交給 printf %b
file_is() { [ "$(cat "$1")" = "$2" ]; }   # $(…) 只去掉結尾的 LF：多出來的 CR 看得到（Git Bash 的 grep 會吃掉 CR）
count_is() { [ "$(grep -c -- "$1" "$CALLS")" = "$2" ]; }
stdout_has() { grep -q -- "$1" "$T/stdout"; }
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"

# --- 解析順序與 fail closed：與 Keychain 那一側相同 ---
UNAME=$W KC=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_store_hit "$KC_VAL"
check win_store_hit_backend all "called '^wincred get tok-sops$'" "not_called '^keychain'" "not_called '^sops get'" "stderr_has 'alias=tok-sops backend=wincred'"
check win_store_hit_no_value_in_logs no_dummy "$T/stderr" "$T/stdout" "$ARGV" "$CALLS"
UNAME=MSYS_NT-10.0-26200 KC=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_msys_uname_uses_wincred "$KC_VAL"
check win_msys_uname_backend all "called '^wincred get tok-sops$'" "stderr_has 'backend=wincred'"
KC=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check mac_still_uses_keychain all ok_rc "called '^keychain get tok-sops$'" "not_called '^wincred'" "stderr_has 'backend=keychain'"
UNAME=Linux KC=found SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check linux_never_calls_wincred all ok_rc "not_called '^wincred'" "not_called '^keychain'"
UNAME=$W KC=notfound SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_notfound_falls_to_sops "$SOPS_VAL"
check win_notfound_falls_logs_backend stderr_has 'alias=tok-sops backend=sops'
UNAME=$W KC=error SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny win_store_error_no_fallthrough
check win_store_error_no_sops_call all "not_called '^sops'" "stderr_has 'Credential Manager 讀取失敗'"
UNAME=$W KC=notfound SP=notfound broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny win_missing_everywhere
UNAME=$W KC=empty broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_deny win_empty_value
# keychain-only：名稱沿用，在 Windows 表示只存在這台機器的 Credential Manager
UNAME=$W KC=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_keychain_only_hit "$KC_VAL"
UNAME=$W KC=notfound SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny win_keychain_only_never_sops
check win_keychain_only_never_sops_call not_called '^sops'
UNAME=$W KC=error SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny win_keychain_only_error
check win_keychain_only_error_no_sops not_called '^sops'
# 簡易模式
UNAME=$W KC=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok win_simple_hit "$KC_VAL"
check win_simple_logs_mode stderr_has 'name=MY_SIMPLE backend=wincred mode=simple'
UNAME=$W KC=notfound SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok win_simple_notfound_falls_to_sops "$SOPS_VAL"
UNAME=$W KC=error SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny win_simple_error_no_fallthrough
check win_simple_error_no_sops_call not_called '^sops'
# 指令限制照舊
UNAME=$W broker as_main run tok-sops -- "$T/bin/other-tool" MY_TOKEN; rc=$?
expect_deny win_command_mismatch
check win_command_mismatch_no_backend all "not_called '^wincred'" "not_called '^sops'"

# --- 注入的變數不被 MSYS 改寫：2026-10-10 實測 /abc/def 這種值交給原生程式時會變成 C:/Program Files/Git/abc/def ---
( unset MSYS2_ENV_CONV_EXCL; UNAME=$W broker as_main run tok-star -- sh -c 'printf %s "${MSYS2_ENV_CONV_EXCL-unset}"' ); rc=$?
check win_run_excludes_env_from_msys_conversion all ok_rc "stdout_is 'MY_TOKEN'"
UNAME=$W MSYS2_ENV_CONV_EXCL='FOO;BAR' broker as_main run MY_SIMPLE -- sh -c 'printf %s "$MSYS2_ENV_CONV_EXCL"'; rc=$?
check win_run_keeps_caller_exclusions all ok_rc "stdout_is 'MY_SIMPLE;FOO;BAR'"
( unset MSYS2_ENV_CONV_EXCL; broker as_main run tok-star -- sh -c 'printf %s "${MSYS2_ENV_CONV_EXCL-unset}"' ); rc=$?
check mac_run_does_not_touch_msys_exclusions all ok_rc "stdout_is 'unset'"

# --- put / rm ---
: > "$T/putlog"
UNAME=$W SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?
check win_put_ok all ok_rc "called '^wincred put tok-sops sops$'" "file_is '$T/putlog' 'wincred-stdin $PUT_VAL'" "stderr_has 'backend=wincred'" "not_called '^keychain'"
check win_put_value_not_in_args no_dummy "$CALLS" "$T/stderr" "$T/stdout"
UNAME=$W SP=found STDIN="$T/in" broker as_main put tok-sops; rc=$?
check win_put_refused_when_in_sops all bad_rc "not_called '^wincred put'"
UNAME=$W SP=error STDIN="$T/in" broker as_main put tok-sops; rc=$?
check win_put_refused_when_sops_state_unknown all bad_rc "not_called '^wincred put'"
UNAME=$W SP=notfound KC=error STDIN="$T/in" broker as_main put tok-sops; rc=$?
check win_put_backend_error all bad_rc "stderr_has 'Credential Manager 寫入失敗'"
UNAME=$W SP=notfound STDIN="$T/long" broker as_main put MY_SIMPLE; rc=$?
check win_put_too_long all bad_rc "not_called '^wincred put'"
UNAME=$W SP=notfound STDIN="$T/multi" broker as_main put MY_SIMPLE; rc=$?
check win_put_multiline all bad_rc "not_called '^wincred put'"
# PowerShell 的 pipe 行尾是 CRLF（Get-Clipboard | agent-secret put）。broker 不處理 CR：真實的 Git Bash 上
# bash 的 $(...) 會把結尾的 CRLF 當成換行去掉（實測），所以存得進去而且值是乾淨的；其他平台照舊拒絕。
printf '%s\r\n' "$PUT_VAL" > "$T/in-crlf"; : > "$T/putlog"
UNAME=$W SP=notfound STDIN="$T/in-crlf" broker as_main put MY_SIMPLE; rc=$?
if [ $WIN = 1 ]; then
  check winreal_put_crlf_line_ending_ok all ok_rc "called '^wincred put MY_SIMPLE simple$'" "file_is '$T/putlog' 'wincred-stdin $PUT_VAL'"
else
  check win_put_trailing_cr_rejected_off_git_bash all bad_rc "not_called '^wincred put'"
  SP=notfound STDIN="$T/in-crlf" broker as_main put MY_SIMPLE; rc=$?
  check mac_put_trailing_cr_still_rejected all bad_rc "not_called '^keychain put'"
fi
printf 'DUMMY\rMID\r\n' > "$T/in-crmid"
UNAME=$W SP=notfound STDIN="$T/in-crmid" broker as_main put MY_SIMPLE; rc=$?
check win_put_cr_in_middle_rejected all bad_rc "not_called '^wincred put'"
printf 'DUMMY\r\r\n' > "$T/in-crcr"
UNAME=$W SP=notfound STDIN="$T/in-crcr" broker as_main put MY_SIMPLE; rc=$?
check win_put_two_trailing_cr_rejected all bad_rc "not_called '^wincred put'"
printf '\r\n' > "$T/in-cronly"
UNAME=$W SP=notfound STDIN="$T/in-cronly" broker as_main put MY_SIMPLE; rc=$?
check win_put_only_crlf_is_empty all bad_rc "not_called '^wincred put'"
UNAME=$W broker as_main rm MY_SIMPLE; rc=$?
check win_rm_ok all ok_rc "called '^wincred delete MY_SIMPLE$'" "stderr_has 'removed name=MY_SIMPLE backend=wincred mode=simple'" "not_called '^keychain'"
UNAME=$W KC=notfound broker as_main rm MY_SIMPLE; rc=$?
check win_rm_missing_item_fails all bad_rc "stderr_has 'Credential Manager 沒有這個項目'"
UNAME=$W KC=error broker as_main rm MY_SIMPLE; rc=$?
check win_rm_backend_error_fails all bad_rc "stderr_has 'Credential Manager 刪除失敗'"
UNAME=$W broker as_main rm tok-sops; rc=$?
check win_rm_registered_refused all bad_rc "not_called '^wincred'"

# --- list / doctor：每次執行只列舉一次（names all），不逐列呼叫 exists ---
WC_L=$'alias/tok-sops\nalias/tok-kc\nalias/abcd\nsimple/MY_SIMPLE\nsimple/ABC\n'
UNAME=$W KC=found SP=notfound WC_LIST="$WC_L" broker as_main list; rc=$?
check win_list_rows all ok_rc \
  "stdout_has '^tok-sops${TAB}sops${TAB}wincred=yes${TAB}sops=no${TAB}env=MY_TOKEN${TAB}cmds=$HELPER$'" \
  "stdout_has '^tok-kc${TAB}keychain-only${TAB}wincred=yes${TAB}sops=no${TAB}'" \
  "stdout_has '^tok-star${TAB}sops${TAB}wincred=no${TAB}sops=no${TAB}'" \
  "stdout_has '^MY_SIMPLE${TAB}simple${TAB}wincred=yes${TAB}sops=no$'"
# alias abc：清單裡只有 alias/abcd 與 simple/ABC，前綴或只差大小寫都不算
check win_list_exact_name_match all "stdout_has '^abc${TAB}sops${TAB}wincred=no${TAB}'" "stdout_has '^ABC${TAB}simple${TAB}wincred=yes${TAB}sops=no$'" "! grep -q '^abcd' '$T/stdout'"
check win_list_single_enumeration all "count_is '^wincred names' 1" "called '^wincred names all$'" "not_called '^wincred exists'" "not_called '^wincred get'" "not_called '^keychain'"
check win_list_no_keychain_column all "! grep -q 'keychain=' '$T/stdout'" "no_dummy '$T/stdout' '$T/stderr'"
UNAME=$W KC=error SP=notfound broker as_main list; rc=$?
check win_list_enumeration_error_fails all bad_rc "stdout_has '^tok-sops${TAB}sops${TAB}wincred=error${TAB}'" "stderr_has '無法列舉簡易模式的名稱: wincred'" "count_is '^wincred names' 1"
UNAME=$W KC=found SP=found WC_LIST="$WC_L" broker as_main doctor; rc=$?
check win_doctor_flags_both_backends all bad_rc "stdout_has '兩個 backend 都有: tok-sops（Credential Manager 會蓋過 sops）'" "stdout_has 'keychain-only 的 alias 出現在 sops: tok-kc'"
check win_doctor_single_enumeration all "count_is '^wincred names' 1" "not_called '^wincred exists'" "not_called ' get '" "no_dummy '$T/stdout' '$T/stderr'"
UNAME=$W KC=found SP=notfound WC_LIST="$WC_L" broker as_main doctor; rc=$?
check win_doctor_clean all ok_rc "grep -qx ok '$T/stdout'" "stdout_has '^INFO 簡易模式 2 個名稱'"
check win_doctor_mode_check_note stdout_has '^INFO Windows：.*不是 NTFS ACL'
UNAME=$W KC=error SP=notfound broker as_main doctor; rc=$?
check win_doctor_enumeration_error all bad_rc "stdout_has '^PROBLEM 無法確認 backend 狀態: tok-sops (wincred=error sops=no)'" "stdout_has '^WARN 無法列舉簡易模式的名稱（wincred）'"
KC=found SP=notfound broker as_main doctor; rc=$?
check mac_doctor_has_no_windows_note all ok_rc "! grep -q 'NTFS' '$T/stdout'"
write_table "kc-star|keychain-only|KC_STAR_TOKEN|*"
UNAME=$W KC=found SP=notfound WC_LIST="" broker as_main doctor; rc=$?
check win_doctor_keychain_only_star_warns all ok_rc "stdout_has '^WARN keychain-only 且 allowed_commands 是 \\*：沒有任何讀取限制（Credential Manager 讀取不需要確認.*: kc-star$'" "! grep -q '確認視窗' '$T/stdout'"
default_table
"$BROKER" > /dev/null 2> "$T/stderr"
check usage_mentions_windows_store all "grep -q 'Credential Manager' '$T/stderr'" "grep -q 'wincred=' '$T/stderr'" "grep -q 'agent-secret.ps1' '$T/stderr'"

# --- 真正的 backend_wincred（只 stub 最底層的 _wincred）：target 名稱、兩個訊號才算找不到、輸出再驗一次 ---
UNAME=$W REAL_BACKEND=1 WC_OUT="$KC_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_real_found "$KC_VAL"
check win_real_get_target all "called '^wincred-ps get agent-secret/alias/tok-sops$'" "count_is '^wincred-ps' 1" "not_called '^sops-bin'" "not_called '^security'"
check win_real_get_no_value_in_calls no_dummy "$CALLS" "$T/stderr"
UNAME=$W REAL_BACKEND=1 WC_OUT="$KC_VAL" broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok win_real_simple_found "$KC_VAL"
check win_real_simple_target called '^wincred-ps get agent-secret/simple/MY_SIMPLE$'
# 兩種模式的 target 用前綴分開：Credential Manager 不分大小寫，abc 與 ABC 不能只靠大小寫區分
UNAME=$W REAL_BACKEND=1 WC_OUT="$KC_VAL" broker as_main run abc -- "$HELPER" MY_TOKEN; rc=$?
check win_real_alias_target_prefix all ok_rc "called '^wincred-ps get agent-secret/alias/abc$'"
UNAME=$W REAL_BACKEND=1 WC_OUT="$KC_VAL" broker as_main run ABC -- "$HELPER" ABC; rc=$?
check win_real_simple_target_prefix all ok_rc "called '^wincred-ps get agent-secret/simple/ABC$'"
# 呼叫端的 stdin 原樣留給被注入的指令；PowerShell 那一側拿到的是 /dev/null
UNAME=$W REAL_BACKEND=1 WC_OUT="$KC_VAL" STDIN="$T/in" broker as_main run tok-star -- cat; rc=$?
check win_real_run_preserves_caller_stdin all ok_rc "stdout_is '$PUT_VAL'" "[ ! -s '$T/wincred-stdin' ]"
printf '%s\n' 'tok-sops: ENC[AES256_GCM,data:FAKE,type:str]' 'MY_SIMPLE: ENC[AES256_GCM,data:FAKE,type:str]' 'sops:' '    age: []' \
  > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
UNAME=$W REAL_BACKEND=1 WC_RC=3 WC_OUT="$NF" SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_real_notfound_falls_to_sops "$SOPS_VAL"
check win_real_notfound_sops_argv called "^sops-bin -d --extract \[\"tok-sops\"\] $FAKE_HOME/dotfile/secrets/agent.enc.yaml$"
UNAME=$W REAL_BACKEND=1 WC_RC=3 WC_OUT="$NF" SOPS_OUT="$SOPS_VAL" broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_deny win_real_keychain_only_notfound
check win_real_keychain_only_notfound_no_sops not_called '^sops-bin'
# exit code 3 但 sentinel 不對：不是「找不到」
for o in '' 'AS-WINCRED-NOT-FOUND' 'AS-WINCRED-NOT-FOUND\r\n' 'AS-WINCRED-NOT-FOUND\nX' 'as-wincred-not-found\n' 'AS-WINCRED-OK\n' "$KC_VAL"; do
  UNAME=$W REAL_BACKEND=1 WC_RC=3 WC_OUT="$o" SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
  check "win_real_rc3_bad_sentinel_fail_closed_[$o]" all bad_rc not_run "not_called '^sops-bin'" "stderr_has 'Credential Manager 讀取失敗'"
done
# sentinel 對但 exit code 不是 3（PowerShell 起不來是 126 / 127、當掉、其他錯誤）：一樣不是「找不到」
for code in 0 1 2 4 5 126 127 128 255; do
  UNAME=$W REAL_BACKEND=1 WC_RC=$code WC_OUT="$NF" SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
  check "win_real_rc_${code}_with_sentinel_fail_closed" all bad_rc not_run "not_called '^sops-bin'"
  UNAME=$W REAL_BACKEND=1 WC_RC=$code WC_OUT="$NF" broker eval 'as_paths; backend_wincred get tok-sops; builtin printf "rc=%s" "$?"'; rc=$?
  check "win_real_rc_${code}_with_sentinel_is_error_not_3" stdout_is 'rc=1'
done
for code in 1 2 126 127 255; do
  UNAME=$W REAL_BACKEND=1 WC_RC=$code WC_OUT="$KC_VAL" SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
  check "win_real_rc_${code}_with_value_fail_closed" all bad_rc not_run "not_called '^sops-bin'"
done
# get 的輸出再驗一次：結尾多出 CR 或換行、空的、過長、不可列印都拒絕
head -c 1025 /dev/zero | tr '\0' 'D' > "$T/long1025"; head -c 1024 /dev/zero | tr '\0' 'D' > "$T/long1024"
for o in "$KC_VAL\r" "$KC_VAL\n" "$KC_VAL\r\n" '' '\n' "DUMMY\tTAB" "DUMMY\nLINE2" 'DUMMY\0001X' "$(cat "$T/long1025")"; do
  UNAME=$W REAL_BACKEND=1 WC_RC=0 WC_OUT="$o" SOPS_OUT="$SOPS_VAL" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
  check "win_real_get_output_rejected_[$(printf '%s' "$o" | cut -c1-30)]" all bad_rc not_run "not_called '^sops-bin'"
done
UNAME=$W REAL_BACKEND=1 WC_RC=0 WC_OUT="$(cat "$T/long1024")" broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check win_real_get_max_len_ok all ok_rc "[ \"\$(wc -c < '$OUT' | tr -d ' ')\" = 1024 ]"
UNAME=$W REAL_BACKEND=1 WC_RC=0 WC_OUT='DUMMY $x "q" `b` end' broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_real_get_shell_metachars_intact 'DUMMY $x "q" `b` end'
# exists / delete / put：成功也要 sentinel
for spec in "0|$WOK|0" "3|$NF|3" "0||1" "0|$NF|1" "3|$WOK|1" "3||1" "1|$WOK|1" "127||1" "0|AS-WINCRED-OK|1"; do
  IFS='|' read -r wrc wout want <<< "$spec"
  UNAME=$W REAL_BACKEND=1 WC_RC=$wrc WC_OUT="$wout" broker eval 'as_paths; backend_wincred exists tok-sops; builtin printf "rc=%s" "$?"'; rc=$?
  check "win_real_exists_[$spec]" all "stdout_is 'rc=$want'" "called '^wincred-ps exists agent-secret/alias/tok-sops$'"
  UNAME=$W REAL_BACKEND=1 WC_RC=$wrc WC_OUT="$wout" broker eval 'as_paths; backend_wincred delete MY_SIMPLE; builtin printf "rc=%s" "$?"'; rc=$?
  check "win_real_delete_[$spec]" all "stdout_is 'rc=$want'" "called '^wincred-ps delete agent-secret/simple/MY_SIMPLE$'"
done
for nm in 'My_Simple' 'a b' 'x/y' '' '../x' 'A*'; do
  UNAME=$W REAL_BACKEND=1 WC_OUT="$KC_VAL" broker eval "as_paths; backend_wincred get '$nm'; builtin printf 'rc=%s' \"\$?\""; rc=$?
  check "win_real_bad_name_never_reaches_powershell_[$nm]" all "stdout_is 'rc=1'" "not_called '^wincred-ps'"
done
/bin/rm -f "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
UNAME=$W REAL_BACKEND=1 WC_OUT="$WOK" STDIN="$T/in" broker as_main put tok-kc; rc=$?
check win_real_put_ok all ok_rc "called '^wincred-ps put agent-secret/alias/tok-kc$'" "count_is '^wincred-ps' 1"
check win_real_put_value_only_on_stdin all "file_is '$T/wincred-stdin' '$PUT_VAL'" "[ \"\$(wc -c < '$T/wincred-stdin' | tr -d ' ')\" = ${#PUT_VAL} ]" "no_dummy '$CALLS' '$T/stderr' '$T/stdout'"
UNAME=$W REAL_BACKEND=1 WC_OUT="$WOK" STDIN="$T/in-crlf" broker as_main put MY_SIMPLE; rc=$?
if [ $WIN = 1 ]; then
  check winreal_put_crlf_stores_clean_value all ok_rc "file_is '$T/wincred-stdin' '$PUT_VAL'" "[ \"\$(wc -c < '$T/wincred-stdin' | tr -d ' ')\" = ${#PUT_VAL} ]"
else
  check win_real_put_crlf_rejected_off_git_bash all bad_rc "not_called '^wincred-ps'"
fi
UNAME=$W REAL_BACKEND=1 WC_OUT='' STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check win_real_put_without_ok_sentinel_fails bad_rc
UNAME=$W REAL_BACKEND=1 WC_RC=1 WC_OUT="$WOK" STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check win_real_put_error_fails bad_rc
UNAME=$W REAL_BACKEND=1 WC_RC=3 WC_OUT="$NF" STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check win_real_put_notfound_is_error bad_rc
UNAME=$W REAL_BACKEND=1 WC_OUT="$WOK" broker as_main rm MY_SIMPLE; rc=$?
check win_real_rm_ok all ok_rc "called '^wincred-ps delete agent-secret/simple/MY_SIMPLE$'"
UNAME=$W REAL_BACKEND=1 WC_RC=3 WC_OUT="$NF" broker as_main rm MY_SIMPLE; rc=$?
check win_real_rm_missing all bad_rc "stderr_has 'Credential Manager 沒有這個項目'"
# names：結尾要有 END sentinel；其他前綴的行當成錯誤
EXP_SIMPLE=$'A_B\nSECOND'; EXP_ALL=$'simple/A_B\nalias/x-y'
UNAME=$W REAL_BACKEND=1 WC_OUT="simple/A_B\nalias/x-y\nsimple/SECOND\n$WEND" broker eval 'as_paths; backend_wincred names'; rc=$?
check win_real_names_simple_only all ok_rc 'stdout_is "$EXP_SIMPLE"' "called '^wincred-ps names$'"
UNAME=$W REAL_BACKEND=1 WC_OUT="simple/A_B\nalias/x-y\n$WEND" broker eval 'as_paths; backend_wincred names all'; rc=$?
check win_real_names_all all ok_rc 'stdout_is "$EXP_ALL"'
UNAME=$W REAL_BACKEND=1 WC_OUT="$WEND" broker eval 'as_paths; backend_wincred names all'; rc=$?
check win_real_names_empty all ok_rc "[ ! -s '$T/stdout' ]"
for o in '' 'simple/A_B\n' 'simple/A_B\nAS-WINCRED-END' "weird/A_B\n$WEND" "simple/A_B$WEND"; do
  UNAME=$W REAL_BACKEND=1 WC_OUT="$o" broker eval 'as_paths; backend_wincred names all >/dev/null; builtin printf "rc=%s" "$?"'; rc=$?
  check "win_real_names_bad_output_is_error_[$o]" stdout_is 'rc=1'
done
UNAME=$W REAL_BACKEND=1 WC_RC=1 WC_OUT="$WEND" broker eval 'as_paths; backend_wincred names all; builtin printf "rc=%s" "$?"'; rc=$?
check win_real_names_error_rc stdout_is 'rc=1'
UNAME=$W REAL_BACKEND=1 WC_OUT="alias/tok-sops\nsimple/MY_SIMPLE\n$WEND" broker as_main list; rc=$?
check win_real_list all ok_rc "stdout_has '^tok-sops${TAB}sops${TAB}wincred=yes${TAB}sops=no${TAB}'" "stdout_has '^tok-kc${TAB}keychain-only${TAB}wincred=no${TAB}'" "stdout_has '^MY_SIMPLE${TAB}simple${TAB}wincred=yes${TAB}sops=no$'"
check win_real_list_single_powershell_call all "count_is '^wincred-ps' 1" "called '^wincred-ps names$'" "not_called '^security'" "not_called '^sops-bin'"

# --- 以檔案模擬的 Credential Manager（target 不分大小寫）：put、list、run、rm 一輪，以及只差大小寫的名稱 ---
/bin/rm -rf "$T/wcstore"; mkdir "$T/wcstore"
printf '%s\n' 'DUMMY-NOT-A-SECRET-UPPER' > "$T/in-upper"; printf '%s\n' 'DUMMY-NOT-A-SECRET-LOWER' > "$T/in-lower"
UNAME=$W REAL_BACKEND=3 broker as_main list; rc=$?
check win_store_list_empty all ok_rc "! grep -q '${TAB}simple${TAB}' '$T/stdout'" "stdout_has '^abc${TAB}sops${TAB}wincred=no${TAB}'"
UNAME=$W REAL_BACKEND=3 STDIN="$T/in-upper" broker as_main put ABC; rc=$?
check win_store_put_simple_ok all ok_rc "called '^wincred-ps put agent-secret/simple/ABC$'"
UNAME=$W REAL_BACKEND=3 STDIN="$T/in-lower" broker as_main put abc; rc=$?
check win_store_put_alias_same_letters_ok all ok_rc "called '^wincred-ps put agent-secret/alias/abc$'"
UNAME=$W REAL_BACKEND=3 broker as_main run ABC -- "$HELPER" ABC; rc=$?
expect_ok win_store_simple_value_not_mixed_with_alias 'DUMMY-NOT-A-SECRET-UPPER'
UNAME=$W REAL_BACKEND=3 broker as_main run abc -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_store_alias_value_not_mixed_with_simple 'DUMMY-NOT-A-SECRET-LOWER'
UNAME=$W REAL_BACKEND=3 broker as_main list; rc=$?
check win_store_list_shows_both all ok_rc "stdout_has '^abc${TAB}sops${TAB}wincred=yes${TAB}sops=no${TAB}'" "stdout_has '^ABC${TAB}simple${TAB}wincred=yes${TAB}sops=no$'" "stdout_has '^tok-sops${TAB}sops${TAB}wincred=no${TAB}'"
check win_store_list_single_powershell_call all "count_is '^wincred-ps' 1" "no_dummy '$T/stdout' '$T/stderr'"
UNAME=$W REAL_BACKEND=3 broker as_main doctor; rc=$?
check win_store_doctor_counts_simple all "stdout_has '^INFO 簡易模式 1 個名稱'" "count_is '^wincred-ps' 1" "no_dummy '$T/stdout'"
UNAME=$W REAL_BACKEND=3 broker as_main rm ABC; rc=$?
check win_store_rm_ok ok_rc
UNAME=$W REAL_BACKEND=3 broker as_main run abc -- "$HELPER" MY_TOKEN; rc=$?
expect_ok win_store_rm_simple_keeps_alias 'DUMMY-NOT-A-SECRET-LOWER'
UNAME=$W REAL_BACKEND=3 broker as_main run ABC -- "$HELPER" ABC; rc=$?
expect_deny win_store_run_after_rm_fails
UNAME=$W REAL_BACKEND=3 broker as_main rm ABC; rc=$?
check win_store_rm_again_fails all bad_rc "stderr_has 'Credential Manager 沒有這個項目'"
# 別的工具建立、只差大小寫的項目（agent-secret/simple/my_simple）：要求 MY_SIMPLE 時是錯誤，不是找不到也不是命中
printf '%s\n' 'agent-secret/simple/my_simple' > "$T/wcstore/agent-secret_simple_my_simple.name"
printf '%s' 'DUMMY-NOT-A-SECRET-ODDCASE' > "$T/wcstore/agent-secret_simple_my_simple.val"
UNAME=$W REAL_BACKEND=3 broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_deny win_store_case_mismatch_is_error
check win_store_case_mismatch_no_fallthrough all "not_called '^sops-bin'" "stderr_has 'Credential Manager 讀取失敗'" "no_dummy '$T/stdout' '$T/stderr'"
UNAME=$W REAL_BACKEND=3 STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check win_store_case_mismatch_put_refused all bad_rc "file_is '$T/wcstore/agent-secret_simple_my_simple.val' 'DUMMY-NOT-A-SECRET-ODDCASE'"
UNAME=$W REAL_BACKEND=3 broker as_main rm MY_SIMPLE; rc=$?
check win_store_case_mismatch_rm_refused all bad_rc "stderr_has 'Credential Manager 刪除失敗'" "[ -f '$T/wcstore/agent-secret_simple_my_simple.val' ]"
UNAME=$W REAL_BACKEND=3 broker as_main list; rc=$?
check win_store_case_mismatch_not_listed all ok_rc "! grep -qi '^my_simple' '$T/stdout'"
DUMP_RC=1 UNAME=$W REAL_BACKEND=3 broker as_main list; rc=$?
check win_store_list_enumeration_error_fails all bad_rc "stdout_has '^abc${TAB}sops${TAB}wincred=error${TAB}'"
/bin/rm -rf "$T/wcstore"

# --- 內建拒絕清單：比對前轉小寫並去掉 .exe；只在 allowed_commands 列出路徑時套用 ---
for f in cmd.exe PowerShell.EXE Python3.exe Bash.EXE mytool.exe; do cp "$HELPER" "$T/bin/$f"; done
write_table "tok-exe|sops|MY_TOKEN|$T/bin/cmd.exe,$T/bin/PowerShell.EXE,$T/bin/Python3.exe,$T/bin/Bash.EXE,$T/bin/mytool.exe" "tok-star|sops|MY_TOKEN|*"
for f in cmd.exe PowerShell.EXE Python3.exe Bash.EXE; do
  broker as_main run tok-exe -- "$T/bin/$f" MY_TOKEN; rc=$?
  check "listed_denies_exe_name_[$f]" all bad_rc not_run "not_called '^keychain'" "stderr_has '內建拒絕清單'"
  UNAME=$W broker as_main run tok-exe -- "$T/bin/$f" MY_TOKEN; rc=$?
  check "win_listed_denies_exe_name_[$f]" all bad_rc not_run "not_called '^wincred'" "stderr_has '內建拒絕清單'"
done
broker as_main run tok-exe -- "$T/bin/mytool.exe" MY_TOKEN; rc=$?
expect_ok listed_plain_exe_name_ok "$KC_VAL"
broker as_main run tok-star -- "$T/bin/cmd.exe" MY_TOKEN; rc=$?
expect_ok star_still_skips_deny_list_for_exe_names "$KC_VAL"
broker eval 'for b in Rscript RSCRIPT.EXE cmd CMD.EXE powershell PowerShell.exe pwsh.exe ENV sh.exe; do as_cmd_denied "$b" || exit 1; done; exit 0'; rc=$?
check deny_list_case_and_exe_suffix ok_rc
broker eval 'for b in gh gh.exe cmder powershell_ise kubectl.EXE exe; do as_cmd_denied "$b" && exit 2; done; exit 0'; rc=$?
check deny_list_does_not_overmatch ok_rc
default_table

if [ $WIN = 1 ]; then
  # === 真實 Windows（Git Bash）才跑：需要 cygpath 與 MSYS 對 .exe 的處理。不啟動 PowerShell、不碰 Credential Manager ===
  RW=$REAL_OS

  # --- 指令解析：gh、gh.exe、C:\...\gh.exe 解析成同一個字串；allowed_commands 要寫 MSYS 路徑加 .exe ---
  cp /usr/bin/printenv.exe "$T/bin/wtool.exe"
  cp "$HELPER" "$T/bin/dual"; cp /usr/bin/printenv.exe "$T/bin/dual.exe"
  write_table "tok-w|sops|MY_TOKEN|$T/bin/wtool.exe" "tok-noext|sops|MY_TOKEN|$T/bin/wtool" "tok-dual|sops|MY_TOKEN|$T/bin/dual.exe"
  for c in "$T/bin/wtool" "$T/bin/wtool.exe" "$(cygpath -w "$T/bin/wtool.exe")" "$(cygpath -w "$T/bin/wtool")" "$(cygpath -m "$T/bin/wtool.exe")"; do
    UNAME=$RW broker as_main run tok-w -- "$c" MY_TOKEN; rc=$?
    check "winreal_exe_resolves_to_listed_path_[$c]" all ok_rc "stdout_is '$KC_VAL'"
  done
  PATH="$T/bin:$PATH" UNAME=$RW broker as_main run tok-w -- wtool MY_TOKEN; rc=$?
  check winreal_bare_name_resolves_to_exe all ok_rc "stdout_is '$KC_VAL'"
  UNAME=$RW broker as_main run tok-noext -- "$T/bin/wtool" MY_TOKEN; rc=$?
  check winreal_allowlist_without_exe_suffix_does_not_match all bad_rc "not_called '^wincred'" "no_dummy '$T/stdout'" "stderr_has '$T/bin/wtool.exe'"
  # 同目錄同時有 dual（腳本）與 dual.exe：清單只列 dual.exe 時，呼叫 dual 不能被當成 dual.exe
  UNAME=$RW broker as_main run tok-dual -- "$T/bin/dual" MY_TOKEN; rc=$?
  check winreal_script_shadowing_exe_not_allowed all bad_rc not_run "not_called '^wincred'"
  UNAME=$RW broker as_main run tok-dual -- "$T/bin/dual.exe" MY_TOKEN; rc=$?
  check winreal_listed_exe_next_to_script_ok all ok_rc "stdout_is '$KC_VAL'"
  default_table

  # --- 真正的 _wincred 啟動流程，PowerShell 換成會記錄環境、argv 與 stdin 的假程式 ---
  FAKEPS="$T/bin/fake-ps"
  cat > "$FAKEPS" <<EOF
#!/bin/bash
/usr/bin/env > "$T/psenv"
printf '%s\n' "\$@" > "$T/psargv"
/usr/bin/cat > "$T/psstdin"
[ -f "$T/psreply" ] && /usr/bin/cat "$T/psreply"
[ -f "$T/psreply-err" ] && /usr/bin/cat "$T/psreply-err" >&2
exit "\$(/usr/bin/cat "$T/psrc" 2>/dev/null || echo 0)"
EOF
  chmod 755 "$FAKEPS"
  ps_reply() { /bin/rm -f "$T/psenv" "$T/psargv" "$T/psstdin" "$T/psreply-err"; printf '%b' "$2" > "$T/psreply"; printf '%s' "$1" > "$T/psrc"; }
  polluted() {   # 呼叫端把會影響 .NET / PowerShell / MSYS 的變數全部弄髒
    COR_ENABLE_PROFILING=1 COR_PROFILER='{EVIL-EVIL}' COR_PROFILER_PATH='C:\evil\p.dll' COMPLUS_Version=evil \
      DOTNET_STARTUP_HOOKS='C:\evil\h.dll' PSModulePath='C:\evil\Modules' SystemRoot='C:\evil' TEMP='C:\evil' TMP='C:\evil' \
      MSYSTEM=EVIL MSYS_NO_PATHCONV=1 MSYS2_ENV_CONV_EXCL='*' AS_WC_OP=evil AS_WC_TARGET=evil "$@"
  }
  ps_reply 0 "$KC_VAL"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" STDIN="$T/in" polluted broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  expect_ok winreal_launcher_get "$KC_VAL"
  check winreal_launcher_env_pollution_does_not_reach_powershell all "[ -s '$T/psenv' ]" "! grep -qi 'evil' '$T/psenv'" \
    "! grep -qi '^COR_\\|^COMPLUS_\\|^DOTNET_\\|^MSYS_NO_PATHCONV\\|^MSYS2_ENV_CONV_EXCL' '$T/psenv'"
  check winreal_launcher_fixed_env all "grep -qi '^PSModulePath=C:\\\\Windows\\\\System32\\\\WindowsPowerShell\\\\v1\\.0\\\\Modules$' '$T/psenv'" \
    "grep -qi '^SystemRoot=C:\\\\Windows$' '$T/psenv'" "grep -qx 'MSYSTEM=MSYS' '$T/psenv'" "grep -qx 'MSYS2_ARG_CONV_EXCL=\\*' '$T/psenv'" \
    "grep -qx 'AS_WC_OP=get' '$T/psenv'" "grep -qx 'AS_WC_TARGET=agent-secret/simple/MY_SIMPLE' '$T/psenv'"
  # env -i 之後只剩 broker 給的變數，加上 bash 與 MSYS runtime 自己補的
  sed 's/=.*//' "$T/psenv" | sort -u > "$T/psenv-names"
  check winreal_launcher_env_allowlist all "[ -z \"\$(grep -vix 'SystemRoot\\|TEMP\\|TMP\\|PATH\\|MSYSTEM\\|PSModulePath\\|MSYS2_ARG_CONV_EXCL\\|AS_WC_OP\\|AS_WC_TARGET\\|WINDIR\\|PWD\\|SHLVL\\|_\\|OLDPWD' '$T/psenv-names')\" ]"
  check winreal_launcher_argv all "grep -qx -- '-NoProfile' '$T/psargv'" "grep -qx -- '-NonInteractive' '$T/psargv'" "grep -qx -- '-EncodedCommand' '$T/psargv'" "no_dummy '$T/psargv' '$T/psenv'"
  tail -n 1 "$T/psargv" | base64 -d 2>/dev/null | iconv -f UTF-16LE -t UTF-8 > "$T/pssrc" 2>/dev/null
  check winreal_launcher_script_is_the_embedded_source all "grep -q 'public static class AsWinCred' '$T/pssrc'" "grep -q 'GetLastWin32Error' '$T/pssrc'" "grep -q 'StringComparison.Ordinal' '$T/pssrc'"
  check winreal_launcher_get_stdin_is_devnull all "[ -f '$T/psstdin' ]" "[ ! -s '$T/psstdin' ]"
  ps_reply 0 "$KC_VAL"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" STDIN="$T/in" broker as_main run MY_SIMPLE -- cat; rc=$?
  check winreal_launcher_run_preserves_caller_stdin all ok_rc "stdout_is '$PUT_VAL'" "[ ! -s '$T/psstdin' ]"
  ps_reply 0 "$WOK"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" STDIN="$T/in" polluted broker as_main put MY_SIMPLE; rc=$?
  check winreal_launcher_put all ok_rc "file_is '$T/psstdin' '$PUT_VAL'" "[ \"\$(wc -c < '$T/psstdin' | tr -d ' ')\" = ${#PUT_VAL} ]" \
    "grep -qx 'AS_WC_OP=put' '$T/psenv'" "no_dummy '$T/psargv' '$T/psenv' '$T/stderr' '$T/stdout'" "! grep -qi 'evil' '$T/psenv'"
  ps_reply 0 "$WEND"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" STDIN="$T/in" broker as_main list; rc=$?
  check winreal_launcher_list_stdin_is_devnull all ok_rc "grep -qx 'AS_WC_OP=names' '$T/psenv'" "[ ! -s '$T/psstdin' ]"
  # 找不到要兩個訊號：exit code 3 加 stdout 的 sentinel
  ps_reply 3 "$NF"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" broker eval 'as_paths; backend_wincred get MY_SIMPLE; builtin printf "rc=%s" "$?"'; rc=$?
  check winreal_launcher_notfound_two_signals stdout_is 'rc=3'
  ps_reply 3 ''; printf 'AS-WINCRED-NOT-FOUND\n' > "$T/psreply-err"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" broker eval 'as_paths; backend_wincred get MY_SIMPLE; builtin printf "rc=%s" "$?"'; rc=$?
  check winreal_launcher_sentinel_on_stderr_is_error stdout_is 'rc=1'
  ps_reply 0 "$NF"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" broker eval 'as_paths; backend_wincred get MY_SIMPLE; builtin printf "rc=%s" "$?"'; rc=$?
  check winreal_launcher_sentinel_with_rc0_is_error stdout_is 'rc=1'
  ps_reply 0 "$KC_VAL\r"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  expect_deny winreal_launcher_trailing_cr_rejected
  check winreal_launcher_trailing_cr_no_fallthrough stderr_has 'Credential Manager 讀取失敗'
  # PowerShell 起不來：檔案不存在、不是可執行的東西 —— 都是錯誤，不會被當成「找不到」而落到 sops
  printf '%s\n' 'MY_SIMPLE: ENC[AES256_GCM,data:FAKE,type:str]' 'sops:' '    age: []' > "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
  printf 'not a program' > "$T/bin/broken-ps"; chmod 755 "$T/bin/broken-ps"
  for ps in "$T/bin/no-such-powershell.exe" "$T/bin/broken-ps" "$T/bin"; do
    UNAME=$RW REAL_BACKEND=2 FAKE_PS="$ps" broker eval 'as_paths; backend_wincred get MY_SIMPLE; builtin printf "rc=%s" "$?"'; rc=$?
    check "winreal_powershell_cannot_start_is_error_not_3_[${ps##*/}]" stdout_is 'rc=1'
    UNAME=$RW REAL_BACKEND=2 FAKE_PS="$ps" broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
    check "winreal_powershell_cannot_start_fail_closed_[${ps##*/}]" all bad_rc not_run "stderr_has 'Credential Manager 讀取失敗'" "! grep -q 'sops 讀取失敗' '$T/stderr'"
    UNAME=$RW REAL_BACKEND=2 FAKE_PS="$ps" broker as_main list; rc=$?
    check "winreal_powershell_cannot_start_list_fails_[${ps##*/}]" all bad_rc "stderr_has '無法列舉簡易模式的名稱: wincred'"
  done

  # --- 真正的 _sops：scoop 的 sops.exe（假程式）、路徑自己轉成 Windows 寫法、呼叫端的 MSYS 與 SOPS 設定進不去 ---
  mkdir -p "$FAKE_HOME/scoop/shims" "$FAKE_HOME/scoop/apps/sops/current" "$FAKE_HOME/.age"
  mk_fake_sops() {
    cat > "$1" <<EOF
#!/bin/bash
/usr/bin/env > "$T/sopsenv"
printf '%s\n' "\$@" > "$T/sopsargv"
printf '%s' "$2"
EOF
    chmod 755 "$1"
  }
  mk_fake_sops "$FAKE_HOME/scoop/shims/sops.exe" 'DUMMY-NOT-A-SECRET-SHIM'
  ps_reply 3 "$NF"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' MSYS2_ENV_CONV_EXCL='*' \
    SOPS_AGE_KEY=AGE-SECRET-KEY-DUMMY SOPS_AGE_KEY_FILE=/evil/key.txt SOPS_AGE_KEY_CMD=evil-cmd \
    broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  expect_ok winreal_sops_scoop_shim_used 'DUMMY-NOT-A-SECRET-SHIM'
  check winreal_sops_logs_backend stderr_has 'name=MY_SIMPLE backend=sops mode=simple'
  printf '%s\n' '-d' '--extract' '["MY_SIMPLE"]' "$(cygpath -w "$FAKE_HOME/dotfile/secrets/agent.enc.yaml")" > "$T/expect-sopsargv"
  check winreal_sops_argv_windows_path cmp -s "$T/expect-sopsargv" "$T/sopsargv"
  check winreal_sops_env all "grep -qxF 'SOPS_AGE_KEY_FILE=$(cygpath -w "$FAKE_HOME/.age/key.txt")' '$T/sopsenv'" \
    "grep -qxF 'HOME=$(cygpath -w "$FAKE_HOME")' '$T/sopsenv'" "grep -qxF 'USERPROFILE=$(cygpath -w "$FAKE_HOME")' '$T/sopsenv'" \
    "grep -qxF 'APPDATA=$(cygpath -w "$FAKE_HOME")\\AppData\\Roaming' '$T/sopsenv'" \
    "! grep -q '^SOPS_AGE_KEY=\\|^SOPS_AGE_KEY_CMD=\\|^MSYS_NO_PATHCONV=\\|^MSYS2_ARG_CONV_EXCL=\\|^MSYS2_ENV_CONV_EXCL=\\|evil' '$T/sopsenv'"
  mk_fake_sops "$FAKE_HOME/scoop/apps/sops/current/sops.exe" 'DUMMY-NOT-A-SECRET-APP'
  ps_reply 3 "$NF"
  UNAME=$RW REAL_BACKEND=2 FAKE_PS="$FAKEPS" broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  expect_ok winreal_sops_scoop_app_preferred_over_shim 'DUMMY-NOT-A-SECRET-APP'
  # 非 Windows 平台不找家目錄底下的 scoop
  ps_reply 3 "$NF"
  UNAME=Linux REAL_BACKEND=2 broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  check winreal_scoop_sops_not_used_off_windows all bad_rc not_run
  /bin/rm -rf "$FAKE_HOME/scoop" "$FAKE_HOME/dotfile/secrets/agent.enc.yaml"
fi
default_table

# === envfile（非 macOS 的本機來源，Miyago 2026-11-07）===
# backend_envfile 不 stub：直接讀寫暫存家目錄裡的 secrets.env；UNAME 決定平台。
EF_DIR="$FAKE_HOME/.config/agent-secret"
EF_VAL='DUMMY-NOT-A-SECRET-EF'
write_ef() { /bin/rm -f "$EF"; printf '%s\n' "$@" > "$EF"; chmod 600 "$EF"; }
ef_mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
# Git Bash 的 mode 是合成的，broker 自己 chmod 的結果讀不回來：Windows 主機上不比對 mode（權限拒絕的 case 仍以 MODES 照跑）
ef_mode_is() { [ $WIN = 1 ] && return 0; [ "$(ef_mode "$1")" = "$2" ]; }
# Git Bash 的 ln -s 預設複製檔案；建不出真正的 symlink 時，Windows 主機略過 symlink 的 case（其他主機照常失敗）
ef_symlink_ok() { [ -L "$EF" ] || [ $WIN = 0 ]; }
no_tmp() { local f; for f in "$EF_DIR"/.secrets.env.*; do [ -e "$f" ] && return 1; done; return 0; }
write_table "tok-sops|sops|MY_TOKEN|$HELPER" "tok-kc|keychain-only|MY_TOKEN|$HELPER" \
  "tok-multi|sops|MY_TOKEN|$HELPER" "tok-lit|sops|MY_TOKEN|$HELPER" "tok-dup|sops|MY_TOKEN|$HELPER" \
  "tok-empty|sops|MY_TOKEN|$HELPER" "tok-star|sops|MY_TOKEN|*"
write_ef '# comment' '' "tok-sops=$EF_VAL" "MY_SIMPLE=$EF_VAL" "tok-kc=$EF_VAL" "tok-star=$EF_VAL" \
  'tok-lit="DUMMY-NOT-A-SECRET q" $HOME `x` a=b' "tok-dup=$EF_VAL" "tok-dup=$EF_VAL-2" 'tok-empty=' \
  "# tok-multi=$EF_VAL" "export tok-multi=$EF_VAL" " tok-multi=$EF_VAL"

# --- 讀取：Linux 先查 envfile，命中就不查 sops，也不碰 Keychain ---
UNAME=Linux KC=found SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_linux_hit "$EF_VAL"
check ef_linux_hit_no_other_backend all "not_called '^keychain'" "not_called '^sops'"
check ef_linux_hit_logs_backend stderr_has 'alias=tok-sops backend=envfile'
check ef_linux_hit_no_value_leak no_dummy "$T/stderr" "$T/stdout" "$ARGV" "$CALLS"
UNAME=Linux KC=found SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok ef_linux_simple_hit "$EF_VAL"
check ef_linux_simple_logs stderr_has 'name=MY_SIMPLE backend=envfile mode=simple'
UNAME=Linux SP=found broker as_main run tok-lit -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_value_literal_no_expansion '"DUMMY-NOT-A-SECRET q" $HOME `x` a=b'
# 註解、export 前綴、前導空白都不算這個 key：確認找不到才落到 sops
UNAME=Linux SP=found broker as_main run tok-multi -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_miss_falls_to_sops "$SOPS_VAL"
check ef_miss_calls_sops_get called '^sops get tok-multi$'
UNAME=Linux SP=notfound broker as_main run tok-multi -- "$HELPER" MY_TOKEN; rc=$?
expect_deny ef_miss_and_sops_miss
UNAME=Linux SP=error broker as_main run tok-multi -- "$HELPER" MY_TOKEN; rc=$?
expect_deny ef_miss_and_sops_error
UNAME=Linux SP=found broker as_main run tok-dup -- "$HELPER" MY_TOKEN; rc=$?
check ef_duplicate_key_fail_closed all bad_rc not_run "not_called '^sops'" "stderr_has 'key 重複'" "no_dummy '$T/stderr' '$T/stdout'"
UNAME=Linux SP=found broker as_main run tok-empty -- "$HELPER" MY_TOKEN; rc=$?
check ef_empty_value_no_fallthrough all bad_rc not_run "not_called '^sops'"
# envfile 不存在：直接落到 sops
/bin/mv "$EF" "$T/ef.bak"
UNAME=Linux SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_absent_falls_to_sops "$SOPS_VAL"
/bin/mv "$T/ef.bak" "$EF"

# --- keychain-only 在 Linux 仍 fail closed，envfile 有值也不讀 ---
UNAME=Linux KC=found SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
check ef_keychain_only_linux_fail_closed all bad_rc not_run "not_called '^keychain'" "not_called '^sops'" "no_dummy '$T/stderr' '$T/stdout'"

# --- allowed_commands 與 backend 無關 ---
UNAME=Linux broker as_main run tok-sops -- "$T/bin/other-tool" MY_TOKEN; rc=$?
expect_deny ef_allowlist_mismatch
for c in sh /usr/bin/env "$T/bin/innocent-name"; do
  UNAME=Linux broker as_main run tok-sops -- "$c" -c 'printf %s "$MY_TOKEN"'; rc=$?
  check "ef_listed_denies_${c##*/}" all bad_rc not_run "no_dummy '$T/stdout' '$T/stderr'"
done
UNAME=Linux broker as_main run tok-star -- sh -c 'printf %s "$MY_TOKEN"'; rc=$?
check ef_star_unrestricted_same_as_other_backends all ok_rc "stdout_is '$EF_VAL'"

# --- 不可信的 envfile：一律 fail closed，不落到 sops，錯誤訊息不含值 ---
ef_deny() { # <case> <stderr 片段>
  UNAME=Linux SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
  check "$1" all bad_rc not_run "not_called '^sops'" "stderr_has '$2'" "no_dummy '$T/stderr' '$T/stdout'"
  UNAME=Linux SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
  check "$1_simple" all bad_rc not_run "not_called '^sops'" "no_dummy '$T/stderr' '$T/stdout'"
}
for m in 644 640 604 400 700 660 666; do chmod "$m" "$EF"; ef_deny "ef_mode_${m}_denied" 'mode'; done
chmod 600 "$EF"
/bin/mv "$EF" "$T/ef-target"; ln -s "$T/ef-target" "$EF"
ef_symlink_ok && ef_deny ef_symlink_denied 'symlink'
/bin/rm -f "$EF"; /bin/mv "$T/ef-target" "$EF"
chmod 770 "$EF_DIR"; ef_deny ef_dir_group_writable_denied '所在目錄'
chmod 702 "$EF_DIR"; ef_deny ef_dir_other_writable_denied '所在目錄'
chmod 700 "$EF_DIR"
UNAME=Linux SP=found broker eval 'as_stat() { if [[ $1 == *secrets.env ]]; then echo "0 600"; else echo "$EUID 700"; fi; }; as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE'; rc=$?
check ef_wrong_owner_denied all bad_rc not_run "not_called '^sops'" "stderr_has '擁有者'" "no_dummy '$T/stderr' '$T/stdout'"
/bin/mv "$EF" "$T/ef.bak"; mkdir "$EF"
ef_deny ef_directory_denied '一般檔案'
rmdir "$EF"; /bin/mv "$T/ef.bak" "$EF"
UNAME=Linux SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_ok_after_restore "$EF_VAL"

# --- macOS 永遠不碰 envfile：壞掉的 envfile 不影響，有值也不用 ---
KC=notfound SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_macos_ignores_envfile_value "$SOPS_VAL"
chmod 666 "$EF"
KC=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_macos_ignores_bad_envfile "$KC_VAL"
KC=found SP=notfound broker as_main list; rc=$?
check ef_macos_list_na all ok_rc "grep -qx 'tok-sops	sops	keychain=yes	sops=no	envfile=n/a	env=MY_TOKEN	cmds=$HELPER' '$T/stdout'"
cp -p "$EF" "$T/ef-before"
SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?
check ef_macos_put_uses_keychain all ok_rc "called '^keychain put tok-sops sops$'" "cmp -s '$EF' '$T/ef-before'" "ef_mode_is '$EF' 666"
chmod 600 "$EF"

# --- Windows 永遠不碰 envfile：本機儲存區是 Credential Manager，壞掉的 envfile 不影響，有值也不用 ---
UNAME=$W KC=found SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_windows_uses_wincred "$KC_VAL"
check ef_windows_logs_backend all "called '^wincred get tok-sops$'" "stderr_has 'alias=tok-sops backend=wincred'" "not_called '^sops'"
UNAME=$W KC=notfound SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_windows_ignores_envfile_value "$SOPS_VAL"
UNAME=$W KC=notfound SP=found broker as_main run MY_SIMPLE -- "$HELPER" MY_SIMPLE; rc=$?
expect_ok ef_windows_simple_ignores_envfile "$SOPS_VAL"
UNAME=$W KC=error SP=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
check ef_windows_wincred_error_no_envfile_no_sops all bad_rc not_run "not_called '^sops'" "! grep -q envfile '$T/stderr'"
UNAME=$W KC=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_windows_keychain_only_uses_wincred "$KC_VAL"
UNAME=$W KC=notfound SP=found broker as_main run tok-kc -- "$HELPER" MY_TOKEN; rc=$?
check ef_windows_keychain_only_miss_fail_closed all bad_rc not_run "not_called '^sops'"
chmod 666 "$EF"
UNAME=$W KC=found broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_windows_ignores_bad_envfile "$KC_VAL"
UNAME=$W KC=found SP=notfound WC_LIST='alias/tok-sops
simple/MY_SIMPLE
' broker as_main list; rc=$?
check ef_windows_list_no_envfile_column all ok_rc "grep -qx 'tok-sops	sops	wincred=yes	sops=no	env=MY_TOKEN	cmds=$HELPER' '$T/stdout'" \
  "grep -qx 'MY_SIMPLE	simple	wincred=yes	sops=no' '$T/stdout'" "! grep -q 'envfile' '$T/stdout'" "! grep -q 'envfile' '$T/stderr'"
cp -p "$EF" "$T/ef-before"
UNAME=$W SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?
check ef_windows_put_uses_wincred all ok_rc "called '^wincred put tok-sops sops$'" "stderr_has 'backend=wincred'" "cmp -s '$EF' '$T/ef-before'" no_tmp "no_dummy '$T/stderr' '$T/stdout'"
UNAME=$W SP=notfound STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check ef_windows_put_simple_uses_wincred all ok_rc "called '^wincred put MY_SIMPLE simple$'" "cmp -s '$EF' '$T/ef-before'" no_tmp
UNAME=$W KC=found broker as_main rm MY_SIMPLE; rc=$?
check ef_windows_rm_uses_wincred all ok_rc "called '^wincred delete MY_SIMPLE$'" "cmp -s '$EF' '$T/ef-before'"
chmod 600 "$EF"
# 真正的入口（不 stub uname）：macOS 走 Keychain，Windows 走 Credential Manager，其他平台走 envfile
entry run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
if [ "$REAL_OS" = Darwin ]; then expect_ok ef_entry_real_os "$KC_VAL"
elif [ $WIN = 1 ]; then
  expect_ok ef_entry_real_os "$KC_VAL"
  check ef_entry_real_os_windows_backend all "called '^wincred-ps get'" "stderr_has 'backend=wincred'" "not_called '^sops-bin'"
else expect_ok ef_entry_real_os "$EF_VAL"; fi

# --- list（Linux）：只列 key 名稱，不讀值 ---
UNAME=Linux SP=notfound broker as_main list; rc=$?
check ef_list_registered all ok_rc "grep -qx 'tok-sops	sops	keychain=n/a	sops=no	envfile=yes	env=MY_TOKEN	cmds=$HELPER' '$T/stdout'" "grep -qx 'tok-multi	sops	keychain=n/a	sops=no	envfile=no	env=MY_TOKEN	cmds=$HELPER' '$T/stdout'"
check ef_list_simple all "grep -qx 'MY_SIMPLE	simple	keychain=n/a	sops=no	envfile=yes' '$T/stdout'" "[ \"\$(grep -c '	simple	' '$T/stdout')\" = 1 ]"
check ef_list_no_value all "no_dummy '$T/stdout' '$T/stderr'" "not_called ' get '" "not_called '^keychain'"
chmod 644 "$EF"
UNAME=Linux SP=notfound broker as_main list; rc=$?
check ef_list_bad_perms_fails all bad_rc "grep -q 'envfile' '$T/stderr'" "no_dummy '$T/stdout' '$T/stderr'"
chmod 600 "$EF"

# --- put（Linux）：umask 077、目錄 700、檔案 600，取代既有 key ---
/bin/rm -rf "$EF_DIR"
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?
check ef_put_creates all ok_rc "[ -f '$EF' ]" "[ ! -L '$EF' ]" "ef_mode_is '$EF' 600" "ef_mode_is '$EF_DIR' 700" "grep -qx 'MY_SIMPLE=$PUT_VAL' '$EF'" no_tmp
check ef_put_no_keychain_no_leak all "not_called '^keychain'" "no_dummy '$T/stderr' '$T/stdout' '$CALLS'" "stderr_has 'backend=envfile'"
write_table "tok-sops|sops|MY_TOKEN|$HELPER" "tok-kc|keychain-only|MY_TOKEN|$HELPER"
write_ef '# keep me' 'OTHER_NAME=DUMMY-NOT-A-SECRET-OTHER' 'tok-sops=DUMMY-NOT-A-SECRET-OLD' 'tok-sops=DUMMY-NOT-A-SECRET-OLD2' 'tok-sops-x=keep'
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?
printf '%s\n' '# keep me' 'OTHER_NAME=DUMMY-NOT-A-SECRET-OTHER' 'tok-sops-x=keep' "tok-sops=$PUT_VAL" > "$T/ef-expect"
check ef_put_replaces all ok_rc "cmp -s '$EF' '$T/ef-expect'" "ef_mode_is '$EF' 600" no_tmp
UNAME=Linux broker as_main run tok-sops -- "$HELPER" MY_TOKEN; rc=$?
expect_ok ef_put_then_run "$PUT_VAL"
cp -p "$EF" "$T/ef-before"
ef_put_deny() { # <case> [env...]：put 被拒且 envfile 原封不動、沒有暫存檔、值沒外洩
  check "$1" all bad_rc "cmp -s '$EF' '$T/ef-before'" no_tmp "not_called '^keychain'" "no_dummy '$T/stderr' '$T/stdout'"
}
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put tok-kc; rc=$?; ef_put_deny ef_put_keychain_only_refused
UNAME=Linux SP=found STDIN="$T/in" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_refused_when_in_sops
UNAME=Linux SP=error STDIN="$T/in" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_refused_sops_unknown
UNAME=Linux SP=notfound STDIN="$T/multi" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_multiline
UNAME=Linux SP=notfound STDIN="$T/ctl" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_control_char
printf 'DUMMY-NOT-A-SECRET-CR\r\n' > "$T/cr"
# Git Bash 的 $(...) 會把結尾的 CRLF 一起去掉（broker 的 cmd_put 有註明），結尾 CR 的 case 只在其他主機跑；
# 值中間的 CR 每個主機都要拒絕
if [ $WIN = 0 ]; then
  UNAME=Linux SP=notfound STDIN="$T/cr" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_carriage_return
fi
printf 'DUMMY-NOT-A-SECRET\rCR\n' > "$T/cr"
UNAME=Linux SP=notfound STDIN="$T/cr" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_inner_carriage_return
UNAME=Linux SP=notfound STDIN=/dev/null broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_empty
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put unknown-alias; rc=$?; ef_put_deny ef_put_unknown_alias
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put PATH; rc=$?; ef_put_deny ef_put_denylisted_name
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put 'a.c'; rc=$?; ef_put_deny ef_put_bad_name
chmod 644 "$EF"; cp -p "$EF" "$T/ef-before"
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?; ef_put_deny ef_put_bad_mode_refused
check ef_put_bad_mode_reason stderr_has 'mode'
chmod 600 "$EF"; cp -p "$EF" "$T/ef-before"
chmod 770 "$EF_DIR"
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put MY_SIMPLE; rc=$?; ef_put_deny ef_put_dir_writable_refused
chmod 700 "$EF_DIR"
/bin/mv "$EF" "$T/ef-target"; ln -s "$T/ef-target" "$EF"; cp -p "$T/ef-target" "$T/ef-target-before"
UNAME=Linux SP=notfound STDIN="$T/in" broker as_main put tok-sops; rc=$?
ef_symlink_ok && check ef_put_symlink_refused all bad_rc "[ -L '$EF' ]" "cmp -s '$T/ef-target' '$T/ef-target-before'" no_tmp "stderr_has 'symlink'" "no_dummy '$T/stderr'"
/bin/rm -f "$EF" "$T/ef-target" "$T/ef-target-before" "$T/ef-before" "$T/ef-expect"
default_table

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
