#!/bin/sh
set -e

# Detect OS for user info
if [ "$(uname)" = "Darwin" ]; then
  echo "Detected: macOS"
elif [ -f /etc/arch-release ]; then
  echo "Detected: Arch Linux"
elif [ -f /etc/debian_version ]; then
  echo "Detected: Ubuntu/Debian"
else
  echo "Detected: $(uname) (generic)"
fi

echo "Installing pnpm..."
curl -fsSL https://get.pnpm.io/install.sh | sh -

if command -v corepack >/dev/null 2>&1; then
  corepack enable pnpm || true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" pnpm
fi

echo "✅ pnpm 安裝完成，重新開啟終端即可使用"
