#!/usr/bin/env bash
# inventory-refresh: 掃所有 cluster 把 service/deployment/ingress 列表寫到 .ai/sre-inventory.md
# TTL 6h，由 locate.sh 讀取

set -uo pipefail
set +m

readonly INVENTORY_FILE="${SRE_INVENTORY_FILE:-$HOME/dotfile/.ai/sre-inventory.md}"
readonly TIMEOUT_SEC=15
readonly TTL_SECONDS=$((6 * 3600))

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found" >&2; exit 2
fi

mkdir -p "$(dirname "$INVENTORY_FILE")"
WORKDIR="$(mktemp -d -t sre-inventory.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

run_with_timeout() (
  exec 2>/dev/null
  local sec="$1"; shift
  local outfile="$1"; shift
  ( "$@" ) >"$outfile" 2>&1 &
  local pid=$! count=0
  while kill -0 "$pid" 2>/dev/null; do
    if [[ $count -ge $sec ]]; then
      kill -TERM "$pid" 2>/dev/null
      sleep 1
      kill -KILL "$pid" 2>/dev/null
      echo "__TIMEOUT__" >>"$outfile"
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1; count=$((count + 1))
  done
  wait "$pid" 2>/dev/null
)

scan_one() {
  local ctx="$1"
  kubectl --context="$ctx" --request-timeout=10s get svc,deploy,ingress -A \
    -o custom-columns=KIND:.kind,NS:.metadata.namespace,NAME:.metadata.name \
    --no-headers 2>/dev/null
}

contexts=$(kubectl config get-contexts -o name 2>/dev/null)
if [[ -z "$contexts" ]]; then
  echo "no kubectl contexts" >&2; exit 1
fi

echo "[sre-locate] refreshing inventory: $INVENTORY_FILE"
START=$(date +%s)

pids=()
while IFS= read -r ctx; do
  [[ -z "$ctx" ]] && continue
  (
    run_with_timeout "$TIMEOUT_SEC" "$WORKDIR/${ctx//\//_}.out" scan_one "$ctx"
  ) &
  pids+=($!)
done <<<"$contexts"
for p in "${pids[@]}"; do wait "$p" 2>/dev/null; done

# Write inventory
{
  echo "# SRE Inventory"
  echo ""
  echo "> Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "> TTL: 6h"
  echo "> Source: kubectl config get-contexts"
  echo ""

  while IFS= read -r ctx; do
    [[ -z "$ctx" ]] && continue
    file="$WORKDIR/${ctx//\//_}.out"
    [[ -e "$file" ]] || continue
    echo "## $ctx"
    echo ""
    if grep -q "__TIMEOUT__" "$file" 2>/dev/null; then
      echo "  status: timeout"
      echo ""
      continue
    fi
    if [[ ! -s "$file" ]]; then
      echo "  status: empty"
      echo ""
      continue
    fi
    hits=$(wc -l <"$file" | tr -d ' ')
    echo "  status: ok ($hits entries)"
    echo ""
    echo '```'
    cat "$file"
    echo '```'
    echo ""
  done <<<"$contexts"
} >"$INVENTORY_FILE"

ELAPSED=$(($(date +%s) - START))
echo "[sre-locate] inventory refreshed in ${ELAPSED}s -> $INVENTORY_FILE"
