#!/bin/sh
set -e

install_with_brew() {
  brew update
  brew install php@8.3
  brew link --overwrite --force php@8.3
}

install_with_apt() {
  sudo apt update
  sudo apt install -y software-properties-common
  sudo add-apt-repository -y ppa:ondrej/php
  sudo apt update
  sudo apt install -y php8.3 php8.3-cli php8.3-common php8.3-fpm
}

install_with_pacman() {
  sudo pacman -Syu --noconfirm php php-fpm
}

if command -v brew >/dev/null 2>&1; then
  echo "🔧 透過 Homebrew 安裝 PHP 8.3..."
  install_with_brew
elif command -v apt >/dev/null 2>&1; then
  echo "🔧 透過 APT 安裝 PHP 8.3..."
  install_with_apt
elif command -v pacman >/dev/null 2>&1; then
  echo "🔧 透過 Pacman 安裝 PHP 8.3..."
  install_with_pacman
else
  echo "⚠️ 找不到支援的套件管理器，請手動安裝 PHP 8.3" >&2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" php83
fi

echo "✅ PHP 8.3 安裝完成"
