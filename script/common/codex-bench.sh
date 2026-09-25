#!/usr/bin/env bash
set -euo pipefail

PROMPT=${CODEX_BENCH_PROMPT:-'回覆 EXACT: OK。不要讀檔、不要跑工具、不要解釋。'}
RUNS=${CODEX_BENCH_RUNS:-1}
OUT_DIR=${CODEX_BENCH_OUT_DIR:-"${TMPDIR:-/tmp}/codex-bench"}

mkdir -p "$OUT_DIR"

run_case() {
  local name="$1"
  shift
  local run="$1"
  shift
  local out="$OUT_DIR/${name}-${run}.out"
  local err="$OUT_DIR/${name}-${run}.err"
  local start end elapsed status bytes

  start=$(date +%s)
  if "$@" "$PROMPT" >"$out" 2>"$err"; then
    status=0
  else
    status=$?
  fi
  end=$(date +%s)
  elapsed=$((end - start))
  bytes=$(wc -c <"$out" | tr -d ' ')
  printf '%s,%s,%s,%s,%s,%s,%s\n' "$name" "$run" "$status" "$elapsed" "$bytes" "$out" "$err"
}

printf 'case,run,status,elapsed_sec,stdout_bytes,stdout_path,stderr_path\n'

for run in $(seq 1 "$RUNS"); do
  run_case default "$run" codex exec --color never
  run_case fast "$run" codex exec --ignore-user-config -p fast --color never
  run_case code "$run" codex exec --ignore-user-config -p code --color never
  run_case heavy "$run" codex exec -p heavy --color never
done
