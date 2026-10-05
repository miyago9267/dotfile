#!/bin/bash

# Tests for script/common/setup_computer_use.sh. The script is copied into a
# throwaway dotfile tree with a throwaway HOME; `claude` and `agy` are stubs
# that keep a registry file. No real registry or config is touched and no MCP
# server is started.
#
# The --install checks also stub npm, git, bun, swiftc, codesign and spctl and
# run with a PATH that cannot reach the real ones, so nothing is installed,
# cloned or built and the network is never used.
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
  make_install_fixture
}

PIN_VERSION='0.3.6'
PIN_INTEGRITY='sha512-pGNfWBBefl5qzQMo6rkC/e28sOfeczTQ0hEKkYn2sXwti38uz+fC4Y0oBdtnNACemsNVR06Dzp6SozJjkpkbSg=='
PIN_TEAM='J9P29FA5BX'
PIN_COMMIT='864aa801ca0bde84bf29fae0d63fc7be0d195796'
REPO_URL='git@github.com:miyago9267/desktop-ops.git'
REPO="$WORK/home/Project/Active/Tools/desktop-ops"
NVM_PREFIX="$WORK/home/.nvm/versions/node/v24.0.0"
CALLS="$WORK/reg/calls.log"
CTL="$WORK/ctl"
SYS="$WORK/sys"

# make_install_fixture: stub tools, a verified driver and a complete service
# checkout whose HEAD contains the pin. Each stub logs "<tool> <args>" to
# $CALLS and reads its behaviour from one-line files in $CTL.
make_install_fixture() {
  rm -rf "$CTL" "$SYS" "$WORK/repo-template"
  mkdir -p "$CTL" "$SYS" "$WORK/repo-template/src" "$WORK/repo-template/helper"
  for util in dirname basename readlink sed head tail sort cut cat mkdir rm touch chmod grep tr ls ln uname cp tee; do
    for util_dir in /usr/bin /bin; do
      [ -x "$util_dir/$util" ] && ln -s "$util_dir/$util" "$SYS/$util" && break
    done
  done

  : >"$WORK/repo-template/src/server.ts"
  : >"$WORK/repo-template/bun.lock"
  : >"$WORK/repo-template/helper/desktop-ops-helper.swift"
  cat >"$WORK/repo-template/helper/build.sh" <<'BUILD'
#!/bin/sh
d="$(cd "$(dirname "$0")" && pwd)"
swiftc -O "$d/desktop-ops-helper.swift" -o "$d/desktop-ops-helper" && chmod 700 "$d/desktop-ops-helper"
BUILD
  chmod +x "$WORK/repo-template/helper/build.sh"

  printf '%s\n' "$PIN_INTEGRITY" >"$CTL/integrity"
  printf '%s\n' "$PIN_VERSION" >"$CTL/npm_version"
  printf '%s\n' "$PIN_TEAM" >"$CTL/team"
  echo 0 >"$CTL/verify_rc"
  echo 'Notarized Developer ID' >"$CTL/spctl_source"
  echo 0 >"$CTL/spctl_rc"
  printf '%s\n' "$REPO_URL" >"$CTL/origin"
  echo 0 >"$CTL/pin_is_ancestor"
  echo 0 >"$CTL/head_is_ancestor"
  : >"$CTL/status"
  printf '%s\n' "$PIN_COMMIT" >"$CTL/head"

  # mkdriver.sh VERSION: the npm package layout under a fake nvm prefix.
  cat >"$CTL/mkdriver.sh" <<STUB
#!/bin/sh
root="$NVM_PREFIX/lib/node_modules/open-computer-use"
mkdir -p "\$root/bin" "\$root/dist/Open Computer Use.app" "$NVM_PREFIX/bin"
printf '{\n  "name": "open-computer-use",\n  "version": "%s"\n}\n' "\$1" >"\$root/package.json"
printf '#!/bin/sh\nexit 0\n' >"\$root/bin/open-computer-use"
chmod +x "\$root/bin/open-computer-use"
ln -sf ../lib/node_modules/open-computer-use/bin/open-computer-use "$NVM_PREFIX/bin/open-computer-use"
STUB
  chmod +x "$CTL/mkdriver.sh"

  cat >"$WORK/bin/npm" <<STUB
#!/bin/sh
printf 'npm %s\n' "\$*" >>"$CALLS"
case "\$1" in
  view) [ "\$*" = "view open-computer-use@$PIN_VERSION dist.integrity" ] || exit 2; cat "$CTL/integrity" ;;
  i | install)
    shift
    [ "\$*" = "-g --ignore-scripts open-computer-use@$PIN_VERSION" ] || exit 2
    "$CTL/mkdriver.sh" "\$(cat "$CTL/npm_version")" ;;
  *) exit 2 ;;
esac
STUB
  cat >"$WORK/bin/codesign" <<STUB
#!/bin/sh
printf 'codesign %s\n' "\$*" >>"$CALLS"
case "\$1" in
  -dv) printf 'Identifier=com.example\nTeamIdentifier=%s\n' "\$(cat "$CTL/team")" >&2 ;;
  --verify) exit "\$(cat "$CTL/verify_rc")" ;;
  *) exit 2 ;;
esac
STUB
  cat >"$WORK/bin/spctl" <<STUB
#!/bin/sh
printf 'spctl %s\n' "\$*" >>"$CALLS"
printf 'app: accepted\nsource=%s\n' "\$(cat "$CTL/spctl_source")" >&2
exit "\$(cat "$CTL/spctl_rc")"
STUB
  cat >"$WORK/bin/git" <<STUB
#!/bin/sh
printf 'git %s\n' "\$*" >>"$CALLS"
[ "\$1" = "-C" ] && shift 2
case "\$1" in
  clone)
    [ -e "$CTL/clone_fails" ] && exit 128
    mkdir -p "\$3/.git"
    cp -R "$WORK/repo-template/." "\$3/"
    printf '%s\n' "\$2" >"$CTL/origin"
    echo default-branch-head >"$CTL/head"
    echo 0 >"$CTL/pin_is_ancestor" ;;
  checkout) [ "\$2" = "--detach" ] || exit 2; printf '%s\n' "\$3" >"$CTL/head" ;;
  config) [ "\$*" = "config --get remote.origin.url" ] || exit 2; cat "$CTL/origin" ;;
  rev-parse) cat "$CTL/head" ;;
  merge-base)
    [ "\$2" = "--is-ancestor" ] || exit 2
    if [ "\$4" = "HEAD" ]; then exit "\$(cat "$CTL/pin_is_ancestor")"; fi
    exit "\$(cat "$CTL/head_is_ancestor")" ;;
  status) cat "$CTL/status" ;;
  fetch | cat-file) exit 0 ;;
  merge) [ "\$2" = "--ff-only" ] || exit 2; echo 0 >"$CTL/pin_is_ancestor" ;;
  *) exit 2 ;;
esac
STUB
  cat >"$WORK/bin/bun" <<STUB
#!/bin/sh
printf 'bun %s\n' "\$*" >>"$CALLS"
[ "\$*" = "install --frozen-lockfile --ignore-scripts" ] || exit 2
mkdir -p node_modules/@modelcontextprotocol/sdk node_modules/.bin
STUB
  cat >"$WORK/bin/swiftc" <<STUB
#!/bin/sh
printf 'swiftc %s\n' "\$*" >>"$CALLS"
while [ "\$#" -gt 1 ]; do
  [ "\$1" = "-o" ] && : >"\$2"
  shift
done
STUB
  chmod +x "$WORK/bin/npm" "$WORK/bin/codesign" "$WORK/bin/spctl" "$WORK/bin/git" "$WORK/bin/bun" "$WORK/bin/swiftc"

  "$CTL/mkdriver.sh" "$PIN_VERSION"
  mkdir -p "$REPO/.git"
  cp -R "$WORK/repo-template/." "$REPO/"
  touch -t 202601010000 "$REPO/bun.lock" "$REPO/helper/desktop-ops-helper.swift"
  mkdir -p "$REPO/node_modules/@modelcontextprotocol/sdk" "$REPO/node_modules/.bin"
  printf '#!/bin/sh\n' >"$REPO/helper/desktop-ops-helper"
  chmod 700 "$REPO/helper/desktop-ops-helper"
  # A secrets file the script must never read.
  printf 'TYPESAFE_API_KEY=CANARY-do-not-read\n' >"$WORK/home/.env.secrets"
}

# fresh_mac: neither the driver nor the service repo is there yet.
fresh_mac() {
  rm -rf "$WORK/home/.nvm" "$WORK/home/Project"
  echo 1 >"$CTL/pin_is_ancestor"
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

# ======================================================================================
# --install: driver, service repo, dependencies, helper
# ======================================================================================

# run_install <args...>: like run_setup, but the PATH holds only the stubs and a
# few coreutils, so a real npm/git/bun/swiftc/codesign/spctl is unreachable.
run_install() {
  rm -f "$CALLS"
  /usr/bin/env -i HOME="$WORK/home" PATH="$WORK/bin:$SYS" "$SETUP" "$@" >"$WORK/out" 2>"$WORK/err"
  RC=$?
}
called() { grep -qE -- "$1" "$CALLS" 2>/dev/null; }
not_called() { ! called "$1"; }
GIT_MUTATION='^git (-C [^ ]+ )?(clone|checkout|fetch|merge|pull|reset|clean|stash|commit|push|rebase|switch|restore)( |$)'
MUTATION="^npm (i|install|rm|uninstall|update) |$GIT_MUTATION|^bun |^swiftc "
no_mutation() { not_called "$MUTATION" && no_cli_calls; }
no_git_mutation() { not_called "$GIT_MUTATION"; }
failed() { [ "$RC" -ne 0 ]; }
says() { grep -qiE -- "$1" "$WORK/out" "$WORK/err"; }
configs_untouched() { same "$TOML" "$WORK/pristine.toml" && same "$OC_JSON" "$WORK/pristine.json"; }
no_secret_leak() { ! grep -q 'CANARY' "$WORK/out" "$WORK/err"; }
line_of() { grep -nE -- "$1" "$CALLS" 2>/dev/null | head -n 1 | cut -d: -f1; }
in_order() { a="$(line_of "$1")" && b="$(line_of "$2")" && [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; }

# --- arguments ------------------------------------------------------------------------
make_fixture
run_install --install --apply
check '--install with --apply: exit 2' [ "$RC" -eq 2 ]
run_install --remove --install
check '--install with --remove: exit 2' [ "$RC" -eq 2 ]
check '--install with another action: nothing ran' no_mutation

# --- dry-run issues no mutating command --------------------------------------------------
make_fixture
fresh_mac
run_install --dry-run --install
check 'dry-run install on a fresh Mac: exit 0' [ "$RC" -eq 0 ]
check 'dry-run install on a fresh Mac: no mutating command' no_mutation
check 'dry-run install on a fresh Mac: repo not created' [ ! -e "$REPO" ]
check 'dry-run install on a fresh Mac: driver not created' [ ! -e "$WORK/home/.nvm" ]
check 'dry-run install on a fresh Mac: configs untouched' configs_untouched
check 'dry-run install: plan names the pinned npm install' says "would run: npm i(nstall)? -g --ignore-scripts open-computer-use@$PIN_VERSION"
check 'dry-run install: plan names the clone' says "would run: git clone $REPO_URL "
check 'dry-run install: plan names the pinned commit' says "$PIN_COMMIT"
run_install --install --dry-run
check '--install --dry-run (other order): exit 0 and no mutating command' eval '[ "$RC" -eq 0 ] && no_mutation && [ ! -e "$REPO" ]'
make_fixture
echo 1 >"$CTL/pin_is_ancestor"
run_install --dry-run --install
check 'dry-run install, repo behind and clean: no mutating command' eval '[ "$RC" -eq 0 ] && no_mutation'
make_fixture
fresh_mac
run_install --dry-run
check 'plain dry-run: no mutating command' no_mutation
check 'plain dry-run: exit 0 and configs untouched' eval '[ "$RC" -eq 0 ] && configs_untouched'

# --- driver ------------------------------------------------------------------------------
make_fixture
run_install --install --server open-computer-use
check 'driver already installed and valid: exit 0' [ "$RC" -eq 0 ]
check 'driver already installed and valid: npm never called' not_called '^npm '
check 'driver already installed and valid: Team ID and notarization were checked' eval 'called "^codesign -dv" && called "^spctl "'
check '--server open-computer-use: the service repo is not looked at' not_called '^git '

make_fixture
fresh_mac
echo 'sha512-AAAAnotthepinnedvalue==' >"$CTL/integrity"
run_install --install
check 'integrity mismatch: non-zero exit' failed
check 'integrity mismatch: no install command issued' not_called '^npm (i|install) '
check 'integrity mismatch: stops before the repo step' not_called '^git '
check 'integrity mismatch: message says so' says 'integrity'
check 'integrity mismatch: nothing mutated' no_mutation

make_fixture
fresh_mac
: >"$CTL/integrity"
run_install --install
check 'registry returns no integrity: non-zero and no install' eval 'failed && not_called "^npm (i|install) "'

make_fixture
fresh_mac
echo 'EVILTEAM00' >"$CTL/team"
run_install --install
check 'Team ID mismatch after install: non-zero exit' failed
check 'Team ID mismatch after install: the install did run' called "^npm (i|install) -g --ignore-scripts open-computer-use@$PIN_VERSION\$"
check 'Team ID mismatch after install: stops before the repo step' not_called '^git |^bun |^swiftc '
check 'Team ID mismatch after install: message names the Team ID' says 'TeamIdentifier'

make_fixture
fresh_mac
echo 'Unnotarized Developer ID' >"$CTL/spctl_source"
run_install --install
check 'not notarized after install: non-zero exit' failed
check 'not notarized after install: stops before the repo step' not_called '^git |^bun |^swiftc '
check 'not notarized after install: message says so' says 'notariz'

make_fixture
fresh_mac
echo 3 >"$CTL/spctl_rc"
run_install --install
check 'spctl rejects the app: non-zero and stops before the repo step' eval 'failed && not_called "^git |^bun |^swiftc "'

make_fixture
fresh_mac
echo 1 >"$CTL/verify_rc"
run_install --install
check 'codesign --verify fails after install: non-zero and stops before the repo step' eval 'failed && not_called "^git |^bun |^swiftc "'

make_fixture
fresh_mac
echo '0.3.7' >"$CTL/npm_version"
run_install --install
check 'npm delivers another version: non-zero and stops before the repo step' eval 'failed && not_called "^git |^bun |^swiftc "'

make_fixture
echo 'EVILTEAM00' >"$CTL/team"
run_install --install
check 'installed driver fails verification: non-zero, no reinstall, no repo step' eval 'failed && not_called "^npm (i|install) " && not_called "^git "'

make_fixture
"$CTL/mkdriver.sh" 0.3.5
run_install --install --server open-computer-use
check 'another version installed: integrity checked before the install' in_order '^npm view ' '^npm (i|install) '
check 'another version installed: ends with the pinned version verified' eval '[ "$RC" -eq 0 ] && grep -q "\"version\": \"$PIN_VERSION\"" "$NVM_PREFIX/lib/node_modules/open-computer-use/package.json"'

# --- service repo ------------------------------------------------------------------------
make_fixture
fresh_mac
run_install --install
check 'fresh Mac: exit 0' [ "$RC" -eq 0 ]
check 'fresh Mac: integrity is checked before the install' in_order '^npm view ' '^npm (i|install) '
check 'fresh Mac: driver is verified before the clone' in_order '^spctl ' '^git clone '
check 'fresh Mac: clones the private repo into place' called "^git clone $REPO_URL $REPO\$"
check 'fresh Mac: checks out the pinned commit' called "^git -C $REPO checkout --detach $PIN_COMMIT\$"
check 'fresh Mac: installs dependencies frozen and without scripts' called '^bun install --frozen-lockfile --ignore-scripts$'
check 'fresh Mac: builds the helper' eval 'called "^swiftc " && [ -x "$REPO/helper/desktop-ops-helper" ]'
check 'fresh Mac: no registration happened' eval 'no_cli_calls && configs_untouched'
check 'fresh Mac: prints the permission step' says 'open-computer-use doctor'
check 'fresh Mac: prints the key step without the key' eval 'says "TYPESAFE_API_KEY" && no_secret_leak'
check 'fresh Mac: prints the apply and restart steps' eval 'says "setup_computer_use.sh --apply" && says "restart"'
run_install --install
check 'second run after a fresh install: exit 0 and nothing to do' eval '[ "$RC" -eq 0 ] && no_mutation'
run_setup --apply
check 'apply after a fresh install: both servers registered' eval '[ "$RC" -eq 0 ] && all_four_have open-computer-use && all_four_have desktop-ops'

make_fixture
fresh_mac
: >"$CTL/clone_fails"
run_install --install
check 'clone fails: non-zero, message, no dependency or build step' eval 'failed && says "clone" && not_called "^bun |^swiftc " && [ ! -e "$REPO" ]'
rm "$CTL/clone_fails"
run_install --install
check 'clone fails, then works: the next run completes' eval '[ "$RC" -eq 0 ] && [ -x "$REPO/helper/desktop-ops-helper" ]'

make_fixture
run_install --install
check 'repo present with the pin as ancestor: exit 0' [ "$RC" -eq 0 ]
check 'repo present with the pin as ancestor: no git mutation' no_git_mutation
check 'repo present, deps and helper current: no mutating command at all' no_mutation

make_fixture
echo 'https://github.com/miyago9267/desktop-ops.git' >"$CTL/origin"
run_install --install
check 'origin in https form is accepted' eval '[ "$RC" -eq 0 ] && no_mutation'

make_fixture
echo 1 >"$CTL/pin_is_ancestor"
run_install --install
check 'repo behind and clean: exit 0' [ "$RC" -eq 0 ]
check 'repo behind and clean: fetches' called "^git -C $REPO fetch origin\$"
check 'repo behind and clean: fast-forwards to the pin only' called "^git -C $REPO merge --ff-only $PIN_COMMIT\$"
check 'repo behind and clean: fetch comes before the fast-forward' in_order ' fetch origin$' ' merge --ff-only '
check 'repo behind and clean: never resets, cleans or stashes' not_called '^git .* (reset|clean|stash|checkout)( |$)'

make_fixture
echo 1 >"$CTL/pin_is_ancestor"
echo ' M src/server.ts' >"$CTL/status"
run_install --install
check 'repo behind and dirty: non-zero exit' failed
check 'repo behind and dirty: mutates nothing' no_mutation
check 'repo behind and dirty: says what to do' says 'commit|stash'

make_fixture
echo 1 >"$CTL/pin_is_ancestor"
echo 1 >"$CTL/head_is_ancestor"
run_install --install
check 'repo diverged from the pin: non-zero and no merge' eval 'failed && not_called " (merge|reset|checkout) "'

for origin in 'git@github.com:evil/desktop-ops.git' 'https://github.com.evil.example/miyago9267/desktop-ops.git' 'https://token@github.com/miyago9267/desktop-ops.git' ''; do
  make_fixture
  printf '%s\n' "$origin" >"$CTL/origin"
  run_install --install
  check "wrong origin '$origin': refuses and mutates nothing" eval 'failed && no_mutation && says "origin"'
done

make_fixture
rm -rf "$REPO/.git"
run_install --install
check 'directory exists but is not a git repo: refuses and mutates nothing' eval 'failed && no_mutation'

# --- dependencies and helper run only when needed ------------------------------------------
make_fixture
rm -rf "$REPO/node_modules"
run_install --install
check 'node_modules missing: bun install runs, helper is not rebuilt' eval '[ "$RC" -eq 0 ] && called "^bun install --frozen-lockfile --ignore-scripts\$" && not_called "^swiftc "'

make_fixture
touch -t 202501010000 "$REPO/node_modules" "$REPO/node_modules/.bin"
run_install --install
check 'lockfile newer than node_modules: bun install runs' eval '[ "$RC" -eq 0 ] && called "^bun install "'
run_install --install
check 'lockfile newer, second run: bun install does not run again' not_called '^bun '

make_fixture
rm "$REPO/helper/desktop-ops-helper"
run_install --install
check 'helper missing: build runs, bun install does not' eval '[ "$RC" -eq 0 ] && called "^swiftc " && not_called "^bun " && [ -x "$REPO/helper/desktop-ops-helper" ]'

make_fixture
touch -t 202501010000 "$REPO/helper/desktop-ops-helper"
run_install --install
check 'helper older than its Swift source: build runs' eval '[ "$RC" -eq 0 ] && called "^swiftc "'

make_fixture
run_install --install --server desktop-ops
check '--server desktop-ops: the driver is not touched' not_called '^npm |^codesign |^spctl '

# --- missing tools ---------------------------------------------------------------------------
for tool in npm git bun swiftc codesign spctl; do
  make_fixture
  fresh_mac
  rm "$WORK/bin/$tool"
  run_install --install
  check "missing $tool: non-zero exit" failed
  check "missing $tool: one line names the tool and how to get it" [ "$(grep -c "^missing tool: $tool -- ." "$WORK/err")" = "1" ]
  check "missing $tool: nothing was started" eval 'no_mutation && [ ! -e "$REPO" ] && [ ! -e "$WORK/home/.nvm" ]'
done
make_fixture
rm "$WORK/bin/npm"
printf '#!/bin/sh\nexit 0\n' >"$NVM_PREFIX/bin/npm"
chmod +x "$NVM_PREFIX/bin/npm"
run_install --install
check 'npm only under ~/.nvm: found there, not reported missing' [ "$RC" -eq 0 ]

# --- --apply refuses when a prerequisite is missing ------------------------------------------
make_fixture
rm -rf "$WORK/home/.nvm"
run_setup --apply --server open-computer-use
check 'apply without the driver: non-zero exit' failed
check 'apply without the driver: nothing registered' eval 'all_four_lack open-computer-use && no_cli_calls && configs_untouched'
check 'apply without the driver: message points at --install' grep -q -- '--install' "$WORK/err"
run_setup --apply
check 'apply (all) without the driver: desktop-ops not half-applied' eval 'failed && all_four_lack desktop-ops && no_cli_calls'
run_setup --apply --server desktop-ops
check 'apply desktop-ops alone still works without the driver package' eval '[ "$RC" -eq 0 ] && all_four_have desktop-ops'

make_fixture
"$CTL/mkdriver.sh" 0.3.5
run_setup --apply --server open-computer-use
check 'apply with another driver version: non-zero, nothing registered' eval 'failed && all_four_lack open-computer-use && no_cli_calls'

make_fixture
rm -rf "$WORK/home/Project"
run_setup --apply --server desktop-ops
check 'apply without the repo: non-zero, nothing registered' eval 'failed && all_four_lack desktop-ops && no_cli_calls && configs_untouched'
make_fixture
rm -rf "$REPO/node_modules"
run_setup --apply --server desktop-ops
check 'apply without dependencies: non-zero, nothing registered' eval 'failed && all_four_lack desktop-ops && no_cli_calls'
make_fixture
rm "$REPO/helper/desktop-ops-helper"
run_setup --apply --server desktop-ops
check 'apply without the helper: non-zero, nothing registered' eval 'failed && all_four_lack desktop-ops && no_cli_calls'
run_setup --apply
check 'apply (all) without the helper: S1 not half-applied' eval 'failed && all_four_lack open-computer-use && no_cli_calls && configs_untouched'
run_setup --remove
check 'remove needs no prerequisite' [ "$RC" -eq 0 ]
make_fixture
rm "$WORK/bin/bun"
run_install --apply --server desktop-ops
check 'apply without bun: non-zero, nothing registered' eval 'failed && all_four_lack desktop-ops && no_cli_calls'

# --- menu entry point: install, then apply ----------------------------------------------------
ENTRY_SRC="$(dirname "$SCRIPT_SRC")/install_desktop_ops.sh"
ENTRY="$DOT/script/common/install_desktop_ops.sh"
run_entry() {
  cp "$ENTRY_SRC" "$ENTRY" 2>/dev/null
  cp "$(dirname "$SCRIPT_SRC")/_platform.sh" "$DOT/script/common/_platform.sh"
  rm -f "$CALLS"
  /usr/bin/env -i HOME="$WORK/home" PATH="$WORK/bin:$SYS" /bin/bash "$ENTRY" >"$WORK/out" 2>"$WORK/err"
  RC=$?
}
make_fixture
fresh_mac
run_entry
check 'menu entry on a fresh Mac: exit 0' [ "$RC" -eq 0 ]
check 'menu entry: installs before it registers' eval 'called "^git clone " && all_four_have open-computer-use && all_four_have desktop-ops'
make_fixture
fresh_mac
echo 'sha512-AAAAnotthepinnedvalue==' >"$CTL/integrity"
run_entry
check 'menu entry, install fails: non-zero and nothing registered' eval 'failed && no_cli_calls && configs_untouched'
MENU="$(dirname "$SCRIPT_SRC")/../../setup.sh"
check 'setup.sh has exactly one entry for it, macOS only' [ "$(grep -c '^  "install_desktop_ops.sh|[^|]*|[^|]*|0|0|environment|darwin|[01]"$' "$MENU")" = "1" ]

# --- static: no sudo, no secrets read -----------------------------------------------------------
no_forbidden_words() { ! grep -nE '(^|[^[:alnum:]_-])sudo([^[:alnum:]_-]|$)|\.env\.secrets|agent-secret run' "$SCRIPT_SRC" "$ENTRY_SRC"; }
check 'neither script calls sudo or reads the secrets file' no_forbidden_words

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
