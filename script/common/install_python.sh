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
  *) echo "[WARN] pyenv 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v pyenv >/dev/null 2>&1; then
  exit 0
fi

echo "Installing Python tools (Poetry, UV, Pyenv)..."
# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh
# Install Pyenv
git clone https://github.com/pyenv/pyenv.git ~/.pyenv || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" python
fi