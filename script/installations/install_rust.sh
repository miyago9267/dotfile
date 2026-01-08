

#!/bin/bash
set -e

echo "🔧 安裝 Rust..."
curl https://sh.rustup.rs -sSf | sh -s -- -y

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
	"$SCRIPT_DIR/setup_env_snippets.sh" rust
fi

echo "✅ Rust 安裝完成，環境變數已更新，重新開啟終端即可生效"