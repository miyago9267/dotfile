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
  *) echo "[WARN] flutter 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v flutter >/dev/null 2>&1 || [ -d "$HOME/development/flutter" ]; then
  exit 0
fi

FLUTTER_DIR="$HOME/development/flutter"

echo "Installing Flutter..."
if [ -d "$FLUTTER_DIR/.git" ]; then
  git -C "$FLUTTER_DIR" fetch --tags
  git -C "$FLUTTER_DIR" checkout stable
  git -C "$FLUTTER_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
fi

"$FLUTTER_DIR/bin/flutter" config --no-analytics >/dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" flutter
fi

echo "✅ Flutter 就緒，請執行 'flutter doctor' 確認環境"
