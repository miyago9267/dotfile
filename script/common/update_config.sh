#!/bin/bash
# 只同步 repository-managed config、generated entries 與 runtime symlinks。
# 不安裝套件、不升級 CLI、不建立 secrets placeholder。

set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export MIYAGO_DOTFILE_ROOT="$DOTFILE_DIR"
SCRIPT_DIR="$DOTFILE_DIR/script/common"

CONFIG_SETUP_SCRIPTS=(
  setup_dotfiles.sh
  setup_claude.sh
  setup_codex.sh
  setup_gemini.sh
  setup_grok.sh
  setup_pi.sh
)

for name in "${CONFIG_SETUP_SCRIPTS[@]}"; do
  script_path="$SCRIPT_DIR/$name"
  if [ ! -f "$script_path" ]; then
    printf '[SKIP] %s -- script not found\n' "$name"
    continue
  fi
  printf '[RUN] %s\n' "$name"
  bash "$script_path"
done

# installer 會把這台機器的絕對路徑回寫進版控的 hook 設定，收尾時改回可攜形式。
if command -v python3 >/dev/null 2>&1; then
  python3 "$SCRIPT_DIR/portable_paths.py" --fix
fi

printf '%s\n' '[OK] config-only sync complete'
