#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

platform_guard "Codex CLI" darwin

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"

install_monika_codex() {
  bash "$DOTFILE_DIR/config/ai/codex-plugin/scripts/build.sh"
  bash "$DOTFILE_DIR/config/ai/codex-plugin/scripts/install-local.sh"
}

if [ "$_PLATFORM_PKG" = "brew" ]; then
  if brew list --cask codex &>/dev/null; then
    outdated_info=$(brew outdated --cask codex)
    if [ -z "$outdated_info" ]; then
      echo -e "${G}[SKIP] Codex CLI: 已安裝且為最新版本${N}"
      install_monika_codex
      exit 0
    else
      echo -e "${Y}[UPDATE] Codex CLI: 正在更新至最新版本...${N}"
      brew upgrade --cask codex
      install_monika_codex
      exit 0
    fi
  else
    echo -e "${Y}[INSTALL] Codex CLI: 正在安裝...${N}"
    brew install --cask codex
    install_monika_codex
  fi
else
  echo "[SKIP] Codex CLI: 目前僅支援 macOS (Homebrew Cask)"
fi
