#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

platform_guard "Gemini CLI" darwin linux

if is_installed brew && brew list gemini-cli >/dev/null 2>&1; then
  if [ -n "$(brew outdated gemini-cli 2>/dev/null)" ]; then
    echo "[UPDATE] Gemini CLI via existing Homebrew installation"
    brew upgrade gemini-cli
  else
    echo "[SKIP] Gemini CLI: Homebrew installation is up to date"
  fi
  if ! is_installed gemini; then
    echo "[ERROR] Homebrew manages Gemini CLI but gemini is not on PATH" >&2
    exit 1
  fi
  gemini_version=$(gemini --version)
  echo "[OK] $gemini_version"
  exit 0
fi

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

if is_installed gemini; then
  echo "[UPDATE] Gemini CLI via official npm package"
else
  echo "[INSTALL] Gemini CLI via official npm package"
fi

npm install --global @google/gemini-cli@latest
hash -r

if ! is_installed gemini; then
  echo "[ERROR] Gemini CLI installer completed but gemini is not on PATH" >&2
  exit 1
fi

gemini_version=$(gemini --version)
echo "[OK] $gemini_version"
