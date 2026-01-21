#!/bin/sh
set -e

echo "Installing Meslo Nerd Font..."

# Create temp directory
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"

curl -LO https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf

mkdir -p ~/.local/share/fonts

old_filename=$(ls | grep ttf)
new_filename=$(echo "$old_filename" | sed "s/%20/ /g")
mv "$old_filename" "$new_filename"
mv "$new_filename" ~/.local/share/fonts

fc-cache -f -v

echo "✅ Font installation complete"
