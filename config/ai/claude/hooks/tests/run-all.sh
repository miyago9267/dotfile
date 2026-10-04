#!/usr/bin/env bash
# 一次跑完 hooks/tests 底下所有 test_*.sh，再跑 shared/jev/tests 的 python unittest。
# 任何一個失敗就 exit 1；失敗的測試會印出完整輸出，結尾印每個測試的 PASS/FAIL 摘要。
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
JEV_TESTS="$DIR/../../../shared/jev/tests"
names=(); results=(); fail=0

record() { # name rc output
  names+=("$1")
  if [ "$2" = 0 ]; then results+=(PASS); else results+=(FAIL); fail=1; printf '%s\n' "--- $1 (rc=$2) ---" "$3"; fi
}

for t in "$DIR"/test_*.sh; do
  [ -e "$t" ] || continue
  out=$(bash "$t" 2>&1); rc=$?
  record "$(basename "$t")" "$rc" "$out"
done

if [ -d "$JEV_TESTS" ]; then
  out=$(cd "$JEV_TESTS" && python3 -m unittest discover -s "$JEV_TESTS" 2>&1); rc=$?
else
  out="找不到目錄 $JEV_TESTS"; rc=1
fi
record "jev unittest" "$rc" "$out"

echo "=== 摘要 ==="
for i in "${!names[@]}"; do printf '%s %s\n' "${results[$i]}" "${names[$i]}"; done
[ $fail = 0 ] && echo "all passed"; exit $fail
