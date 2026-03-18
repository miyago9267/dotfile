#!/bin/sh
set -e

# Detect OS for user info
if [ "$(uname)" = "Darwin" ]; then
  echo "Detected: macOS"
elif [ -f /etc/arch-release ]; then
  echo "Detected: Arch Linux"
elif [ -f /etc/debian_version ]; then
  echo "Detected: Ubuntu/Debian"
else
  echo "Detected: $(uname) (generic)"
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
