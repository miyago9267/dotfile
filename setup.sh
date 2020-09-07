#!/bin/bash

exit

Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

printf "${YELLOW}Installing\n${NC}"

# installing curl && git
sudo apt install curl git

# build link
printf "${Y}Building link to dotfiles${N}\n"
filepath=$(realpath "$0")
dir=$(dirname "$filepath")
ln -sf $dir/.bashrc ~/.bashrc
ln -sf $dir/.vimrc ~/.vimrc

# install powerline
sudo apt-get install python-pip git
pip install --user powerline-status

# setup font
wget https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf
wget https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf
mkdir -p ~/.font/
mv PowerlineSymbols.otf ~/.fonts/
fc-cache -vf ~/.fonts/
mkdir -p ~/.config/
mkdir -p ~/.config/fontconfig/
mkdir -p ~/.config/fontconfig/conf.d/
mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/

# setup vundle
printf "${Y}Setting up Vundle for vim\n${N}"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall

# fin
printf "${Y}Finished!\nPlease restart your device to apply\n${N}"
