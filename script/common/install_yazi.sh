#!/bin/sh
set -e
. "$(dirname "$0")/_platform.sh"

platform_guard "Yazi" darwin linux:apt linux:pacman

is_installed yazi && skip_installed "Yazi"

echo "Installing Yazi + optional deps (zoxide, bat)..."

case "$_PLATFORM_PKG" in
  brew)
    brew install yazi zoxide bat
    ;;
  apt)
    # yazi 沒有官方 apt 包，用 cargo 安裝
    if ! is_installed cargo; then
      echo "需要 Rust toolchain，請先執行 install_rust.sh"
      exit 1
    fi
    cargo install --locked yazi-fm yazi-cli
    sudo apt-get install -y zoxide bat
    ;;
  pacman)
    sudo pacman -S --noconfirm yazi zoxide bat
    ;;
esac

echo "Yazi 安裝完成"
