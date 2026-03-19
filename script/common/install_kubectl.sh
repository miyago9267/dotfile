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
  *) echo "[WARN] kubectl 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v kubectl >/dev/null 2>&1; then
  exit 0
fi

Y="\033[1;33m"
N="\033[0m"

echo "${Y}Installing kubectl...${N}"

if [ "$(uname)" = "Darwin" ]; then
  if command -v brew >/dev/null; then
    brew install kubectl
  else
    echo "Homebrew not found. Please install Homebrew first."
    exit 1
  fi
elif command -v pacman >/dev/null; then
  sudo pacman -S --noconfirm kubectl
elif command -v apt >/dev/null; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) K8S_ARCH="amd64" ;;
    aarch64|arm64) K8S_ARCH="arm64" ;;
    *) echo "[WARN] kubectl 不支援當前架構 ($ARCH)，跳過"; exit 0 ;;
  esac
  STABLE="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -LO "https://dl.k8s.io/release/${STABLE}/bin/linux/${K8S_ARCH}/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "[WARN] kubectl 不支援當前 OS ($(uname))，跳過"
  exit 0
fi

echo "${Y}kubectl installed successfully!${N}"
