#!/bin/sh
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
  *) echo "[WARN] fvm 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v fvm >/dev/null 2>&1; then
  exit 0
fi

install_with_brew() {
  brew tap leoafarias/fvm >/dev/null 2>&1 || true
  brew install fvm
}

install_with_dart() {
  dart pub global activate fvm
}

install_with_flutter() {
  flutter pub global activate fvm
}

if command -v brew >/dev/null 2>&1; then
  echo "Installing FVM via Homebrew..."
  install_with_brew
elif command -v dart >/dev/null 2>&1; then
  echo "Installing FVM via Dart..."
  install_with_dart
elif command -v flutter >/dev/null 2>&1; then
  echo "Installing FVM via Flutter..."
  install_with_flutter
else
  echo "Error: Please install Homebrew, Dart, or Flutter first" >&2
  exit 1
fi

if command -v fvm >/dev/null 2>&1; then
  FVM_BIN="$(command -v fvm)"
  mkdir -p "$HOME/fvm/bin"
  ln -sf "$FVM_BIN" "$HOME/fvm/bin/fvm"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" fvm
fi

echo "✅ FVM 安裝完成"
