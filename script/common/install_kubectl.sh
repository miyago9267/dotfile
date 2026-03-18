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
elif command -v apt >/dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
elif command -v pacman >/dev/null; then
  sudo pacman -S --noconfirm kubectl
else
  echo "kubectl installation not supported on this OS"
  exit 1
fi

echo "${Y}kubectl installed successfully!${N}"