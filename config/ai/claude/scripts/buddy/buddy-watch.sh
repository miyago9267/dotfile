#!/usr/bin/env bash
# =============================================================================
# Claude Code Buddy Auto-Patcher
#
# Detects new Claude Code versions and re-applies bones patch + companion inject.
# Designed to run from LaunchAgent or shell startup.
#
# Usage:
#   ./buddy-watch.sh              Check + patch if needed (default)
#   ./buddy-watch.sh --status     Just report, don't patch
#   ./buddy-watch.sh --force      Patch even if already done
#   ./buddy-watch.sh --install    Install LaunchAgent
#   ./buddy-watch.sh --uninstall  Remove LaunchAgent
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_DIR="$HOME/.local/share/claude/versions"
STAMP_FILE="$HOME/.claude/.buddy-patched-version"
DESIRED_FILE="$SCRIPT_DIR/buddy-desired.json"
BONES_PATCH="$SCRIPT_DIR/buddy-bones-patch.sh"
CONFIG_FILE="$HOME/.claude.json"
LOG_FILE="$HOME/.claude/.buddy-watch.log"
PLIST_NAME="com.miyago.claude-buddy-watch"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

get_current_version() {
  ls -t "$BINARY_DIR" 2>/dev/null | grep -v '\.bak\|\.bones-bak\|\.buddy-bak' | head -1
}

get_patched_version() {
  cat "$STAMP_FILE" 2>/dev/null || echo ""
}

is_patched() {
  local binary="$BINARY_DIR/$(get_current_version)"
  [[ -f "$binary" ]] || return 1

  # Check if spread order is already reversed
  perl -0777 -ne '
    while (/\.companion;if\(!(\w)\)return;let\{bones:(\w)\}=\w+\(\w+\(\)\);return\{\.\.\.\2,\.\.\.\1\}\}/g) {
      print "reversed\n";
    }
  ' <(strings "$binary") | grep -q "reversed"
}

inject_desired() {
  [[ -f "$DESIRED_FILE" ]] || { log "ERROR: $DESIRED_FILE not found"; return 1; }
  [[ -f "$CONFIG_FILE" ]] || { log "ERROR: $CONFIG_FILE not found"; return 1; }

  python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    desired = json.load(f)
with open(sys.argv[2]) as f:
    cfg = json.load(f)

if 'companion' not in cfg:
    print('SKIP: No companion in config yet (run /buddy first)', file=sys.stderr)
    sys.exit(0)

for k in ('name', 'personality', 'rarity', 'species', 'eye', 'hat', 'shiny', 'stats'):
    if k in desired:
        cfg['companion'][k] = desired[k]

with open(sys.argv[2], 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(f\"Injected: {desired.get('name','')} ({desired.get('species','')}/{desired.get('hat','')})\")
" "$DESIRED_FILE" "$CONFIG_FILE"
}

do_watch() {
  local force="${1:-false}"
  local current
  current=$(get_current_version)

  if [[ -z "$current" ]]; then
    log "No Claude Code binary found"
    exit 0
  fi

  local patched
  patched=$(get_patched_version)

  if [[ "$force" != "true" && "$current" == "$patched" ]]; then
    # Version matches stamp -- but verify binary is actually patched
    if is_patched; then
      return 0
    fi
    log "Version stamp matches ($current) but binary not patched. Re-patching..."
  fi

  if [[ "$force" != "true" && "$current" != "$patched" ]]; then
    log "New version detected: $current (was: ${patched:-none})"
  fi

  # Step 1: Bones patch (reverse spread order)
  log "Patching binary..."
  if bash "$BONES_PATCH" patch 2>&1 | tee -a "$LOG_FILE"; then
    log "Binary patched"
  else
    log "ERROR: Binary patch failed"
    return 1
  fi

  # Step 2: Inject desired companion state
  log "Injecting companion..."
  if inject_desired 2>&1 | tee -a "$LOG_FILE"; then
    log "Companion injected"
  else
    log "ERROR: Companion inject failed"
    return 1
  fi

  # Step 3: Write stamp
  echo "$current" > "$STAMP_FILE"
  log "Stamp written: $current"
}

do_status() {
  local current
  current=$(get_current_version)
  local patched
  patched=$(get_patched_version)

  echo "Current version: ${current:-none}"
  echo "Patched version: ${patched:-none}"

  if [[ -n "$current" ]]; then
    if is_patched; then
      echo "Binary status:   PATCHED"
    else
      echo "Binary status:   UNPATCHED"
    fi
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    c = json.load(f).get('companion', {})
print(f\"Companion:       {c.get('name','?')} ({c.get('species','?')}/{c.get('hat','?')}) shiny={c.get('shiny','?')}\")
print(f\"Personality:     {c.get('personality','?')[:50]}...\")
stats = c.get('stats', {})
print(f\"Stats:           {' '.join(f'{k}={v}' for k,v in stats.items())}\")
" 2>/dev/null
  fi

  if launchctl list "$PLIST_NAME" &>/dev/null; then
    echo "LaunchAgent:     LOADED"
  else
    echo "LaunchAgent:     NOT LOADED"
  fi
}

do_install() {
  local watch_script="$SCRIPT_DIR/buddy-watch.sh"

  mkdir -p "$(dirname "$PLIST_PATH")"

  cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$watch_script</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>$BINARY_DIR</string>
  </array>
  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
PLIST

  launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"

  log "LaunchAgent installed and loaded"
  echo "Watching: $BINARY_DIR"
  echo "Log: $LOG_FILE"
}

do_uninstall() {
  if [[ -f "$PLIST_PATH" ]]; then
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    log "LaunchAgent uninstalled"
  else
    echo "LaunchAgent not found at $PLIST_PATH"
  fi
}

case "${1:-}" in
  --status)    do_status ;;
  --force)     do_watch true ;;
  --install)   do_install ;;
  --uninstall) do_uninstall ;;
  "")          do_watch false ;;
  *)
    echo "Usage:"
    echo "  $0              Check + auto-patch if needed"
    echo "  $0 --status     Report current state"
    echo "  $0 --force      Force re-patch"
    echo "  $0 --install    Install LaunchAgent (watch for updates)"
    echo "  $0 --uninstall  Remove LaunchAgent"
    ;;
esac
