#!/bin/bash
set -e

# -- OS 檢查 --
OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Darwin) echo "Detected: macOS" ;;
  Linux)
    if [ -f /etc/arch-release ]; then echo "Detected: Arch Linux"
    elif [ -f /etc/debian_version ]; then echo "Detected: Ubuntu/Debian"
    else echo "Detected: Linux (generic)"
    fi ;;
  *) echo "[WARN] rust 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v rustup >/dev/null 2>&1 || command -v cargo >/dev/null 2>&1; then
  exit 0
fi

echo "Installing Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" rust
fi

echo "Rust installed. Environment variables updated. Restart terminal to apply changes"