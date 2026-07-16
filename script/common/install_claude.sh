#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

platform_guard "Claude Code" darwin linux

export PATH="$HOME/.local/bin:$PATH"
installer=""

cleanup() {
  [ -n "$installer" ] && rm -f "$installer"
}
trap cleanup EXIT

if is_installed claude; then
  echo "[UPDATE] Claude Code CLI via official native installer"
else
  echo "[INSTALL] Claude Code CLI via official native installer"
fi

installer=$(mktemp /tmp/claude-install.XXXXXX)
download_installer "https://claude.ai/install.sh" "$installer"
bash "$installer"
hash -r

if ! is_installed claude; then
  echo "[ERROR] Claude Code installer completed but claude is not on PATH" >&2
  exit 1
fi

claude_version=$(claude --version)
echo "[OK] $claude_version"
