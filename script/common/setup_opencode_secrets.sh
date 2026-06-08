#!/bin/bash
set -euo pipefail

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPENCODE_SECRET_DIR="${OPENCODE_SECRET_DIR:-$HOME/.config/opencode/secrets}"
EXAMPLE_DIR="$DOTFILE_DIR/config/opencode/secrets.example"

Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"

mkdir -p "$OPENCODE_SECRET_DIR"
chmod 700 "$OPENCODE_SECRET_DIR"

copy_placeholder() {
  local name="$1"
  local dst="$OPENCODE_SECRET_DIR/$name"
  local src="$EXAMPLE_DIR/$name"

  if [ -f "$dst" ]; then
    chmod 600 "$dst" 2>/dev/null || true
    echo -e "  ${G}[OK]${N} ~/.config/opencode/secrets/$name exists"
    return 0
  fi

  if [ -f "$src" ]; then
    cp "$src" "$dst"
  else
    : > "$dst"
  fi
  chmod 600 "$dst"
  echo -e "  ${Y}[CREATE]${N} ~/.config/opencode/secrets/$name"
}

copy_placeholder "gemini-api-key"
copy_placeholder "aluo-api-key"

echo -e "${G}[OK]${N} OpenCode secret files are present; replace placeholder values if needed"
