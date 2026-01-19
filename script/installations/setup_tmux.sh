#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOTFILE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo "Tmux setup starting..."

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/debian_version ]] || [[ -f /etc/ubuntu-release ]]; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

install_package() {
    local package=$1
    
    case $OS in
        "macOS")
            if command -v brew &> /dev/null; then
                brew install "$package" 2>/dev/null || true
            else
                echo "Error: Homebrew not found. Install from https://brew.sh"
                exit 1
            fi
            ;;
        "ubuntu")
            sudo apt update -qq
            sudo apt install -y "$package" || true
            ;;
        "arch")
            sudo pacman -S --noconfirm "$package" || true
            ;;
        *)
            echo "Error: Unsupported OS"
            exit 1
            ;;
    esac
}

OS=$(detect_os)
echo "Detected OS: $OS"

echo "Checking tmux..."
if ! command -v tmux &> /dev/null; then
    echo "Installing tmux..."
    install_package tmux
else
    TMUX_VERSION=$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")
    echo "tmux $TMUX_VERSION installed"
    
    if [ "$(echo "$TMUX_VERSION < 3.2" | bc 2>/dev/null)" = "1" ]; then
        echo "Warning: tmux $TMUX_VERSION is old. Recommend 3.2+ for popup support"
        read -p "Upgrade tmux? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_package tmux
        fi
    fi
fi

echo "Checking clipboard tool..."
if [[ "$OS" == "macOS" ]]; then
    echo "macOS has built-in pbcopy"
else
    if ! command -v xclip &> /dev/null; then
        echo "Installing xclip..."
        install_package xclip
    else
        echo "xclip installed"
    fi
fi

echo "Backing up existing config..."
BACKUP_DIR="$HOME/.tmux_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f "$HOME/.tmux.conf.local" ]; then
    cp "$HOME/.tmux.conf.local" "$BACKUP_DIR/"
    echo "Backed up to $BACKUP_DIR"
fi

if [ ! -f "$HOME/.tmux.conf" ] || ! grep -q "gpakosz" "$HOME/.tmux.conf" 2>/dev/null; then
    echo "Installing gpakosz/.tmux..."
    
    cd "$HOME"
    git clone https://github.com/gpakosz/.tmux.git "$HOME/.tmux_gpakosz" 2>/dev/null || \
        (cd "$HOME/.tmux_gpakosz" && git pull)
    
    ln -sf "$HOME/.tmux_gpakosz/.tmux.conf" "$HOME/.tmux.conf"
    echo "gpakosz/.tmux installed"
else
    echo "gpakosz/.tmux already exists"
fi

echo "Creating symlinks..."
if [ -f "$DOTFILE_DIR/tmux/base.conf" ] && [ -f "$DOTFILE_DIR/tmux/nvim-extension.conf" ]; then
    ln -sf "$DOTFILE_DIR/tmux/base.conf" "$HOME/.tmux.conf"
    ln -sf "$DOTFILE_DIR/tmux/nvim-extension.conf" "$HOME/.tmux.conf.local"
    echo "  ~/.tmux.conf -> ~/dotfile/tmux/base.conf"
    echo "  ~/.tmux.conf.local -> ~/dotfile/tmux/nvim-extension.conf"
else
    echo "Error: Config files not found"
    exit 1
fi

echo "Reloading tmux config..."
if [ -n "$TMUX" ]; then
    tmux source-file ~/.tmux.conf
    echo "Config reloaded"
else
    echo "Not in tmux session. Run: tmux source-file ~/.tmux.conf"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start Neovim to install vim-tmux-navigator: nvim"
echo "  2. Start tmux: tmux"
echo ""
echo "Key bindings:"
echo "  Ctrl-h/j/k/l: Navigate between Neovim and tmux panes"
echo "  <prefix> |: Vertical split"
echo "  <prefix> _: Horizontal split"
echo "  <prefix> t: Popup terminal"
echo "  <prefix> r: Reload config"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
