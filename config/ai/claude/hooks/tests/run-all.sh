#!/usr/bin/env bash
# 平行跑 hooks/tests 底下所有 test_*.sh，再加上 shared/jev/tests 的 python unittest。
# 每個 suite 的輸出寫進 mktemp 目錄，全部結束後依固定順序印 PASS/FAIL，失敗的 suite 印完整輸出。
# 任何一個失敗就 exit 1。相容 bash 3.2（macOS /bin/bash）。
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
JEV_TESTS="$DIR/../../../shared/jev/tests"
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
names=(); pids=(); fail=0

launch() { # name command...：背景執行，輸出進 $WORK/<序號>.out
  local i=${#names[@]}
  names+=("$1"); shift
  "$@" >"$WORK/$i.out" 2>&1 &
  pids+=("$!")
}

for t in "$DIR"/test_*.sh; do
  [ -e "$t" ] || continue
  launch "$(basename "$t")" bash "$t"
done
launch "jev unittest" bash -c 'cd "$1" 2>/dev/null && python3 -m unittest discover -s "$1" || { echo "找不到目錄 $1"; exit 1; }' _ "$JEV_TESTS"

rcs=()
for i in "${!names[@]}"; do
  wait "${pids[$i]}"; rcs+=("$?")
done

for i in "${!names[@]}"; do
  if [ "${rcs[$i]}" != 0 ]; then
    fail=1
    printf '%s\n' "--- ${names[$i]} (rc=${rcs[$i]}) ---"
    cat "$WORK/$i.out"
  fi
done

echo "=== 摘要 ==="
for i in "${!names[@]}"; do
  if [ "${rcs[$i]}" = 0 ]; then echo "PASS ${names[$i]}"; else echo "FAIL ${names[$i]}"; fi
done
[ $fail = 0 ] && echo "all passed"; exit $fail
