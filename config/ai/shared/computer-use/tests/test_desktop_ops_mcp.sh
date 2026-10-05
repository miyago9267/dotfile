#!/bin/bash

# Tests for desktop-ops-mcp.sh. A fake repo and a fake bun stand in for the
# real ones: no MCP server, driver, helper, or GUI is started.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$TESTS_DIR/../desktop-ops-mcp.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/desktop-ops-mcp-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok() {
  PASS=$((PASS + 1))
  printf 'ok   - %s\n' "$1"
}

not_ok() {
  FAIL=$((FAIL + 1))
  printf 'FAIL - %s\n' "$1"
}

check() {
  desc="$1"
  shift
  if "$@"; then ok "$desc"; else not_ok "$desc"; fi
}

# make_fixture: fake repo (server entry, installed deps, built helper) and a
# fake bun that records argv, cwd and environment instead of running anything.
make_fixture() {
  rm -rf "${WORK:?}/repo" "${WORK:?}/bin" "${WORK:?}/home" "${WORK:?}"/child.* "${WORK:?}/stderr"
  mkdir -p "$WORK/repo/src" "$WORK/repo/helper" "$WORK/repo/node_modules/@modelcontextprotocol/sdk" "$WORK/bin" "$WORK/home/elsewhere"
  : >"$WORK/repo/src/server.ts"
  printf '#!/bin/sh\nexit 0\n' >"$WORK/repo/helper/desktop-ops-helper"
  chmod +x "$WORK/repo/helper/desktop-ops-helper"
  cat >"$WORK/bin/bun" <<BUN
#!/bin/sh
printf '%s\n' "\$@" >"$WORK/child.args"
pwd -P >"$WORK/child.cwd"
env >"$WORK/child.env"
exit 0
BUN
  chmod +x "$WORK/bin/bun"
}

# run_launcher [VAR=value ...] -- [launcher args...]
# Runs $TARGET: the shipped launcher unless a test points it at the off copy.
TARGET="$LAUNCHER"
run_launcher() {
  envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    envs+=("$1")
    shift
  done
  [ "$#" -gt 0 ] && shift
  (
    cd "$WORK/home/elsewhere" || exit 99
    /usr/bin/env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" \
      DESKTOP_OPS_HOME="$WORK/repo" ${envs[@]+"${envs[@]}"} \
      "$TARGET" "$@" >"$WORK/stdout" 2>"$WORK/stderr"
  )
  RC=$?
}

child_ran() { [ -e "$WORK/child.args" ]; }
child_not_run() { [ ! -e "$WORK/child.args" ]; }
env_is() { grep -qx "$1" "$WORK/child.env"; }
env_lacks() { ! grep -q "^$1=" "$WORK/child.env"; }
one_line_stderr() { [ "$(wc -l <"$WORK/stderr" | tr -d ' ')" = "1" ]; }

REAL_SHARED="$(cd "$TESTS_DIR/.." && pwd -P)"
REAL_REPO="$(cd "$WORK" && pwd -P)/repo"

# The secrets file and the broker both leave a marker when touched, so "not
# read" and "not invoked" are observable. Every key below is a dummy string,
# and HOME is always the throwaway one: the real ~/.env.secrets is never read.
make_secrets() {
  cat >"$WORK/home/.env.secrets" <<SECRETS
: >"$WORK/secrets.sourced"
export TYPESAFE_API_KEY=dummy-file-key-for-tests
export OTHER_SECRET=dummy-other-secret
SECRETS
}
make_broker() {
  cat >"$WORK/bin/agent-secret" <<BROKER
#!/bin/sh
printf '%s\n' "\$@" >"$WORK/broker.args"
[ "\$1" = run ] && [ "\$3" = "--" ] || exit 64
shift 3
TYPESAFE_API_KEY=dummy-broker-key-for-tests exec "\$@"
BROKER
  chmod +x "$WORK/bin/agent-secret"
}
clean_markers() { rm -f "$WORK/secrets.sourced" "$WORK/broker.args" "$WORK/stdout"; }
no_key_in_argv() { ! grep -q 'dummy-' "$WORK/child.args"; }
silent() { [ ! -s "$WORK/stderr" ] && [ ! -s "$WORK/stdout" ]; }

# The off launcher: a copy of the shipped one with only the switch line
# changed, next to stand-ins for its two siblings.
OFF_DIR="$WORK/off"
OFF_LAUNCHER="$OFF_DIR/desktop-ops-mcp.sh"
make_off_launcher() {
  rm -rf "$OFF_DIR"
  mkdir -p "$OFF_DIR"
  sed 's/^DESKTOP_OPS_JEV_PATH=on$/DESKTOP_OPS_JEV_PATH=off/' "$LAUNCHER" >"$OFF_LAUNCHER"
  chmod +x "$OFF_LAUNCHER"
  printf '#!/bin/sh\nexit 0\n' >"$OFF_DIR/computer-use-mcp.sh"
  chmod +x "$OFF_DIR/computer-use-mcp.sh"
  printf '{"version":1}\n' >"$OFF_DIR/policy.json"
}
REAL_OFF="$(cd "$WORK" && pwd -P)/off"
switch_lines() { grep -c '^DESKTOP_OPS_JEV_PATH=' "$1"; }

make_off_launcher
check 'the switch is one line' [ "$(switch_lines "$LAUNCHER")" = "1" ]
check 'shipped launcher default is on' grep -qx 'DESKTOP_OPS_JEV_PATH=on' "$LAUNCHER"
check 'the off copy has one switch line, and it is off' [ "$(grep '^DESKTOP_OPS_JEV_PATH=' "$OFF_LAUNCHER")" = "DESKTOP_OPS_JEV_PATH=off" ]
check 'the off copy differs from the shipped launcher by that one line' [ "$(diff "$LAUNCHER" "$OFF_LAUNCHER" | grep -c '^[<>]')" = "2" ]

# --- happy path (shipped: on; no key anywhere) ---------------------------------
make_fixture
clean_markers
run_launcher --
check 'happy path exits 0' [ "$RC" -eq 0 ]
check 'bun was started' child_ran
check 'argv is exactly: --no-install --no-env-file <repo>/src/server.ts' [ "$(tr '\n' '|' <"$WORK/child.args")" = "--no-install|--no-env-file|$WORK/repo/src/server.ts|" ]
check 'cwd is the repo, not the caller cwd' [ "$(cat "$WORK/child.cwd")" = "$REAL_REPO" ]
check 'Jev path switch is on' env_is 'DESKTOP_OPS_JEV_PATH=on'
check 'driver command is the sibling S1 launcher' env_is "DESKTOP_OPS_DRIVER_CMD=$REAL_SHARED/computer-use-mcp.sh"
check 'policy file is the sibling policy.json' env_is "DESKTOP_OPS_POLICY=$REAL_SHARED/policy.json"
check 'no key and no broker: still starts (the Jev tools report no_api_key)' child_ran
check 'no key and no broker: no key in the child environment' env_lacks TYPESAFE_API_KEY

# --- inherited environment cannot redirect anything or change the switch ----------
make_fixture
clean_markers
make_secrets
run_launcher DESKTOP_OPS_JEV_PATH=off \
  DESKTOP_OPS_HELPER=/tmp/evil-helper DESKTOP_OPS_STATE_DIR=/tmp/evil-state \
  DESKTOP_OPS_DRIVER_CMD=/tmp/evil-driver DESKTOP_OPS_POLICY=/tmp/evil-policy.json \
  DESKTOP_OPS_API_URL=http://evil.example/ DESKTOP_OPS_FUTURE_KNOB=1 --
check 'inherited overrides: still starts' child_ran
check 'inherited DESKTOP_OPS_JEV_PATH=off does not turn the switch off' env_is 'DESKTOP_OPS_JEV_PATH=on'
check 'inherited off: the on branch still ran (key from the secrets file)' env_is 'TYPESAFE_API_KEY=dummy-file-key-for-tests'
check 'inherited helper override is dropped' env_lacks DESKTOP_OPS_HELPER
check 'inherited state dir override is dropped' env_lacks DESKTOP_OPS_STATE_DIR
check 'inherited endpoint override is dropped' env_lacks DESKTOP_OPS_API_URL
check 'inherited unknown DESKTOP_OPS_* is dropped' env_lacks DESKTOP_OPS_FUTURE_KNOB
check 'inherited driver override is replaced' env_is "DESKTOP_OPS_DRIVER_CMD=$REAL_SHARED/computer-use-mcp.sh"
check 'inherited policy override is replaced' env_is "DESKTOP_OPS_POLICY=$REAL_SHARED/policy.json"

for inherited in on ON 1 'off;on' ''; do
  make_fixture
  clean_markers
  run_launcher "DESKTOP_OPS_JEV_PATH=$inherited" --
  check "inherited DESKTOP_OPS_JEV_PATH='$inherited' changes nothing: switch is exactly on" env_is 'DESKTOP_OPS_JEV_PATH=on'
  check "inherited DESKTOP_OPS_JEV_PATH='$inherited': exactly one switch entry in the child environment" [ "$(grep -c '^DESKTOP_OPS_JEV_PATH=' "$WORK/child.env")" = "1" ]
done

# --- extra arguments are not forwarded ----------------------------------------
make_fixture
run_launcher -- --eval 'console.log(1)'
check 'extra args: argv is still exactly three entries' [ "$(wc -l <"$WORK/child.args" | tr -d ' ')" = "3" ]

# --- fail closed ---------------------------------------------------------------
make_fixture
clean_markers
make_secrets
rm "$WORK/repo/helper/desktop-ops-helper"
run_launcher --
check 'helper not built: non-zero exit (fails closed before any key lookup)' [ "$RC" -ne 0 ]
check 'helper not built: the secrets file was not read' [ ! -e "$WORK/secrets.sourced" ]
check 'helper not built: bun not started' child_not_run
check 'helper not built: one stderr line' one_line_stderr

make_fixture
rm -rf "$WORK/repo/node_modules"
run_launcher --
check 'deps not installed: non-zero exit' [ "$RC" -ne 0 ]
check 'deps not installed: bun not started' child_not_run

make_fixture
rm "$WORK/repo/src/server.ts"
run_launcher --
check 'repo missing: non-zero exit' [ "$RC" -ne 0 ]
check 'repo missing: bun not started' child_not_run

make_fixture
rm "$WORK/bin/bun"
run_launcher --
check 'bun missing: exit 127' [ "$RC" -eq 127 ]

make_fixture
rm "$WORK/bin/bun"
mkdir -p "$WORK/home/.bun/bin"
cat >"$WORK/home/.bun/bin/bun" <<BUN
#!/bin/sh
printf '%s\n' "\$@" >"$WORK/child.args"
exit 0
BUN
chmod +x "$WORK/home/.bun/bin/bun"
run_launcher --
check 'bun not on PATH: falls back to ~/.bun/bin/bun' child_ran

# --- switch on (the shipped launcher): where the key comes from --------------------
make_fixture
clean_markers
make_secrets
run_launcher OTHER_INHERITED=1 DESKTOP_OPS_API_URL=http://evil.example/ --
check 'on + secrets file: starts' child_ran
check 'on: switch is on' env_is 'DESKTOP_OPS_JEV_PATH=on'
check 'on: key comes from the secrets file' env_is 'TYPESAFE_API_KEY=dummy-file-key-for-tests'
check 'on: no other secret from that file is passed on' env_lacks OTHER_SECRET
check 'on: the key is not an argument' no_key_in_argv
check 'on: argv is exactly: --no-install --no-env-file <repo>/src/server.ts' [ "$(tr '\n' '|' <"$WORK/child.args")" = "--no-install|--no-env-file|$WORK/repo/src/server.ts|" ]
check 'on: nothing is printed (the key is never echoed)' silent
check 'on: inherited endpoint override is dropped' env_lacks DESKTOP_OPS_API_URL
check 'on: cwd is the repo, not the caller cwd' [ "$(cat "$WORK/child.cwd")" = "$REAL_REPO" ]

make_fixture
clean_markers
make_secrets
make_broker
run_launcher TYPESAFE_API_KEY=dummy-inherited-key --
check 'on: the secrets file wins over an inherited key' env_is 'TYPESAFE_API_KEY=dummy-file-key-for-tests'
check 'on: the broker is not used when a key is already there' [ ! -e "$WORK/broker.args" ]

make_fixture
clean_markers
run_launcher TYPESAFE_API_KEY=dummy-inherited-key --
check 'on, no secrets file: an inherited key is passed through' env_is 'TYPESAFE_API_KEY=dummy-inherited-key'
check 'on, inherited key: not an argument' no_key_in_argv
check 'on, inherited key: nothing is printed' silent

make_fixture
clean_markers
make_broker
run_launcher --
check 'on, no key: starts through the broker' child_ran
check 'on, no key: broker argv is run typesafe-api -- bun --no-install --no-env-file server' [ "$(tr '\n' '|' <"$WORK/broker.args")" = "run|typesafe-api|--|$WORK/bin/bun|--no-install|--no-env-file|$WORK/repo/src/server.ts|" ]
check 'on, broker: the key reaches the server through the environment' env_is 'TYPESAFE_API_KEY=dummy-broker-key-for-tests'
check 'on, broker: the key is not an argument' no_key_in_argv
check 'on, broker: nothing is printed' silent

# --- switch off (the one-line copy): no key lookup of any kind ----------------------
TARGET="$OFF_LAUNCHER"
make_fixture
clean_markers
make_secrets
make_broker
run_launcher TYPESAFE_API_KEY=dummy-inherited-key --
check 'off: starts' child_ran
check 'off: switch is off' env_is 'DESKTOP_OPS_JEV_PATH=off'
check 'off: no key in the child environment' env_lacks TYPESAFE_API_KEY
check 'off: the secrets file was not read' [ ! -e "$WORK/secrets.sourced" ]
check 'off: the secret broker was not invoked' [ ! -e "$WORK/broker.args" ]
check 'off: no other secret in the child environment' env_lacks OTHER_SECRET
check 'off: argv is exactly: --no-install --no-env-file <repo>/src/server.ts' [ "$(tr '\n' '|' <"$WORK/child.args")" = "--no-install|--no-env-file|$WORK/repo/src/server.ts|" ]
check 'off: nothing is printed' silent
check 'off: driver command is the sibling S1 launcher' env_is "DESKTOP_OPS_DRIVER_CMD=$REAL_OFF/computer-use-mcp.sh"

# With the line set to off, the environment cannot turn it back on either.
make_fixture
clean_markers
make_secrets
make_broker
run_launcher DESKTOP_OPS_JEV_PATH=on TYPESAFE_API_KEY=dummy-inherited-key --
check 'off: inherited DESKTOP_OPS_JEV_PATH=on is forced back to off' env_is 'DESKTOP_OPS_JEV_PATH=off'
check 'off: inherited TYPESAFE_API_KEY is not passed on' env_lacks TYPESAFE_API_KEY
check 'off, inherited on: the secrets file was not read' [ ! -e "$WORK/secrets.sourced" ]
check 'off, inherited on: the secret broker was not invoked' [ ! -e "$WORK/broker.args" ]
TARGET="$LAUNCHER"

# --- static ---------------------------------------------------------------------
no_npx() { ! grep -Eq '(^|[^[:alnum:]_])npx([^[:alnum:]_]|$)' "$LAUNCHER"; }
# The key may be expanded only inside the one command substitution that reads
# it from the secrets file, or tested for emptiness; never echoed or passed as
# an argument.
key_uses_are_known() {
  [ "$(grep -c 'TYPESAFE_API_KEY' "$LAUNCHER")" = "$(grep -Ec '^ *#.*TYPESAFE_API_KEY|^ *unset TYPESAFE_API_KEY$|cached_key="\$\(\. "\$\{HOME\}/\.env\.secrets" 2>/dev/null; printf .%s. "\$\{TYPESAFE_API_KEY:-\}"\)"$|^ *export TYPESAFE_API_KEY="\$cached_key"$|^ *if \[ -n "\$\{TYPESAFE_API_KEY:-\}" \]; then$' "$LAUNCHER")" ]
}
no_env_file_flag() { [ "$(grep -c -- '--no-install --no-env-file' "$LAUNCHER")" -ge 1 ] && ! grep -Eq 'exec .*"\$bun" --no-install "\$repo' "$LAUNCHER"; }
check 'launcher has no npx' no_npx
check 'every use of the key in the launcher is one of the known safe forms' key_uses_are_known
check 'every way the server is started passes --no-env-file' no_env_file_flag
policy_is_additive_only() {
  python3 - "$TESTS_DIR/../policy.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
allowed = {"version", "deny_apps", "deny_app_prefixes", "deny_hosts", "irreversible_keywords", "browsers"}
assert data["version"] == 1
assert set(data) <= allowed, set(data) - allowed
for key in allowed - {"version"}:
    assert all(isinstance(v, str) and v for v in data.get(key, []))
PY
}
check 'policy.json parses and holds only additive keys' policy_is_additive_only

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
