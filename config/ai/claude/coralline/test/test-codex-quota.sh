#!/usr/bin/env bash
# Focused tests for the REMORA-only Codex app-server quota provider.
# Uses a local fake stdio server; no real credentials or network are touched.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
PROVIDER="$ROOT/codex-quota.py"
STATUSLINE="$ROOT/statusline.sh"
SAMPLE="$HERE/sample-input.json"
REAL_PYTHON=$(command -v python3)
TMPD=$(mktemp -d "${TMPDIR:-/tmp}/coralline-codex-quota.XXXXXX") || exit 1
FAKE_BIN="$TMPD/bin"
FAKE_CODEX="$FAKE_BIN/codex"
mkdir -p "$FAKE_BIN"

cleanup() {
  local pid_file pid
  for pid_file in "$TMPD"/case-*/fake.pid; do
    [ -f "$pid_file" ] || continue
    IFS= read -r pid < "$pid_file" || pid=""
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    kill "$pid" 2>/dev/null || true
  done
  rm -rf "$TMPD"
}
trap cleanup EXIT HUP INT TERM

cat > "$FAKE_CODEX" <<'PY'
#!/usr/bin/env python3
import json
import os
import select
import sys
import time

log_path = os.environ["FAKE_CODEX_LOG"]
pid_path = os.environ["FAKE_CODEX_PID_FILE"]
mode = os.environ.get("FAKE_CODEX_MODE", "both")

with open(pid_path, "w", encoding="ascii") as handle:
    handle.write(str(os.getpid()))
with open(log_path, "a", encoding="utf-8") as handle:
    handle.write("argv=" + json.dumps(sys.argv[1:]) + "\n")

if sys.argv[1:] != ["app-server", "--stdio", "-c", "analytics.enabled=false"]:
    sys.exit(64)

def recv():
    line = sys.stdin.readline()
    if not line:
        sys.exit(65)
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write("request=" + line)
    return json.loads(line)

def send(value):
    sys.stdout.write(json.dumps(value, separators=(",", ":")) + "\n")
    sys.stdout.flush()

initialize = recv()
if initialize.get("id") != 1 or initialize.get("method") != "initialize":
    sys.exit(66)
client_info = initialize.get("params", {}).get("clientInfo", {})
if client_info.get("name") != "coralline" or not client_info.get("version"):
    sys.exit(67)
if select.select([sys.stdin], [], [], 0.05)[0]:
    sys.exit(68)
if mode == "timeout-initialize":
    time.sleep(30)
if mode == "initialize-error":
    send({"id": 1, "error": {"code": -32000, "message": "init failed"}})
    sys.exit(0)
send({"id": 1, "result": {"userAgent": "fake", "codexHome": "/tmp/fake", "platformFamily": "unix", "platformOs": "test"}})
initialized = recv()
if initialized != {"method": "initialized"}:
    sys.exit(69)
request = recv()
if request.get("id") != 2 or request.get("method") != "account/rateLimits/read":
    sys.exit(70)

if mode == "timeout":
    time.sleep(30)
if mode == "malformed":
    sys.stdout.write("{not-json\n")
    sys.stdout.flush()
    sys.exit(0)
if mode == "deeply-nested":
    sys.stdout.write("[" * 2000 + "]" * 2000 + "\n")
    sys.stdout.flush()
    sys.exit(0)
if mode == "error":
    send({"id": 2, "error": {"code": -32001, "message": "quota failed"}})
    sys.exit(0)

now = int(time.time())
responses = {
    "both": {
        "primary": {"usedPercent": 66, "windowDurationMins": 10080, "resetsAt": now + 600000},
        "secondary": {"usedPercent": 12, "windowDurationMins": 300, "resetsAt": now + 12000},
    },
    "seven-only": {
        "primary": {"usedPercent": 81, "windowDurationMins": 10080, "resetsAt": now + 600000},
        "secondary": None,
    },
    "five-only": {
        "primary": {"usedPercent": 31, "windowDurationMins": 300, "resetsAt": now + 12000},
        "secondary": None,
    },
    "bounds": {
        "primary": {"usedPercent": 0, "windowDurationMins": 300, "resetsAt": now + 12000},
        "secondary": {"usedPercent": 100, "windowDurationMins": 10080, "resetsAt": now + 600000},
    },
    "untagged": {
        "primary": {"usedPercent": 9, "resetsAt": now + 12000},
        "secondary": {"usedPercent": 54, "resetsAt": now + 600000},
    },
    "untagged-primary-only": {
        "primary": {"usedPercent": 9, "resetsAt": now + 12000},
        "secondary": None,
    },
    "known-seven-ambiguous-secondary": {
        "primary": {"usedPercent": 77, "windowDurationMins": 10080, "resetsAt": now + 600000},
        "secondary": {"usedPercent": 22, "resetsAt": now + 12000},
    },
    "invalid-percent": {
        "primary": {"usedPercent": 101, "windowDurationMins": 300, "resetsAt": now + 12000},
        "secondary": None,
    },
    "invalid-reset": {
        "primary": {"usedPercent": 20, "windowDurationMins": 300, "resetsAt": 12.5},
        "secondary": None,
    },
    "unknown-duration": {
        "primary": {"usedPercent": 20, "windowDurationMins": 60, "resetsAt": now + 12000},
        "secondary": None,
    },
}
if mode == "notification-flood":
    for _ in range(129):
        send({"method": "account/rateLimits/updated", "params": {}})
    rate_limits = responses["seven-only"]
else:
    rate_limits = responses.get(mode)
if rate_limits is None:
    sys.exit(71)
send({"method": "account/rateLimits/updated", "params": {"rateLimits": rate_limits}})
send({"id": 2, "result": {"rateLimits": rate_limits, "account": {"email": "must-not-be-cached@example.invalid"}}})
PY
chmod +x "$FAKE_CODEX"

cat > "$FAKE_BIN/python3" <<'SH'
#!/usr/bin/env bash
printf 'python3\n' >> "$FAKE_PYTHON_LOG"
exec "$REAL_PYTHON" "$@"
SH
chmod +x "$FAKE_BIN/python3"

fail=0
ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s — %s\n' "$1" "$2"; fail=1; }
eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want=$(printf %q "$3") got=$(printf %q "$2")"; }
check() { [ "$2" = 1 ] && ok "$1" || bad "$1" "check failed"; }
mode_bits() { stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null; }

case_dir=""
new_case() {
  case_dir="$TMPD/case-$1"
  rm -rf "$case_dir"
  mkdir -p "$case_dir/home" "$case_dir/cache"
  export HOME="$case_dir/home"
  export XDG_CACHE_HOME="$case_dir/cache"
  export CORALLINE_CODEX_BINARY="$FAKE_CODEX"
  export FAKE_CODEX_MODE="${2:-both}"
  export FAKE_CODEX_LOG="$case_dir/fake.log"
  export FAKE_CODEX_PID_FILE="$case_dir/fake.pid"
  export FAKE_PYTHON_LOG="$case_dir/python.log"
  export REAL_PYTHON
}
run_provider() {
  provider_out=$(PATH="$FAKE_BIN:$PATH" "$PROVIDER" 2> "$case_dir/provider.err")
  provider_rc=$?
}
assert_stopped() {
  local label="$1" pid=""
  [ -f "$FAKE_CODEX_PID_FILE" ] && IFS= read -r pid < "$FAKE_CODEX_PID_FILE"
  case "$pid" in
    ''|*[!0-9]*) bad "$label" "missing pid" ;;
    *) kill -0 "$pid" 2>/dev/null && bad "$label" "pid $pid still alive" || ok "$label" ;;
  esac
}
cache_path() { printf '%s/coralline/codex-quota.json' "$XDG_CACHE_HOME"; }
write_cache() {
  local fetched="$1" five_used="$2" five_reset="$3" seven_used="$4" seven_reset="$5" file
  file=$(cache_path)
  mkdir -p "${file%/*}"
  "$REAL_PYTHON" - "$file" "$fetched" "$five_used" "$five_reset" "$seven_used" "$seven_reset" <<'PY'
import json
import sys
path, fetched, five_used, five_reset, seven_used, seven_reset = sys.argv[1:]
def window(used, reset):
    if used == "-":
        return None
    return {"usedPercent": int(used), "resetsAt": int(reset)}
with open(path, "w", encoding="utf-8") as handle:
    json.dump({"fetchedAt": int(fetched), "fiveHour": window(five_used, five_reset), "sevenDay": window(seven_used, seven_reset)}, handle, separators=(",", ":"))
PY
  chmod 600 "$file"
}

if [ ! -x "$PROVIDER" ]; then
  bad "provider exists and is executable" "$PROVIDER"
  printf 'SOME FAILED\n'
  exit 1
fi
ok "provider exists and is executable"

new_case both both
run_provider
case "$provider_out" in $'12\037'*$'\03766\037'*) ok "tagged 5h+7d output maps by duration and preserves direct used values" ;; *) bad "tagged 5h+7d output maps by duration and preserves direct used values" "$provider_out" ;; esac
[ "$provider_rc" = 0 ] && check "tagged response succeeds" 1 || check "tagged response succeeds" 0
assert_stopped "successful refresh stops app-server"
grep -q 'analytics.enabled=false' "$FAKE_CODEX_LOG" && check "app-server analytics explicitly disabled" 1 || check "app-server analytics explicitly disabled" 0

new_case seven seven-only
run_provider
case "$provider_out" in $'\037\03781\037'*) ok "7d-only leaves 5h absent" ;; *) bad "7d-only leaves 5h absent" "$provider_out" ;; esac
case "$provider_out" in 81$'\037'*) bad "known 7d is not duplicated into 5h" "$provider_out" ;; *) ok "known 7d is not duplicated into 5h" ;; esac
cache=$(cache_path)
eq "cache directory mode" "$(mode_bits "${cache%/*}")" "700"
eq "cache file mode" "$(mode_bits "$cache")" "600"
"$REAL_PYTHON" - "$cache" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
assert set(value) == {"fetchedAt", "fiveHour", "sevenDay"}
assert value["fiveHour"] is None
assert set(value["sevenDay"]) == {"usedPercent", "resetsAt"}
assert value["sevenDay"]["usedPercent"] == 81
assert "account" not in value
PY
[ "$?" = 0 ] && check "cache contains normalized fields only" 1 || check "cache contains normalized fields only" 0

after_first=$(wc -l < "$FAKE_CODEX_LOG" | tr -d ' ')
FAKE_CODEX_MODE=error; export FAKE_CODEX_MODE
run_provider
after_second=$(wc -l < "$FAKE_CODEX_LOG" | tr -d ' ')
case "$provider_out" in $'\037\03781\037'*) ok "fresh cache returns 7d value" ;; *) bad "fresh cache returns 7d value" "$provider_out" ;; esac
eq "fresh cache avoids app-server" "$after_second" "$after_first"

new_case bounds bounds
run_provider
case "$provider_out" in 0$'\037'*$'\037100\037'*) ok "0 and 100 percent are accepted directly" ;; *) bad "0 and 100 percent are accepted directly" "$provider_out" ;; esac

new_case fallback untagged
run_provider
case "$provider_out" in 9$'\037'*$'\03754\037'*) ok "untagged primary and secondary use positional fallback" ;; *) bad "untagged primary and secondary use positional fallback" "$provider_out" ;; esac

new_case lone-untagged untagged-primary-only
run_provider
[ "$provider_rc" != 0 ] && [ -z "$provider_out" ] && check "lone untagged primary is conservatively rejected" 1 || check "lone untagged primary is conservatively rejected" 0

new_case ambiguous known-seven-ambiguous-secondary
run_provider
case "$provider_out" in $'\037\03777\037'*) ok "ambiguous untagged secondary is ignored beside known 7d" ;; *) bad "ambiguous untagged secondary is ignored beside known 7d" "$provider_out" ;; esac

new_case five five-only
run_provider
case "$provider_out" in 31$'\037'*$'\037\037') ok "one tagged 5h window is supported" ;; *) bad "one tagged 5h window is supported" "$provider_out" ;; esac

for bad_mode in invalid-percent invalid-reset unknown-duration malformed error initialize-error; do
  new_case "bad-$bad_mode" "$bad_mode"
  run_provider
  [ "$provider_rc" != 0 ] && [ -z "$provider_out" ] && check "$bad_mode is rejected" 1 || check "$bad_mode is rejected" 0
done

new_case notification-flood notification-flood
run_provider
[ "$provider_rc" != 0 ] && [ -z "$provider_out" ] && check "notification flood is rejected" 1 || check "notification flood is rejected" 0
assert_stopped "notification flood stops app-server"

new_case timeout timeout
started=$(date +%s)
run_provider
elapsed=$(( $(date +%s) - started ))
[ "$provider_rc" != 0 ] && [ -z "$provider_out" ] && check "timeout returns no quota" 1 || check "timeout returns no quota" 0
[ "$elapsed" -le 5 ] && check "timeout is bounded" 1 || bad "timeout is bounded" "elapsed=${elapsed}s"
assert_stopped "timeout kills app-server"

new_case stale error
now=$(date +%s)
write_cache "$((now - 120))" 44 "$((now + 12000))" 55 "$((now + 600000))"
run_provider
case "$provider_out" in 44$'\037'*$'\03755\037'*) ok "stale cache survives refresh error" ;; *) bad "stale cache survives refresh error" "$provider_out" ;; esac

new_case stale-deeply-nested deeply-nested
now=$(date +%s)
write_cache "$((now - 120))" 44 "$((now + 12000))" 55 "$((now + 600000))"
run_provider
case "$provider_out" in 44$'\037'*$'\03755\037'*) ok "stale cache survives deeply nested JSON" ;; *) bad "stale cache survives deeply nested JSON" "$provider_out" ;; esac

new_case expired error
now=$(date +%s)
write_cache "$((now - 901))" 44 "$((now + 12000))" 55 "$((now + 600000))"
run_provider
[ "$provider_rc" != 0 ] && [ -z "$provider_out" ] && check "cache older than 900 seconds is rejected" 1 || check "cache older than 900 seconds is rejected" 0

new_case stale-lock seven-only
mkdir -p "$XDG_CACHE_HOME/coralline/.codex-quota.lock"
touch -t 200001010000 "$XDG_CACHE_HOME/coralline/.codex-quota.lock"
run_provider
case "$provider_out" in $'\037\03781\037'*) ok "stale lock is recovered" ;; *) bad "stale lock is recovered" "$provider_out" ;; esac
[ ! -d "$XDG_CACHE_HOME/coralline/.codex-quota.lock" ] && check "recovered lock is released" 1 || check "recovered lock is released" 0

new_case recent-lock error
now=$(date +%s)
write_cache "$((now - 120))" 33 "$((now + 12000))" 77 "$((now + 600000))"
mkdir -p "$XDG_CACHE_HOME/coralline/.codex-quota.lock"
run_provider
case "$provider_out" in 33$'\037'*$'\03777\037'*) ok "recent lock returns stale cache without waiting" ;; *) bad "recent lock returns stale cache without waiting" "$provider_out" ;; esac
[ ! -e "$FAKE_CODEX_LOG" ] && check "recent lock avoids competing app-server" 1 || check "recent lock avoids competing app-server" 0

new_case relative seven-only
CORALLINE_CODEX_BINARY="codex"; export CORALLINE_CODEX_BINARY
run_provider
[ "$provider_rc" != 0 ] && [ ! -e "$FAKE_CODEX_LOG" ] && check "relative binary override is rejected" 1 || check "relative binary override is rejected" 0

new_case nonexec seven-only
printf '#!/bin/sh\nexit 0\n' > "$case_dir/not-executable"
CORALLINE_CODEX_BINARY="$case_dir/not-executable"; export CORALLINE_CODEX_BINARY
run_provider
[ "$provider_rc" != 0 ] && [ ! -e "$FAKE_CODEX_LOG" ] && check "non-executable binary override is rejected" 1 || check "non-executable binary override is rejected" 0

new_case path seven-only
unset CORALLINE_CODEX_BINARY
run_provider
case "$provider_out" in $'\037\03781\037'*) ok "PATH fallback resolves codex" ;; *) bad "PATH fallback resolves codex" "$provider_out" ;; esac

new_case native seven-only
printf 'VL_CLOCK=off\n' > "$case_dir/native.conf"
CORALLINE_NO_SAMPLE=1 CORALLINE_CONFIG="$case_dir/native.conf" bash "$STATUSLINE" < "$SAMPLE" > "$case_dir/plain.out"
rm -f "$FAKE_CODEX_LOG" "$FAKE_PYTHON_LOG"
PATH="$FAKE_BIN:$PATH" REMORA_ACTIVE=1 CORALLINE_NO_SAMPLE=1 CORALLINE_CONFIG="$case_dir/native.conf" \
  bash "$STATUSLINE" < "$SAMPLE" > "$case_dir/native.out"
cmp -s "$case_dir/plain.out" "$case_dir/native.out" && check "native rate limits remain byte-identical" 1 || check "native rate limits remain byte-identical" 0
[ -s "$case_dir/native.out" ] && check "native render still produces output" 1 || check "native render still produces output" 0
[ ! -e "$FAKE_PYTHON_LOG" ] && [ ! -e "$FAKE_CODEX_LOG" ] && check "native render starts no Python or Codex" 1 || check "native render starts no Python or Codex" 0

new_case render seven-only
printf 'VL_ASCII=1\nVL_CLOCK=off\nVL_SEGMENTS="limit5h limit7d"\n' > "$case_dir/remora.conf"
rendered=$(PATH="$FAKE_BIN:$PATH" REMORA_ACTIVE=1 CORALLINE_NO_SAMPLE=1 CORALLINE_CONFIG="$case_dir/remora.conf" bash "$STATUSLINE" <<'JSON'
{"workspace":{"current_dir":""},"rate_limits":{}}
JSON
)
case "$rendered" in *7d*) ok "REMORA render shows available 7d segment" ;; *) bad "REMORA render shows available 7d segment" "$rendered" ;; esac
case "$rendered" in *5h*) bad "REMORA render omits unavailable 5h segment" "$rendered" ;; *) ok "REMORA render omits unavailable 5h segment" ;; esac
[ -s "$FAKE_PYTHON_LOG" ] && [ -s "$FAKE_CODEX_LOG" ] && check "REMORA render invokes provider and app-server" 1 || check "REMORA render invokes provider and app-server" 0

new_case relative-render seven-only
printf 'VL_ASCII=1\nVL_CLOCK=off\nVL_SEGMENTS="limit5h limit7d"\n' > "$case_dir/remora.conf"
rendered=$(cd "$ROOT" && PATH="$FAKE_BIN:$PATH" REMORA_ACTIVE=1 CORALLINE_NO_SAMPLE=1 CORALLINE_CONFIG="$case_dir/remora.conf" bash statusline.sh <<'JSON'
{"workspace":{"current_dir":""},"rate_limits":{}}
JSON
)
case "$rendered" in *7d*) ok "relative renderer invocation finds sibling provider" ;; *) bad "relative renderer invocation finds sibling provider" "$rendered" ;; esac
[ -s "$FAKE_PYTHON_LOG" ] && [ -s "$FAKE_CODEX_LOG" ] && check "relative renderer invokes sibling provider" 1 || check "relative renderer invokes sibling provider" 0

for forbidden in 'CLIProxy'"API" 'cliproxyapi-'"mgmt-key" 'REMORA_QUOTA_'"TRUST_LOOPBACK" 'REMORA_QUOTA_'"BASE" '/v0/'"management/"; do
  if grep -R -F -q --exclude='test-codex-quota.sh' "$forbidden" "$ROOT"; then
    bad "source tree excludes legacy management reference" "$forbidden"
  else
    ok "source tree excludes legacy management reference: $forbidden"
  fi
done
[ ! -e "$ROOT/remora-quota.sh" ] && check "legacy helper is removed" 1 || check "legacy helper is removed" 0

if [ "$fail" -eq 0 ]; then printf 'ALL PASS\n'; else printf 'SOME FAILED\n'; exit 1; fi
