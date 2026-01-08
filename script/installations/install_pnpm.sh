#!/bin/sh
set -e

echo "🔧 安裝 pnpm..."
curl -fsSL https://get.pnpm.io/install.sh | sh -

if command -v corepack >/dev/null 2>&1; then
  corepack enable pnpm || true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" pnpm
fi

echo "✅ pnpm 安裝完成，重新開啟終端即可使用"
