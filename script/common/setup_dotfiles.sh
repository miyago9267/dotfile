#!/bin/sh
Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"
echo "${Y}Building link to dotfiles${N}"
mkdir -p ~/.config
dir="$HOME/dotfile"

link() {
  src="$1"; dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ${G}[OK]${N} $dst"
  else
    ln -sf "$src" "$dst"
    echo "  ${Y}[LINK]${N} $dst -> $src"
  fi
}

link "$dir/config/bash/.bashrc"      ~/.bashrc
link "$dir/config/zsh/.zshrc"        ~/.zshrc
link "$dir/config/zsh/.zshrc.d"      ~/.zshrc.d
link "$dir/config/zsh/.p10k.zsh"     ~/.p10k.zsh
link "$dir/config/zsh/alias.sh"      ~/alias.sh
link "$dir/config/vim/.vimrc"        ~/.vimrc
link "$dir/config/nvim"              ~/.config/nvim
link "$dir/config/ghostty/config"    ~/.config/ghostty/config

