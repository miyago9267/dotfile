#!/bin/bash
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "Claude Code" darwin linux

# Claude Code CLI 可能安裝在 ~/.local/bin（npm prefix）
# 先加入 PATH 以便 is_installed 偵測
export PATH="$HOME/.local/bin:$PATH"

is_installed claude && skip_installed "Claude Code"

echo "Installing Claude Code CLI via npm..."

if ! is_installed npm; then
  echo "[ERROR] npm not found. Please install Node.js first (install_node.sh)"
  exit 1
fi

npm install -g @anthropic-ai/claude-code

echo "Claude Code CLI installed to: $(command -v claude 2>/dev/null || echo '~/.local/bin/claude')"
