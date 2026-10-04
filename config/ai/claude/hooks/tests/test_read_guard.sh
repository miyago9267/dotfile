#!/usr/bin/env bash
# read-guard.sh 的回歸測試（characterization）：大檔且無 offset/limit/pages 回 deny，其餘無輸出。
# 測試檔全在 mktemp 目錄。HOOK 可用環境變數覆寫（teeth check 用）。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/read-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
unset READ_GUARD_MAX_LINES
seq 1 401 >"$T/big.txt"
seq 1 400 >"$T/edge.txt"
seq 1 5 >"$T/small.txt"
: >"$T/empty.txt"
seq 1 401 >"$T/Makefile"
seq 1 11 >"$T/eleven.txt"
for ext in png jpg jpeg gif webp bmp svg pdf ipynb; do seq 1 401 >"$T/big.$ext"; done
seq 1 401 >"$T/big.PNG"
seq 1 401 >"$T/big.png.txt"
mkdir "$T/dir.d"

fail=0; n=0
run() { # name expect(deny|none) file_path extra-json [MAX 門檻覆寫]
  n=$((n + 1))
  if [ -n "${5:-}" ]; then
    out=$(jq -n --arg f "$3" --argjson e "$4" '{tool_input:({file_path:$f}+$e)}' | READ_GUARD_MAX_LINES="$5" bash "$HOOK" 2>/dev/null); rc=$?
  else
    out=$(jq -n --arg f "$3" --argjson e "$4" '{tool_input:({file_path:$f}+$e)}' | bash "$HOOK" 2>/dev/null); rc=$?
  fi
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  ok=0
  if [ "$2" = none ]; then [ -z "$out" ] && ok=1; else [ "$dec" = "$2" ] && ok=1; fi
  [ $rc = 0 ] || ok=0
  [ $ok = 1 ] || { echo "FAIL $1 expect=$2 rc=$rc dec=$dec out=$out"; fail=1; }
}
reason() { # name file extra-json MAX 子字串：deny 的 reason 要帶行數與門檻
  n=$((n + 1))
  out=$(jq -n --arg f "$2" --argjson e "$3" '{tool_input:({file_path:$f}+$e)}' | READ_GUARD_MAX_LINES="$4" bash "$HOOK" 2>/dev/null)
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' | grep -qF -- "$5" || { echo "FAIL $1 reason 缺 '$5': $out"; fail=1; }
}

# --- 超過門檻且無 range：deny ---
run big_no_range deny "$T/big.txt" '{}'
run big_no_extension deny "$T/Makefile" '{}'
run big_double_extension_text deny "$T/big.png.txt" '{}'
# GAP: 副檔名比對區分大小寫，.PNG 這類大寫副檔名不在放行清單，大檔會被擋
run big_upper_ext_png deny "$T/big.PNG" '{}'
reason big_reason_lines_and_threshold "$T/big.txt" '{}' 400 '有 401 行（門檻 400）'
reason big_reason_has_path "$T/big.txt" '{}' 400 "$T/big.txt"

# --- 門檻邊界 ---
run edge_exactly_max none "$T/edge.txt" '{}'
run edge_one_over deny "$T/big.txt" '{}'
run small_file none "$T/small.txt" '{}'
run empty_file none "$T/empty.txt" '{}'

# --- 帶 range：放行 ---
run range_offset none "$T/big.txt" '{"offset":100}'
run range_limit none "$T/big.txt" '{"limit":50}'
run range_pages none "$T/big.txt" '{"pages":"1-5"}'
run range_offset_and_limit none "$T/big.txt" '{"offset":10,"limit":20}'
run range_offset_zero none "$T/big.txt" '{"offset":0}'
run range_all_null deny "$T/big.txt" '{"offset":null,"limit":null,"pages":null}'

# --- 圖片 / pdf / notebook 副檔名：放行 ---
for ext in png jpg jpeg gif webp bmp svg pdf ipynb; do
  run "ext_$ext" none "$T/big.$ext" '{}'
done

# --- 不存在 / 非一般檔案 / 缺欄位：放行 ---
run missing_file none "$T/nope.txt" '{}'
run directory_path none "$T/dir.d" '{}'
run empty_file_path none '' '{}'
n=$((n + 1))
out=$(printf '%s' '{"tool_input":{}}' | bash "$HOOK" 2>/dev/null); rc=$?
{ [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL no_file_path_field rc=$rc out=$out"; fail=1; }
n=$((n + 1))
out=$(printf '%s' 'not json' | bash "$HOOK" 2>/dev/null); rc=$?
{ [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL bad_json rc=$rc out=$out"; fail=1; }

# --- READ_GUARD_MAX_LINES 覆寫 ---
run max_lowered_denies deny "$T/eleven.txt" '{}' 10
run max_lowered_edge_ok none "$T/eleven.txt" '{}' 11
run max_lowered_small_below none "$T/small.txt" '{}' 10
run max_raised_allows none "$T/big.txt" '{}' 1000
run max_lowered_below_default deny "$T/edge.txt" '{}' 399
run max_zero_denies_nonempty deny "$T/small.txt" '{}' 0
run max_lowered_range_still_ok none "$T/eleven.txt" '{"limit":5}' 10
run max_lowered_image_still_ok none "$T/big.png" '{}' 10
reason max_reason_shows_override "$T/eleven.txt" '{}' 10 '有 11 行（門檻 10）'

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
