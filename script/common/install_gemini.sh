#!/bin/bash
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "Gemini CLI" darwin

Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"

# 如果是 macOS，使用 brew
if [ "$_PLATFORM_PKG" = "brew" ]; then
  if brew list gemini-cli &>/dev/null; then
    # brew outdated <formula> 返回 0 代表有更新 (有輸出)，非 0 代表沒有更新 (無輸出)
    # 注意：brew outdated 的回傳值邏輯有時候會跟版本有關，通常檢查輸出是否為空比較準確
    outdated_info=$(brew outdated gemini-cli)
    if [ -z "$outdated_info" ]; then
      echo -e "${G}[SKIP] Gemini CLI: 已安裝且為最新版本${N}"
      exit 0
    else
      echo -e "${Y}[UPDATE] Gemini CLI: 正在從 $(brew info --json gemini-cli | jq -r '.[0].installed[0].version') 更新至最新版本...${N}"
      brew upgrade gemini-cli
      exit 0
    fi
  else
    echo -e "${Y}[INSTALL] Gemini CLI: 正在安裝...${N}"
    brew install gemini-cli
  fi
else
  echo "[SKIP] Gemini CLI: 目前僅支援 macOS (Homebrew)"
fi
