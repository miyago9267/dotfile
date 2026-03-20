#!/bin/sh
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "uv" darwin linux
is_installed uv && skip_installed "uv"

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh