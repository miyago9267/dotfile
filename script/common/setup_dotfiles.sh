#!/bin/sh
Y="\033[1;33m"
N="\033[0m"
echo "${Y}Building link to dotfiles${N}"
mkdir -p ~/.config
dir="$HOME/dotfile"
ln -sf "$dir/config/bash/.bashrc" ~/.bashrc
ln -sf "$dir/config/zsh/.zshrc" ~/.zshrc
ln -sf "$dir/config/zsh/.zshrc.d" ~/.zshrc.d
ln -sf "$dir/config/zsh/.p10k.zsh" ~/.p10k.zsh
ln -sf "$dir/config/zsh/alias.sh" ~/alias.sh
ln -sf "$dir/config/vim/.vimrc" ~/.vimrc
ln -sf "$dir/config/nvim" ~/.config/nvim
ln -sf "$dir/config/tmux/base.conf" ~/.tmux.conf
ln -sf "$dir/script" ~/
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
  echo "Removing existing powerlevel10k directory..."
  sudo rm -rf "$P10K_DIR"
fi
sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"

