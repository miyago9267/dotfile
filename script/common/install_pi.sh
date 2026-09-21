#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

platform_guard "Pi coding agent" darwin linux

load_nvm() {
  NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    . "/opt/homebrew/opt/nvm/nvm.sh"
  fi
}

load_nvm
if ! is_installed npm; then
  echo "[INFO] npm not found; installing the Node.js dependency first"
  bash "$(dirname "$0")/install_node.sh"
  load_nvm
fi

if ! is_installed npm; then
  echo "[ERROR] npm is unavailable after Node.js setup" >&2
  exit 1
fi

PI_PACKAGE="@earendil-works/pi-coding-agent"
if is_installed pi; then
  echo "[UPDATE] Pi coding agent via official npm package"
else
  echo "[INSTALL] Pi coding agent via official npm package"
fi

npm install --global --ignore-scripts "$PI_PACKAGE@latest"
hash -r

if ! is_installed pi; then
  echo "[ERROR] Pi installer completed but pi is not on PATH" >&2
  exit 1
fi

pi --version
