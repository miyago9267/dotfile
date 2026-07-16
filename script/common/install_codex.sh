#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

platform_guard "Codex CLI" darwin linux

export PATH="$HOME/.local/bin:$PATH"
installer=""

cleanup() {
  [ -n "$installer" ] && rm -f "$installer"
}
trap cleanup EXIT

if is_installed codex; then
  echo "[UPDATE] Codex CLI via official standalone installer"
else
  echo "[INSTALL] Codex CLI via official standalone installer"
fi

installer=$(mktemp /tmp/codex-install.XXXXXX)
download_installer "https://chatgpt.com/codex/install.sh" "$installer"
CODEX_NON_INTERACTIVE=1 sh "$installer"
hash -r

if ! is_installed codex; then
  echo "[ERROR] Codex installer completed but codex is not on PATH" >&2
  exit 1
fi

codex_version=$(codex --version)
echo "[OK] $codex_version"
