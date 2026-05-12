#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

platform_guard "Claude Code" darwin linux

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

install_monika_claude() {
  bash "$DOTFILE_DIR/config/ai/claude-plugin/scripts/build-artifact.sh"
  bash "$DOTFILE_DIR/plugins/monika-claude/install.sh" --tool claude
}

# Claude Code CLI 可能安裝在 ~/.local/bin（npm prefix）
# 先加入 PATH 以便 is_installed 偵測
export PATH="$HOME/.local/bin:$PATH"

if is_installed claude; then
  echo "[SKIP] Claude Code: 已安裝"
  install_monika_claude
  exit 0
fi

echo "Installing Claude Code CLI via npm..."

if ! is_installed npm; then
  echo "[ERROR] npm not found. Please install Node.js first (install_node.sh)"
  exit 1
fi

npm install -g @anthropic-ai/claude-code

echo "Claude Code CLI installed to: $(command -v claude 2>/dev/null || echo '~/.local/bin/claude')"
install_monika_claude
