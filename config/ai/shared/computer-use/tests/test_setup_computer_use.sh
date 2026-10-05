#!/bin/bash

# Tests for script/common/setup_computer_use.sh. The script is copied into a
# throwaway dotfile tree with a throwaway HOME; `claude` and `agy` are stubs
# that keep a registry file. No real registry or config is touched and no MCP
# server is started.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# SETUP_COMPUTER_USE_SCRIPT lets the same checks run against another copy.
SCRIPT_SRC="${SETUP_COMPUTER_USE_SCRIPT:-$TESTS_DIR/../../../../../script/common/setup_computer_use.sh}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/setup-computer-use-test.XXXXXX")"
WORK="$(cd "$WORK" && pwd)"
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

PYTHON_REAL="$(python3 -c 'import sys; print(sys.executable)')"
DOT="$WORK/dot"
SETUP="$DOT/script/common/setup_computer_use.sh"
SHARED="$DOT/config/ai/shared/computer-use"
OC_JSON="$DOT/config/opencode/opencode.json"
TOML="$WORK/home/.codex/config.toml"

# make_fixture: pristine tree, both launchers present, empty registries.
make_fixture() {
  rm -rf "${WORK:?}/dot" "${WORK:?}/home" "${WORK:?}/bin" "${WORK:?}/reg" "${WORK:?}/out" "${WORK:?}/err"
  mkdir -p "$DOT/script/common" "$SHARED" "$DOT/config/opencode" "$WORK/home/.codex" "$WORK/bin" "$WORK/reg"
  cp "$SCRIPT_SRC" "$SETUP"
  chmod +x "$SETUP"
  for launcher in computer-use-mcp.sh desktop-ops-mcp.sh; do
    printf '#!/bin/sh\nexit 0\n' >"$SHARED/$launcher"
    chmod +x "$SHARED/$launcher"
  done
  ln -s "$PYTHON_REAL" "$WORK/bin/python3"
  # Stub CLIs: `<cli> mcp add [--scope user] NAME [--] LAUNCHER`, `<cli> mcp remove [--scope user] NAME`.
  for cli in claude agy; do
    cat >"$WORK/bin/$cli" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >>"$WORK/reg/$cli.log"
[ "\$1" = "mcp" ] || exit 2
verb="\$2"
shift 2
[ "\$1" = "--scope" ] && shift 2
name="\$1"
case "\$verb" in
  add) touch "$WORK/reg/$cli.\$name" ;;
  remove) [ -e "$WORK/reg/$cli.\$name" ] || exit 1; rm "$WORK/reg/$cli.\$name" ;;
  *) exit 2 ;;
esac
STUB
    chmod +x "$WORK/bin/$cli"
  done
  cat >"$TOML" <<'TOML'
model = "gpt-5"
# a comment that must survive   

[mcp_servers.other]
command = "/usr/bin/true"
args = ["a",   "b"]
TOML
  chmod 600 "$TOML"
  python3 - "$OC_JSON" <<'PY'
import json, sys
data = {"$schema": "https://opencode.ai/config.json", "permission": {"edit": "ask", "bash": {"*": "ask"}}, "mcp": {"other": {"type": "local", "command": ["/usr/bin/true"], "enabled": True}}, "名稱": "測試"}
open(sys.argv[1], "wb").write((json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
PY
  cp "$TOML" "$WORK/pristine.toml"
  cp "$OC_JSON" "$WORK/pristine.json"
}

# run_setup <args...>: RC holds the exit code; stdout in $WORK/out, stderr in $WORK/err.
run_setup() {
  /usr/bin/env -i HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" "$SETUP" "$@" >"$WORK/out" 2>"$WORK/err"
  RC=$?
}

registered() { [ -e "$WORK/reg/$1.$2" ]; }
not_registered() { [ ! -e "$WORK/reg/$1.$2" ]; }
toml_has() { grep -qF "[mcp_servers.$1]" "$TOML"; }
toml_lacks() { ! grep -qF "[mcp_servers.$1]" "$TOML"; }
json_state() {
  # json_state NAME -> "mcp=<yes|no> rule=<yes|no>"
  python3 - "$OC_JSON" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
name = sys.argv[2]
print("mcp=%s rule=%s" % ("yes" if name in data.get("mcp", {}) else "no", "yes" if data.get("permission", {}).get(name + "_*") == "ask" else "no"))
PY
}
all_four_have() { registered claude "$1" && registered agy "$1" && toml_has "$1" && [ "$(json_state "$1")" = "mcp=yes rule=yes" ]; }
all_four_lack() { not_registered claude "$1" && not_registered agy "$1" && toml_lacks "$1" && [ "$(json_state "$1")" = "mcp=no rule=no" ]; }
same() { cmp -s "$1" "$2"; }
no_cli_calls() { [ ! -e "$WORK/reg/claude.log" ] && [ ! -e "$WORK/reg/agy.log" ]; }

# --- argument handling -----------------------------------------------------------
make_fixture
run_setup --server bogus --apply
check 'unknown server: exit 2' [ "$RC" -eq 2 ]
check 'unknown server: nothing changed' same "$TOML" "$WORK/pristine.toml"
run_setup --frobnicate
check 'unknown flag: exit 2' [ "$RC" -eq 2 ]
run_setup --server
check '--server without a value: exit 2' [ "$RC" -eq 2 ]
check 'bad arguments never reach a CLI' no_cli_calls

# --- dry-run -----------------------------------------------------------------------
make_fixture
run_setup
check 'default is dry-run' grep -qx 'mode=dry-run' "$WORK/out"
check 'default dry-run covers open-computer-use' grep -q '^open-computer-use: ' "$WORK/out"
check 'default dry-run covers desktop-ops' grep -q '^desktop-ops: ' "$WORK/out"
check 'dry-run: config.toml untouched' same "$TOML" "$WORK/pristine.toml"
check 'dry-run: opencode.json untouched' same "$OC_JSON" "$WORK/pristine.json"
check 'dry-run: no CLI was called' no_cli_calls
run_setup --dry-run --server desktop-ops
no_s1_line() { ! grep -q 'open-computer-use' "$WORK/out"; }
check 'dry-run --server desktop-ops mentions only desktop-ops' no_s1_line

# --- S1 behaviour is unchanged: single-server output and byte-identical round trip ----
make_fixture
run_setup --apply --server open-computer-use
check 'S1 apply: exit 0' [ "$RC" -eq 0 ]
check 'S1 apply: all four runtimes list open-computer-use' all_four_have open-computer-use
check 'S1 apply: desktop-ops is not registered anywhere' all_four_lack desktop-ops
check 'S1 apply: stdout keeps the S1 shape' [ "$(sed -n '1p;2p;$p' "$WORK/out" | tr '\n' '|')" = "mode=apply|open-computer-use: $SHARED/computer-use-mcp.sh|registered open-computer-use for Claude/Codex/AGY/opencode|" ]
check 'S1 apply: Claude gets the S1 command line' grep -qx "mcp add --scope user open-computer-use -- $SHARED/computer-use-mcp.sh" "$WORK/reg/claude.log"
check 'S1 apply: config.toml keeps mode 600' [ "$(stat -f '%Lp' "$TOML")" = "600" ]
cp "$TOML" "$WORK/s1.toml"
cp "$OC_JSON" "$WORK/s1.json"
run_setup --apply --server open-computer-use
check 'S1 apply twice: config.toml unchanged' same "$TOML" "$WORK/s1.toml"
check 'S1 apply twice: opencode.json unchanged' same "$OC_JSON" "$WORK/s1.json"
run_setup --remove --server open-computer-use
check 'S1 remove: exit 0' [ "$RC" -eq 0 ]
check 'S1 round trip: config.toml byte-identical to pristine' same "$TOML" "$WORK/pristine.toml"
check 'S1 round trip: opencode.json byte-identical to pristine' same "$OC_JSON" "$WORK/pristine.json"
check 'S1 remove: gone from all four' all_four_lack open-computer-use

# --- desktop-ops on top of S1: independent apply and remove -------------------------
make_fixture
run_setup --server open-computer-use --apply
cp "$TOML" "$WORK/s1.toml"
cp "$OC_JSON" "$WORK/s1.json"
run_setup --server desktop-ops --apply
check 'desktop-ops apply: exit 0' [ "$RC" -eq 0 ]
check 'desktop-ops apply: all four runtimes list desktop-ops' all_four_have desktop-ops
check 'desktop-ops apply: open-computer-use still listed by all four' all_four_have open-computer-use
check 'desktop-ops apply: launcher is desktop-ops-mcp.sh' grep -qF "command = \"$SHARED/desktop-ops-mcp.sh\"" "$TOML"
check 'desktop-ops apply: Claude gets the desktop-ops command line' grep -qx "mcp add --scope user desktop-ops -- $SHARED/desktop-ops-mcp.sh" "$WORK/reg/claude.log"
no_s1_add_again() { [ "$(grep -c 'add.*open-computer-use' "$WORK/reg/claude.log")" = "1" ] && [ "$(grep -c 'add open-computer-use' "$WORK/reg/agy.log")" = "1" ]; }
check 'desktop-ops apply: the S1 registration was not touched' no_s1_add_again
run_setup --server=desktop-ops --remove
check 'desktop-ops remove: exit 0' [ "$RC" -eq 0 ]
check 'desktop-ops remove: all four still list open-computer-use' all_four_have open-computer-use
check 'desktop-ops remove: none of the four lists desktop-ops' all_four_lack desktop-ops
check 'desktop-ops round trip: config.toml byte-identical to before' same "$TOML" "$WORK/s1.toml"
check 'desktop-ops round trip: opencode.json byte-identical to before' same "$OC_JSON" "$WORK/s1.json"
run_setup --server desktop-ops --remove
check 'desktop-ops remove twice: still exit 0' [ "$RC" -eq 0 ]
check 'desktop-ops remove twice: config.toml still identical' same "$TOML" "$WORK/s1.toml"

# --- removing S1 leaves desktop-ops alone ---------------------------------------------
make_fixture
run_setup --apply
run_setup --server open-computer-use --remove
check 'S1 remove with both present: desktop-ops still listed by all four' all_four_have desktop-ops
check 'S1 remove with both present: open-computer-use gone' all_four_lack open-computer-use

# --- default (all) ----------------------------------------------------------------------
make_fixture
run_setup --apply
check 'all apply: exit 0' [ "$RC" -eq 0 ]
check 'all apply: open-computer-use in all four' all_four_have open-computer-use
check 'all apply: desktop-ops in all four' all_four_have desktop-ops
valid_configs() {
  python3 - "$TOML" "$OC_JSON" <<'PY'
import json, sys
json.load(open(sys.argv[2], encoding="utf-8"))
try:
    import tomllib
except ImportError:
    sys.exit(0)
data = tomllib.load(open(sys.argv[1], "rb"))
assert set(data["mcp_servers"]) == {"other", "open-computer-use", "desktop-ops"}, data["mcp_servers"]
PY
}
check 'all apply: both config files still parse' valid_configs
run_setup --remove
check 'all round trip: config.toml byte-identical to pristine' same "$TOML" "$WORK/pristine.toml"
check 'all round trip: opencode.json byte-identical to pristine' same "$OC_JSON" "$WORK/pristine.json"

# --- a missing launcher stops before anything is written -------------------------------
make_fixture
rm "$SHARED/desktop-ops-mcp.sh"
run_setup --server desktop-ops --apply
check 'missing desktop-ops launcher: exit 1' [ "$RC" -eq 1 ]
check 'missing desktop-ops launcher: no CLI was called' no_cli_calls
check 'missing desktop-ops launcher: config.toml untouched' same "$TOML" "$WORK/pristine.toml"
run_setup --apply
check 'missing desktop-ops launcher, --server all: exit 1 before any change' [ "$RC" -eq 1 ]
check 'missing desktop-ops launcher, --server all: S1 not half-applied' all_four_lack open-computer-use
run_setup --server open-computer-use --apply
check 'missing desktop-ops launcher: S1 alone still applies' all_four_have open-computer-use
run_setup --server desktop-ops --remove
check 'missing desktop-ops launcher: remove still works' [ "$RC" -eq 0 ]

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
