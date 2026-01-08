#!/bin/sh
set -e

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