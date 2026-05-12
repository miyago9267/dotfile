#!/usr/bin/env bash
# sre-locate: 跨 cluster / project / VM 的服務與日誌定位工具
# Phase 1: k8s + gcloud 平行掃描

set -uo pipefail
set +m  # disable job control messages (Terminated: 15 etc)

readonly SCRIPT_NAME="sre-locate"
readonly DEFAULT_LIMIT=50
readonly DEFAULT_FRESHNESS="1h"
readonly DEFAULT_TIMEOUT=10
readonly INVENTORY_FILE="${SRE_INVENTORY_FILE:-$HOME/dotfile/.ai/sre-inventory.md}"
readonly INVENTORY_TTL=$((6 * 3600))
readonly SSH_HOST_LIMIT=30
readonly SSH_TIMEOUT=5

# ---- usage ----
usage() {
  cat <<'EOF'
Usage: locate.sh <keyword> [options]

Cross-cluster / cross-project locator. Read-only.

Options:
  --source=k8s|gcp|ssh|all  Limit sources (default: all)
  --ns-hint=<ns>            Prioritize this namespace
  --freshness=<dur>         gcloud logging freshness window (default: 1h)
  --limit=<n>               Max hits per source (default: 50)
  --timeout=<sec>           Per-source timeout (default: 10)
  --no-cache                Bypass inventory cache
  --ssh, --include-ssh      Include SSH VM scan (off by default with --source=all)
  -h, --help                Show this help

Examples:
  locate.sh fine-tune
  locate.sh ECONNREFUSED --source=gcp --freshness=30m
  locate.sh nginx --ns-hint=pms-fine-tune-html-testing
EOF
}

# ---- arg parsing ----
KEYWORD=""
SOURCE="all"
INCLUDE_SSH=0
NS_HINT=""
FRESHNESS="$DEFAULT_FRESHNESS"
LIMIT="$DEFAULT_LIMIT"
TIMEOUT_SEC="$DEFAULT_TIMEOUT"
USE_CACHE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --source=*) SOURCE="${1#*=}" ;;
    --ns-hint=*) NS_HINT="${1#*=}" ;;
    --freshness=*) FRESHNESS="${1#*=}" ;;
    --limit=*) LIMIT="${1#*=}" ;;
    --timeout=*) TIMEOUT_SEC="${1#*=}" ;;
    --no-cache) USE_CACHE=0 ;;
    --ssh|--include-ssh) INCLUDE_SSH=1 ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *) if [[ -z "$KEYWORD" ]]; then KEYWORD="$1"; else echo "Extra arg: $1" >&2; exit 1; fi ;;
  esac
  shift
done

if [[ -z "$KEYWORD" ]]; then
  usage; exit 1
fi

case "$SOURCE" in
  k8s|gcp|ssh|all) ;;
  *) echo "Invalid --source: $SOURCE" >&2; exit 1 ;;
esac
[[ "$SOURCE" == "ssh" ]] && INCLUDE_SSH=1

# ---- tool check ----
need_k8s=0; need_gcp=0; need_ssh=0
[[ "$SOURCE" == "k8s" || "$SOURCE" == "all" ]] && need_k8s=1
[[ "$SOURCE" == "gcp" || "$SOURCE" == "all" ]] && need_gcp=1
[[ "$SOURCE" == "ssh" ]] || [[ "$SOURCE" == "all" && $INCLUDE_SSH -eq 1 ]] && need_ssh=1

if [[ $need_k8s -eq 1 ]] && ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2; exit 2
fi
if [[ $need_gcp -eq 1 ]] && ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud not found in PATH" >&2; exit 2
fi

# ---- workspace ----
WORKDIR="$(mktemp -d -t sre-locate.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---- timeout wrapper (Bash-native, no `timeout` dep on macOS) ----
run_with_timeout() (
  exec 2>/dev/null
  local sec="$1"; shift
  local outfile="$1"; shift
  ( "$@" ) >"$outfile" 2>&1 &
  local pid=$!
  local count=0
  while kill -0 "$pid" 2>/dev/null; do
    if [[ $count -ge $sec ]]; then
      kill -TERM "$pid" 2>/dev/null
      sleep 1
      kill -KILL "$pid" 2>/dev/null
      echo "__TIMEOUT__" >>"$outfile"
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
    count=$((count + 1))
  done
  wait "$pid" 2>/dev/null
  return $?
)

# ---- k8s scan ----
scan_k8s_context() {
  local ctx="$1"
  local outfile="$WORKDIR/k8s.${ctx//\//_}.out"

  {
    # 優先掃 NS_HINT，再掃全 namespace
    local cmd_args=(--context="$ctx" --request-timeout=5s)
    if [[ -n "$NS_HINT" ]]; then
      kubectl "${cmd_args[@]}" -n "$NS_HINT" get pods,svc,deploy,configmap -o wide --no-headers \
        | grep -iE "$KEYWORD" | head -n "$LIMIT" | sed "s/^/[hint:$NS_HINT] /"
    fi
    kubectl "${cmd_args[@]}" get pods,svc,deploy -A -o wide --no-headers \
      | grep -iE "$KEYWORD" | head -n "$LIMIT"
  } >"$outfile" 2>&1
}

scan_k8s_all() {
  local contexts
  contexts=$(kubectl config get-contexts -o name 2>/dev/null)
  if [[ -z "$contexts" ]]; then
    echo "no kubectl contexts" >"$WORKDIR/k8s.error"
    return
  fi
  local pids=()
  while IFS= read -r ctx; do
    [[ -z "$ctx" ]] && continue
    (
      run_with_timeout "$TIMEOUT_SEC" "$WORKDIR/k8s.${ctx//\//_}.out" scan_k8s_context "$ctx"
    ) &
    pids+=($!)
  done <<<"$contexts"
  for p in "${pids[@]}"; do wait "$p" 2>/dev/null; done
}

# ---- gcloud scan ----
scan_gcp_project() {
  local proj="$1"
  local outfile="$WORKDIR/gcp.${proj}.out"

  gcloud logging read \
    "textPayload:\"$KEYWORD\" OR jsonPayload.message:\"$KEYWORD\"" \
    --project="$proj" \
    --freshness="$FRESHNESS" \
    --limit="$LIMIT" \
    --format="value(timestamp,resource.labels.cluster_name,resource.labels.namespace_name,textPayload)" \
    >"$outfile" 2>&1
}

scan_gcp_all() {
  local projects
  projects=$(gcloud config configurations list --format="value(properties.core.project)" 2>/dev/null | sort -u)
  if [[ -z "$projects" ]]; then
    # fallback to gcloud projects list (top 10)
    projects=$(gcloud projects list --format="value(projectId)" --limit=10 2>/dev/null)
  fi
  if [[ -z "$projects" ]]; then
    echo "no gcloud projects" >"$WORKDIR/gcp.error"
    return
  fi
  local pids=()
  while IFS= read -r proj; do
    [[ -z "$proj" ]] && continue
    (
      run_with_timeout "$TIMEOUT_SEC" "$WORKDIR/gcp.${proj}.out" scan_gcp_project "$proj"
    ) &
    pids+=($!)
  done <<<"$projects"
  for p in "${pids[@]}"; do wait "$p" 2>/dev/null; done
}

# ---- inventory hints (Phase 3) ----
inventory_hints() {
  [[ $USE_CACHE -eq 0 ]] && return
  [[ ! -f "$INVENTORY_FILE" ]] && return
  local mtime
  if stat -f %m "$INVENTORY_FILE" >/dev/null 2>&1; then
    mtime=$(stat -f %m "$INVENTORY_FILE")
  else
    mtime=$(stat -c %Y "$INVENTORY_FILE")
  fi
  local now=$(date +%s)
  local age=$((now - mtime))
  if [[ $age -gt $INVENTORY_TTL ]]; then
    echo "  (inventory stale: ${age}s > ${INVENTORY_TTL}s; consider inventory-refresh.sh)"
    return
  fi
  local hits
  hits=$(grep -iE "$KEYWORD" "$INVENTORY_FILE" 2>/dev/null | head -n 20)
  if [[ -z "$hits" ]]; then
    echo "  (inventory: no match -- service/deploy/ingress level; pod-level still scanned)"
    return
  fi
  echo "  (inventory hints -- age=${age}s):"
  printf '%s\n' "$hits" | sed 's/^/    /'
}

# ---- SSH scan (Phase 4) ----
ssh_hosts_collect() {
  local outfile="$WORKDIR/ssh.hosts"
  : >"$outfile"
  # 1. ssh config
  if [[ -f "$HOME/.ssh/config" ]]; then
    grep -iE "^Host[[:space:]]+" "$HOME/.ssh/config" 2>/dev/null \
      | awk '{for(i=2;i<=NF;i++) if($i!~/[\*\?]/) print $i}' >>"$outfile"
  fi
  # 2. zsh history high-freq
  if [[ -f "$HOME/.zsh_history" ]]; then
    strings "$HOME/.zsh_history" 2>/dev/null \
      | sed -E 's/^: [0-9]+:[0-9]+;//' \
      | grep -E '^ssh ' \
      | awk '{for(i=2;i<=NF;i++) if($i!~/^-/ && $i!~/^"/) {print $i; break}}' \
      | sort | uniq -c | sort -rn | head -10 | awk '{print $2}' >>"$outfile"
  fi
  # 3. gcloud compute instances (running only, top SSH_HOST_LIMIT)
  if command -v gcloud >/dev/null 2>&1; then
    local projects
    projects=$(gcloud config configurations list --format="value(properties.core.project)" 2>/dev/null | sort -u)
    while IFS= read -r proj; do
      [[ -z "$proj" ]] && continue
      gcloud compute instances list --project="$proj" \
        --filter="status=RUNNING" \
        --format="value(name)" 2>/dev/null | head -10
    done <<<"$projects" >>"$outfile"
  fi
  sort -u "$outfile" | head -n "$SSH_HOST_LIMIT"
}

scan_ssh_host() {
  local host="$1"
  local outfile="$WORKDIR/ssh.${host//\//_}.out"
  ssh -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      "$host" \
      "set +e; \
       systemctl list-units --type=service --no-pager 2>/dev/null | grep -iE '$KEYWORD' | head -10; \
       docker ps --format '{{.Names}} {{.Image}} {{.Status}}' 2>/dev/null | grep -iE '$KEYWORD' | head -10; \
       journalctl --since '1 hour ago' --no-pager 2>/dev/null | grep -iE '$KEYWORD' | tail -5" \
      >"$outfile" 2>&1
}

scan_ssh_all() {
  local hosts
  hosts=$(ssh_hosts_collect)
  if [[ -z "$hosts" ]]; then
    echo "no ssh hosts" >"$WORKDIR/ssh.error"
    return
  fi
  local pids=()
  while IFS= read -r host; do
    [[ -z "$host" ]] && continue
    (
      run_with_timeout "$TIMEOUT_SEC" "$WORKDIR/ssh.${host//\//_}.out" scan_ssh_host "$host"
    ) &
    pids+=($!)
  done <<<"$hosts"
  for p in "${pids[@]}"; do wait "$p" 2>/dev/null; done
}

# ---- run scans ----
START_TS=$(date +%s)
INVENTORY_OUT=$(inventory_hints)

if [[ $need_k8s -eq 1 ]]; then scan_k8s_all & K8S_PID=$!; fi
if [[ $need_gcp -eq 1 ]]; then scan_gcp_all & GCP_PID=$!; fi
if [[ $need_ssh -eq 1 ]]; then scan_ssh_all & SSH_PID=$!; fi
[[ $need_k8s -eq 1 ]] && wait "$K8S_PID"
[[ $need_gcp -eq 1 ]] && wait "$GCP_PID"
[[ $need_ssh -eq 1 ]] && wait "$SSH_PID"

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))

# ---- aggregate output ----
echo "# sre-locate: keyword='$KEYWORD' source=$SOURCE elapsed=${ELAPSED}s"
echo ""

if [[ -n "$INVENTORY_OUT" ]]; then
  echo "## inventory"
  echo "$INVENTORY_OUT"
  echo ""
fi

TOTAL_HITS=0
FAILED_SOURCES=()

if [[ $need_k8s -eq 1 ]]; then
  echo "## kubectl"
  for f in "$WORKDIR"/k8s.*.out; do
    [[ -e "$f" ]] || continue
    local_ctx=$(basename "$f" .out); local_ctx="${local_ctx#k8s.}"
    if grep -q "__TIMEOUT__" "$f" 2>/dev/null; then
      echo "  [timeout]  $local_ctx"
      FAILED_SOURCES+=("k8s:$local_ctx (timeout)")
      continue
    fi
    if ! [[ -s "$f" ]] || grep -qE "Unable to connect|error|denied" "$f" 2>/dev/null; then
      if [[ -s "$f" ]] && grep -qE "Unable to connect|error|denied" "$f"; then
        echo "  [error]    $local_ctx"
        FAILED_SOURCES+=("k8s:$local_ctx (auth/connect)")
        continue
      fi
      echo "  [no hits]  $local_ctx"
      continue
    fi
    hits=$(wc -l <"$f" | tr -d ' ')
    TOTAL_HITS=$((TOTAL_HITS + hits))
    echo "  [$hits hits] $local_ctx"
    sed 's/^/    /' "$f"
  done
  echo ""
fi

if [[ $need_ssh -eq 1 ]]; then
  echo "## ssh hosts"
  for f in "$WORKDIR"/ssh.*.out; do
    [[ -e "$f" ]] || continue
    local_host=$(basename "$f" .out); local_host="${local_host#ssh.}"
    if grep -q "__TIMEOUT__" "$f" 2>/dev/null; then
      echo "  [timeout]  $local_host"
      FAILED_SOURCES+=("ssh:$local_host (timeout)")
      continue
    fi
    if grep -qE "Permission denied|Connection refused|Could not resolve|Host key verification failed" "$f" 2>/dev/null; then
      echo "  [error]    $local_host"
      FAILED_SOURCES+=("ssh:$local_host (auth/connect)")
      continue
    fi
    if [[ ! -s "$f" ]]; then
      echo "  [no hits]  $local_host"
      continue
    fi
    hits=$(wc -l <"$f" | tr -d ' ')
    TOTAL_HITS=$((TOTAL_HITS + hits))
    echo "  [$hits hits] $local_host"
    sed 's/^/    /' "$f"
  done
  echo ""
fi

if [[ $need_gcp -eq 1 ]]; then
  echo "## gcloud logging"
  for f in "$WORKDIR"/gcp.*.out; do
    [[ -e "$f" ]] || continue
    local_proj=$(basename "$f" .out); local_proj="${local_proj#gcp.}"
    if grep -q "__TIMEOUT__" "$f" 2>/dev/null; then
      echo "  [timeout]  $local_proj"
      FAILED_SOURCES+=("gcp:$local_proj (timeout)")
      continue
    fi
    if ! [[ -s "$f" ]]; then
      echo "  [no hits]  $local_proj"
      continue
    fi
    if grep -qE "ERROR|PERMISSION_DENIED" "$f" 2>/dev/null; then
      echo "  [error]    $local_proj"
      FAILED_SOURCES+=("gcp:$local_proj (auth/api)")
      continue
    fi
    hits=$(wc -l <"$f" | tr -d ' ')
    TOTAL_HITS=$((TOTAL_HITS + hits))
    echo "  [$hits hits] $local_proj"
    sed 's/^/    /' "$f"
  done
  echo ""
fi

# ---- summary ----
echo "## summary"
echo "  total hits: $TOTAL_HITS"
if [[ ${#FAILED_SOURCES[@]} -gt 0 ]]; then
  echo "  failed sources:"
  for s in "${FAILED_SOURCES[@]}"; do echo "    - $s"; done
fi
if [[ $TOTAL_HITS -eq 0 ]] && [[ ${#FAILED_SOURCES[@]} -eq 0 ]]; then
  echo "  hint: no hits; try broader keyword or larger --freshness"
fi
if [[ $TOTAL_HITS -ge $((LIMIT * 2)) ]]; then
  echo "  hint: many hits; consider narrowing with --ns-hint or more specific keyword"
fi

exit 0
