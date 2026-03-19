#!/bin/sh
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
  *) echo "[WARN] bun 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v bun >/dev/null 2>&1; then
  exit 0
fi

echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" bun
fi

echo "✅ Bun 安裝完成，重新開啟終端即可使用"
