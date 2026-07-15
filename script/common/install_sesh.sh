#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

# sesh：跨 Claude Code + Codex 的 session finder（fzf 互動搜尋 + resume）。
# 單一 Go binary，掃兩邊 history，統一成一份可搜清單，選中直接拉起對應 TUI。

platform_guard "sesh (session finder)" darwin linux

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"

if ! is_installed go; then
  echo "[ERROR] 需要 Go（先跑 install_golang.sh）"
  exit 1
fi
if ! is_installed fzf; then
  echo "[WARN] fzf 未安裝，sesh 互動選擇需要它（brew install fzf / apt install fzf）"
fi

mkdir -p "$HOME/.local/bin"
cd "$DOTFILE_DIR/tools/sesh"
go build -o "$HOME/.local/bin/sesh" .
echo "[DONE] sesh → ~/.local/bin/sesh（用法：sesh / sesh <query> / sesh --cc / sesh --codex）"
