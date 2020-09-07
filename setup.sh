#!/bin/bash

exit

Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

printf "${YELLOW}Installing\n${NC}"

" installing curl && git
sudo apt install curl git

" build link
printf "${Y}Building link to dotfiles${N}\n"
filepath=$(realpath "$0")
dir=$(dirname "$filepath")
ln -sf $dir/.bashrc ~/.bashrc
ln -sf $dir/.vimrc ~/.vimrc

# setup vundle
printf "${Y}Setting up Vundle for vim\n${N}"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall

# fin
printf "${Y}Finished!\nPlease restart your device to apply\n${N}"
