#!/bin/sh
set -e

echo "🔧 安裝 Bun..."
curl -fsSL https://bun.sh/install | bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" bun
fi

echo "✅ Bun 安裝完成，重新開啟終端即可使用"
