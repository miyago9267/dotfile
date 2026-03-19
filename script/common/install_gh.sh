#!/bin/bash
set -e

# -- OS 檢查 --
OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Darwin) echo "Detected: macOS" ;;
  Linux)
    if [ -f /etc/arch-release ]; then echo "Detected: Arch Linux"
    elif [ -f /etc/debian_version ]; then echo "Detected: Ubuntu/Debian"
    else echo "Detected: Linux (generic)"
    fi ;;
  *) echo "[WARN] gh 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v gh >/dev/null 2>&1; then
  exit 0
fi

Y="\033[1;33m"
N="\033[0m"

echo "${Y}Installing GitHub CLI (gh)...${N}"

if [ "$(uname)" = "Darwin" ]; then
  if command -v brew >/dev/null; then
    brew install gh
  else
    echo "Homebrew not found. Please install Homebrew first."
    exit 1
  fi
elif command -v pacman >/dev/null; then
  sudo pacman -S --noconfirm github-cli
elif command -v apt >/dev/null; then
  # Official GitHub CLI apt repo
  (type -p wget >/dev/null || sudo apt install -y wget) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install -y gh
  rm -f "$out"
else
  echo "[WARN] GitHub CLI (gh) 不支援當前 OS ($(uname))，跳過"
  exit 0
fi

echo "${Y}GitHub CLI installed successfully!${N}"
