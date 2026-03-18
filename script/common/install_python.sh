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