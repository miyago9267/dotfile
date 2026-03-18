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

echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" bun
fi

echo "✅ Bun 安裝完成，重新開啟終端即可使用"
