#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/_platform.sh"

platform_guard "OpenCode" darwin linux

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

if ! is_installed bun; then
  echo -e "${Y}[INSTALL] Bun is required for OpenCode; running install_bun.sh${N}"
  bash "$DOTFILE_DIR/script/common/install_bun.sh"
  export PATH="$HOME/.bun/bin:$PATH"
fi

if is_installed opencode; then
  echo -e "${G}[SKIP] OpenCode CLI: installed at $(command -v opencode)${N}"
else
  echo -e "${Y}[INSTALL] OpenCode CLI via Bun${N}"
  bun add -g opencode-ai
fi

echo -e "${Y}[SETUP] Linking OpenCode config${N}"
bash "$DOTFILE_DIR/script/common/setup_dotfiles.sh"

echo -e "${Y}[SETUP] Preparing OpenCode secret placeholders${N}"
bash "$DOTFILE_DIR/script/common/setup_opencode_secrets.sh"

echo -e "${Y}[CHECK] Daily OpenCode config${N}"
opencode debug config >/dev/null

echo -e "${Y}[CHECK] Harness OpenCode config and oh-my-openagent plugin${N}"
OPENCODE_CONFIG="$HOME/.config/opencode-harness/opencode.json" \
  OPENCODE_CONFIG_DIR="$HOME/.config/opencode-harness" \
  opencode debug config >/dev/null

echo -e "${G}[OK] OpenCode daily and harness configs are ready${N}"
