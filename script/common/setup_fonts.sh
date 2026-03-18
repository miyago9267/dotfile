#!/bin/sh
set -e

echo "Installing Meslo Nerd Font..."

if [ "$(uname)" = "Darwin" ]; then
  # macOS: Homebrew cask font
  if command -v brew >/dev/null; then
    brew install --cask font-meslo-lg-nerd-font 2>/dev/null || true
    echo "Font installed via Homebrew"
  else
    # Fallback: download to ~/Library/Fonts/
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    cd "$TMP_DIR"
    curl -LO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    mv MesloLGS%20NF%20Regular.ttf "$HOME/Library/Fonts/MesloLGS NF Regular.ttf"
    echo "Font installed to ~/Library/Fonts/"
  fi
else
  # Linux: download to ~/.local/share/fonts/
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  cd "$TMP_DIR"
  curl -LO "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  mkdir -p ~/.local/share/fonts
  mv MesloLGS%20NF%20Regular.ttf "$HOME/.local/share/fonts/MesloLGS NF Regular.ttf"
  fc-cache -f -v
  echo "Font installed to ~/.local/share/fonts/"
fi

echo "Font installation complete"
