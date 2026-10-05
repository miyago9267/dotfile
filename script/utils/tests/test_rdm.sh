#!/usr/bin/env bash
# rdm 的回歸測試。broker 以 RDM_BROKER 換成假的：把收到的 argv 與 stdin 寫到暫存檔，
# 再吐出指定的 body 與 exit code；不碰真實的 Keychain 或 Redmine。值都是明顯的假字串。
# RDM 可用環境變數覆寫（teeth check 用：換成永遠 exit 0 的空殼時本測試必須失敗）。
# shellcheck disable=SC2016,SC2034  # 條件字串交給 eval 展開；rc 由 eval 內的條件讀取
set -u
RDM=${RDM:-"$(cd "$(dirname "$0")/.." && pwd)/rdm"}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export ARGV="$T/argv" STDIN="$T/stdin" FAKE_BODY="" FAKE_RC=0
export RDM_BROKER="$T/fake-broker" REDMINE_URL="https://redmine.invalid"
FAKE_KEY='DUMMY-NOT-A-SECRET'
fail=0; n=0

cat > "$RDM_BROKER" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$ARGV"
cat > "$STDIN"
printf '%s' "$FAKE_BODY"
exit "$FAKE_RC"
EOF
chmod +x "$RDM_BROKER"

# check <name> <條件...>：每個條件都以 eval 執行，全部成立才算過
check() {
  local name=$1 c; shift; n=$((n + 1))
  for c in "$@"; do
    eval "$c" || { echo "FAIL $name: $c"; fail=1; return; }
  done
}
run() { rm -f "$ARGV" "$STDIN"; "$RDM" "$@" > "$T/out" 2> "$T/err"; rc=$?; }

FAKE_BODY="{\"user\":{\"id\":98,\"api_key\":\"$FAKE_KEY\"}}" FAKE_RC=0
run GET /users/current.json < /dev/null
check get_ok '[ $rc = 0 ]' "grep -q '\"id\": 98' '$T/out'"
check get_strips_api_key "! grep -q '$FAKE_KEY' '$T/out'" "! grep -q api_key '$T/out'"
check get_calls_broker_alias "[ \"\$(sed -n '1,4p' '$ARGV' | tr '\n' ' ')\" = 'run redmine -- /usr/bin/curl ' ]"
check get_url_is_last_arg "[ \"\$(tail -1 '$ARGV')\" = 'https://redmine.invalid/users/current.json' ]"
check key_stays_out_of_argv "grep -qx -- '%REDMINE_API_KEY' '$ARGV'" \
  "grep -qx -- 'X-Redmine-API-Key: {{REDMINE_API_KEY}}' '$ARGV'"
check get_sends_no_body "! grep -qx -- '--data-binary' '$ARGV'"

FAKE_BODY='{"issue":{"id":1}}'
run POST /issues.json <<< '{"issue":{"subject":"s"}}'
check post_forwards_stdin '[ $rc = 0 ]' "grep -q '\"subject\":\"s\"' '$STDIN'"
check post_sends_json_body "grep -qx -- '--data-binary' '$ARGV'" "grep -qx -- '@-' '$ARGV'" \
  "grep -qx -- 'Content-Type: application/json' '$ARGV'" "grep -qx -- 'POST' '$ARGV'"

FAKE_BODY=''
run PUT /issues/1.json <<< '{"issue":{"notes":"n"}}'
check put_empty_body_ok '[ $rc = 0 ]' "[ ! -s '$T/out' ]" "grep -qx -- 'PUT' '$ARGV'"

FAKE_BODY='{"errors":["主旨 不可為空白"]}' FAKE_RC=22
run POST /issues.json <<< '{}'
check http_error_propagates '[ $rc = 22 ]' "grep -q '不可為空白' '$T/out'"

FAKE_BODY='<html>502 Bad Gateway</html>' FAKE_RC=22
run GET /issues.json < /dev/null
check non_json_body_shown '[ $rc = 22 ]' "grep -q '502 Bad Gateway' '$T/out'"

FAKE_BODY="<user><api_key>$FAKE_KEY</api_key></user>" FAKE_RC=0
run GET /issues.json < /dev/null
check unparsable_body_with_key_hidden "! grep -q '$FAKE_KEY' '$T/out'" "! grep -q '$FAKE_KEY' '$T/err'"

FAKE_BODY='{}' FAKE_RC=0
run DELETE /issues/1.json < /dev/null
check delete_refused '[ $rc = 2 ]' "[ ! -e '$ARGV' ]"
run GET issues.json < /dev/null
check relative_path_refused '[ $rc = 2 ]' "[ ! -e '$ARGV' ]"
run GET /users/current.xml < /dev/null
check non_json_endpoint_refused '[ $rc = 2 ]' "[ ! -e '$ARGV' ]"
run GET < /dev/null
check missing_path_refused '[ $rc = 2 ]' "[ ! -e '$ARGV' ]"

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
