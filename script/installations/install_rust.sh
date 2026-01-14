

#!/bin/bash
set -e

echo "Installing Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" rust
fi

echo "Rust installed. Environment variables updated. Restart terminal to apply changes"