#!/bin/bash
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "Argo CD CLI" darwin linux
is_installed argocd && skip_installed "Argo CD CLI"

Y="\033[1;33m"
N="\033[0m"

echo "${Y}Installing Argo CD CLI...${N}"

if [ "$(uname)" = "Darwin" ]; then
  if command -v brew >/dev/null; then
    brew install argocd
  else
    echo "Homebrew not found. Please install Homebrew first."
    exit 1
  fi
elif command -v pacman >/dev/null; then
  # AUR or binary
  if command -v yay >/dev/null; then
    yay -S --noconfirm argocd-cli
  else
    echo "Installing from GitHub release..."
    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64|amd64) ARGOCD_ARCH="amd64" ;;
      aarch64|arm64) ARGOCD_ARCH="arm64" ;;
      *) echo "[WARN] Argo CD CLI 不支援當前架構 ($ARCH)，跳過"; exit 0 ;;
    esac
    VERSION="$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f4)"
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-${ARGOCD_ARCH}"
    chmod +x argocd
    sudo mv argocd /usr/local/bin/
  fi
else
  # Debian/Ubuntu or generic Linux
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) ARGOCD_ARCH="amd64" ;;
    aarch64|arm64) ARGOCD_ARCH="arm64" ;;
    *) echo "[WARN] Argo CD CLI 不支援當前架構 ($ARCH)，跳過"; exit 0 ;;
  esac
  VERSION="$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f4)"
  curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-${ARGOCD_ARCH}"
  chmod +x argocd
  sudo mv argocd /usr/local/bin/
fi

echo "${Y}Argo CD CLI installed successfully!${N}"
