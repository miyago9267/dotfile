#!/bin/bash

# Tests for computer-use-mcp.sh. Everything runs against stubs in a temp dir:
# the real open-computer-use binary, codesign, and any GUI are never touched.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$TESTS_DIR/../computer-use-mcp.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/computer-use-mcp-test.XXXXXX")"
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
  # check <description> <command...>
  desc="$1"
  shift
  if "$@"; then ok "$desc"; else not_ok "$desc"; fi
}

# make_prefix <prefix dir> <package version> [with-node|no-node]
# Builds a fake npm global prefix that mirrors the real layout:
#   prefix/bin/open-computer-use -> ../lib/node_modules/open-computer-use/bin/open-computer-use
#   prefix/bin/node
# The fake child records its argv, environment, and own path instead of
# starting anything.
make_prefix() {
  prefix="$1"
  pkg="$prefix/lib/node_modules/open-computer-use"
  mkdir -p "$prefix/bin" "$pkg/bin" "$pkg/dist/Open Computer Use.app"
  printf '{\n  "name": "open-computer-use",\n  "version": "%s",\n  "bin": {}\n}\n' "$2" >"$pkg/package.json"
  cat >"$pkg/bin/open-computer-use" <<CHILD
#!/bin/sh
printf '%s\n' "\$@" >"$WORK/child.args"
printf '%s\n' "\$0" >"$WORK/child.self"
env >"$WORK/child.env"
exit 0
CHILD
  chmod +x "$pkg/bin/open-computer-use"
  ln -s ../lib/node_modules/open-computer-use/bin/open-computer-use "$prefix/bin/open-computer-use"
  if [ "${3:-with-node}" = "with-node" ]; then
    printf '#!/bin/sh\nexit 0\n' >"$prefix/bin/node"
    chmod +x "$prefix/bin/node"
  fi
}

# make_codesign <team id> [verify exit code]
# Like the real codesign, the stub prints -dv details on stderr; `--verify`
# returns the configured exit code.
make_codesign() {
  cat >"$WORK/codesign" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >>"$WORK/codesign.args"
if [ "\$1" = "--verify" ]; then
  exit ${2:-0}
fi
printf '%s\n' 'Identifier=com.example.stub' >&2
[ -n "$1" ] && printf 'TeamIdentifier=%s\n' "$1" >&2
exit 0
STUB
  chmod +x "$WORK/codesign"
}

# make_fixture <package version> <team id>: one prefix on PATH, nothing in ~/.nvm.
make_fixture() {
  rm -rf "$WORK/prefix" "$WORK/.nvm" "$WORK/nodebin" "$WORK/elsewhere" "$WORK"/child.* "$WORK/stderr" "$WORK/codesign.args"
  mkdir -p "$WORK/elsewhere"
  make_prefix "$WORK/prefix" "$1"
  make_codesign "$2"
}

# run_launcher [VAR=value ...] -- [launcher args...]
# Runs from an unrelated cwd with a minimal environment; RC holds the exit code.
run_launcher() {
  envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    envs+=("$1")
    shift
  done
  [ "$#" -gt 0 ] && shift
  (
    cd "$WORK/elsewhere" || exit 99
    /usr/bin/env -i HOME="$WORK" PATH="$WORK/prefix/bin:/usr/bin:/bin" \
      COMPUTER_USE_MCP_CODESIGN="$WORK/codesign" ${envs[@]+"${envs[@]}"} \
      "$LAUNCHER" "$@" 2>"$WORK/stderr"
  )
  RC=$?
}

child_ran() { [ -e "$WORK/child.args" ]; }
child_not_run() { [ ! -e "$WORK/child.args" ]; }
first_arg_is_mcp() { [ "$(sed -n 1p "$WORK/child.args" 2>/dev/null)" = "mcp" ]; }
one_line_stderr() { [ "$(wc -l <"$WORK/stderr" | tr -d ' ')" = "1" ]; }

# --- happy path -------------------------------------------------------------
make_fixture 0.3.6 J9P29FA5BX
run_launcher --
check 'happy path: exit 0' [ "$RC" -eq 0 ]
check 'happy path: child executed' child_ran
check 'happy path: first argument is mcp' first_arg_is_mcp
REAL_WORK="$(cd -P "$WORK" && pwd -P)"
APP_SUFFIX='lib/node_modules/open-computer-use/dist/Open Computer Use.app'
check 'happy path: codesign -dv asked about the bundled app' \
  grep -qx -- "-dv --verbose=2 $REAL_WORK/prefix/$APP_SUFFIX" "$WORK/codesign.args"
check 'happy path: codesign --verify --strict ran on the bundled app' \
  grep -qx -- "--verify --strict $REAL_WORK/prefix/$APP_SUFFIX" "$WORK/codesign.args"

make_fixture 0.3.6 J9P29FA5BX
run_launcher COMPUTER_USE_MCP_BIN="$WORK/prefix/bin/open-computer-use" PATH=/usr/bin:/bin --
check 'explicit binary seam: child executed with mcp first' first_arg_is_mcp

# A caller-supplied subcommand must not replace `mcp`; js/repl never start.
make_fixture 0.3.6 J9P29FA5BX
run_launcher -- js 'console.log(1)'
check 'caller args: first argument stays mcp' first_arg_is_mcp
make_fixture 0.3.6 J9P29FA5BX
run_launcher -- repl
check 'caller args (repl): first argument stays mcp' first_arg_is_mcp

# --- (g) environment scrub --------------------------------------------------
make_fixture 0.3.6 J9P29FA5BX
run_launcher OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS=1 \
  OPEN_COMPUTER_USE_NATIVE_COMMAND=/tmp/evil OPEN_COMPUTER_USE_=x KEEP_ME=1 --
check 'env scrub: child executed' child_ran
no_ocu_env() { [ -s "$WORK/child.env" ] && ! grep -q '^OPEN_COMPUTER_USE_' "$WORK/child.env"; }
check 'env scrub: child sees no OPEN_COMPUTER_USE_* variable' no_ocu_env
check 'env scrub: unrelated variables are kept' grep -qx 'KEEP_ME=1' "$WORK/child.env"

# --- (h) fail closed ----------------------------------------------------------
make_fixture 0.3.5 J9P29FA5BX
run_launcher --
check 'wrong version: non-zero exit' [ "$RC" -ne 0 ]
check 'wrong version: child not executed' child_not_run
check 'wrong version: one-line stderr message' one_line_stderr
check 'wrong version: message names the version' grep -q "version is '0.3.5'" "$WORK/stderr"

make_fixture 0.3.6 EVILTEAM00
run_launcher --
check 'wrong Team ID: non-zero exit' [ "$RC" -ne 0 ]
check 'wrong Team ID: child not executed' child_not_run
check 'wrong Team ID: one-line stderr message' one_line_stderr
check 'wrong Team ID: message names the team' grep -q "TeamIdentifier is 'EVILTEAM00'" "$WORK/stderr"

make_fixture 0.3.6 ''
run_launcher --
check 'unsigned app (no Team ID): non-zero exit' [ "$RC" -ne 0 ]
check 'unsigned app (no Team ID): child not executed' child_not_run

make_fixture 0.3.6 J9P29FA5BX
rm -rf "$WORK/prefix/lib/node_modules/open-computer-use/dist"
run_launcher --
check 'missing app bundle: non-zero exit' [ "$RC" -ne 0 ]
check 'missing app bundle: child not executed' child_not_run

make_fixture 0.3.6 J9P29FA5BX
run_launcher COMPUTER_USE_MCP_CODESIGN="$WORK/no-such-codesign" --
check 'missing codesign: non-zero exit' [ "$RC" -ne 0 ]
check 'missing codesign: child not executed' child_not_run

make_fixture 0.3.6 J9P29FA5BX
run_launcher PATH=/usr/bin:/bin --
check 'missing binary (not on PATH): non-zero exit' [ "$RC" -ne 0 ]
check 'missing binary (not on PATH): child not executed' child_not_run
check 'missing binary (not on PATH): one-line stderr message' one_line_stderr

make_fixture 0.3.6 J9P29FA5BX
run_launcher COMPUTER_USE_MCP_BIN="$WORK/nope/open-computer-use" --
check 'missing binary (explicit path): non-zero exit' [ "$RC" -ne 0 ]
check 'missing binary (explicit path): child not executed' child_not_run

# --- signature verification ---------------------------------------------------
make_fixture 0.3.6 J9P29FA5BX
make_codesign J9P29FA5BX 3
run_launcher --
check 'codesign --verify fails: non-zero exit' [ "$RC" -ne 0 ]
check 'codesign --verify fails: child not executed' child_not_run
check 'codesign --verify fails: one-line stderr message' one_line_stderr
check 'codesign --verify fails: message names the signature' grep -q 'signature' "$WORK/stderr"

# --- binary resolution --------------------------------------------------------
child_self_is() { [ "$(cat "$WORK/child.self" 2>/dev/null)" = "$1" ]; }
child_path_starts_with() { grep -q "^PATH=$1:" "$WORK/child.env" 2>/dev/null; }
NVM="$WORK/.nvm/versions/node"

# Not on PATH: fall back to the newest ~/.nvm node version whose package matches
# the pin. v24 holds another version; v9 must lose to v22 numerically.
make_fixture 0.3.6 J9P29FA5BX
make_prefix "$NVM/v9.0.0" 0.3.6
make_prefix "$NVM/v22.3.0" 0.3.6
make_prefix "$NVM/v24.0.0" 0.3.5
run_launcher PATH=/usr/bin:/bin --
check 'nvm fallback: exit 0' [ "$RC" -eq 0 ]
check 'nvm fallback: newest matching version is executed' \
  child_self_is "$REAL_WORK/.nvm/versions/node/v22.3.0/lib/node_modules/open-computer-use/bin/open-computer-use"
check 'nvm fallback: first argument is mcp' first_arg_is_mcp
check 'nvm fallback: sibling node directory is first on the child PATH' \
  child_path_starts_with "$NVM/v22.3.0/bin"

make_fixture 0.3.6 J9P29FA5BX
make_prefix "$NVM/v24.0.0" 0.3.5
run_launcher PATH=/usr/bin:/bin --
check 'nvm fallback, no version matches the pin: exit 127' [ "$RC" -eq 127 ]
check 'nvm fallback, no version matches the pin: child not executed' child_not_run

# PATH wins over ~/.nvm when it resolves to an absolute executable.
make_fixture 0.3.6 J9P29FA5BX
make_prefix "$NVM/v22.3.0" 0.3.6
run_launcher PATH="/usr/bin:$WORK/prefix/bin:/bin" --
check 'PATH entry preferred over nvm fallback' \
  child_self_is "$REAL_WORK/prefix/lib/node_modules/open-computer-use/bin/open-computer-use"
check 'PATH entry: sibling node directory is first on the child PATH' \
  child_path_starts_with "$WORK/prefix/bin"

# A stray executable reached through a relative PATH entry has no pinned package
# around it (macOS sh reports it as an absolute path); it must never be exec'd.
make_fixture 0.3.6 J9P29FA5BX
mkdir -p "$WORK/elsewhere/relbin"
cp "$WORK/prefix/lib/node_modules/open-computer-use/bin/open-computer-use" "$WORK/elsewhere/relbin/open-computer-use"
run_launcher PATH=relbin:/usr/bin:/bin --
check 'stray binary via relative PATH: non-zero exit' [ "$RC" -ne 0 ]
check 'stray binary via relative PATH: child not executed' child_not_run

# --- node for the `#!/usr/bin/env node` bin script ------------------------------
make_fixture 0.3.6 J9P29FA5BX
rm -f "$WORK/prefix/bin/node"
run_launcher --
check 'no node next to the binary or on PATH: non-zero exit' [ "$RC" -ne 0 ]
check 'no node next to the binary or on PATH: child not executed' child_not_run
check 'no node next to the binary or on PATH: one-line stderr message' one_line_stderr
check 'no node next to the binary or on PATH: message names node' grep -q 'node' "$WORK/stderr"

make_fixture 0.3.6 J9P29FA5BX
rm -f "$WORK/prefix/bin/node"
mkdir -p "$WORK/nodebin"
printf '#!/bin/sh\nexit 0\n' >"$WORK/nodebin/node"
chmod +x "$WORK/nodebin/node"
run_launcher PATH="$WORK/prefix/bin:$WORK/nodebin:/usr/bin:/bin" --
check 'no sibling node but node on PATH: child executed' first_arg_is_mcp

# --- static guards ------------------------------------------------------------
no_ocu_seam() { [ -f "$LAUNCHER" ] && ! grep -Eq '\$\{?OPEN_COMPUTER_USE_' "$LAUNCHER"; }
check 'launcher reads no OPEN_COMPUTER_USE_* variable as a seam' no_ocu_seam
check 'launcher is executable' [ -x "$LAUNCHER" ]

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
