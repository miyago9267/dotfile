#!/usr/bin/env bash
# Two-way Claude memory sync with the ITRD workstation (macOS only), detached so session start/exit never waits.
[ "$(uname)" = Darwin ] || exit 0
cat >/dev/null
mkdir -p "$HOME/.claude/memory-sync"
nohup "$HOME/dotfile/script/utils/claude-memory-sync" >>"$HOME/.claude/memory-sync/sync.log" 2>&1 </dev/null &
exit 0
