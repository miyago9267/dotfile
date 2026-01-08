#!/bin/sh
set -e

echo "🔧 安裝 Google Cloud SDK..."
curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" gcloud
fi

echo "✅ Google Cloud SDK 安裝完成，請重新開啟終端或執行 'gcloud init'"
