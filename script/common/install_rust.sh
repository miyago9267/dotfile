

#!/bin/bash
set -e

# Skip if already installed
if command -v rustup >/dev/null 2>&1 || command -v cargo >/dev/null 2>&1; then
  echo "已安裝 rust, 跳過"
  exit 0
fi

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

echo "Installing Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" rust
fi

echo "Rust installed. Environment variables updated. Restart terminal to apply changes"