#!/bin/sh
Y="\033[1;33m"
N="\033[0m"
echo "${Y}Building link to dotfiles${N}"
mkdir -p ~/.config
dir="$HOME/dotfile"
ln -sf "$dir/.bashrc" ~/.bashrc
ln -sf "$dir/.zshrc" ~/.zshrc
ln -sf "$dir/.zshrc.d" ~/.zshrc.d
ln -sf "$dir/.p10k.zsh" ~/.p10k.zsh
ln -sf "$dir/.vimrc" ~/.vimrc
ln -sf "$dir/.tmux.conf" ~/.tmux.conf
ln -sf "$dir/nvim" ~/.config
ln -sf "$dir/script" ~/
ln -sf "$dir/alias.sh" ~/alias.sh
sudo cp "$dir/script/printcat" /usr/local/bin
sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

