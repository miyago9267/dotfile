#!/bin/bash
set -e

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
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
  esac
  STABLE="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -LO "https://dl.k8s.io/release/${STABLE}/bin/linux/${K8S_ARCH}/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl installation not supported on this OS"
  exit 1
fi

echo "${Y}kubectl installed successfully!${N}"
