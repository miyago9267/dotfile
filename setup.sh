#!/bin/bash

# Safe, plz remove belove line if u need to start install
exit

# color
Y='\033[1;33m'
R='\033[0;31m'
B='\033[1;34m'
N='\033[0m'

printf "${Y}Installing\n${N}"

# Install all packages you need
## From package manager
if [ -x "$(command -v apt)" ]; then
    cmd="sudo apt install"
    packages=("zsh git curl neovim gawk tmux libtool autoconf automake cmake libncurses5-dev g++ clang")
elif [ -x "$(command -v pacman)" ]; then
    cmd="sudo pacman -S --noconfirm"
    packages=("zsh git curl neovim python-pynvim tmux cmake g++ clang")
elif [ -x "$(command -v brew)" ]; then
    cmd="brew install"
    packages=("zsh curl git tmux")
else 
    printf "${R}No package manager found\n${N}"
    exit
fi 

for pkg in $packages; do
    printf "${Y}Installing ${pkg}${N}\n"
    eval "$cmd $pkg"
done

## Zsh & Zplug
curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh


## install powerline
pip install --user powerline-status


# Install font
curl -LO https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
mkdir -p ~/.local/share/fonts
old_filename=`ls | grep ttf`
new_filename=`echo $old_filename | sed "s/%20/ /g"`
mv "$old_filename" "$new_filename"
mv "$new_filename" ~/.local/share/fonts
sudo fc-cache -f -vi

# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Install PyEnv
git clone https://github.com/pyenv/pyenv.git ~/.pyenv

# get p10k.
sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# build link
printf "${Y}Building link to dotfiles${N}\n"
mkdir -p ~/.config
dir=$(dirname "$(realpath "$0")")
ln -sf $dir/.bashrc ~/.bashrc
ln -sf $dir/.zshrc ~/.zshrc
ln -sf $dir/.p10k.zsh ~/.p10k.zsh
ln -sf $dir/.vimrc ~/.vimrc
ln -sf $dir/.tmux.conf ~/.tmux.conf
ln -sf $dir/nvim ~/.config
ln -sf $dir/script ~/script
ln -sf $dir/alias.sh ~/alias.sh

## setup zsh & zplug
if [ ! -x "$(command -v zsh)" ]; then
   chsh -s $(which zsh)
fi

zsh -c 'source ~/.zshrc;'

## Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# Setup everything
## setup nodejs
## i cant fix the problem that happen when source zshrc in script
nvm install 18
nvm use 18
npm install
npm install npm@latest -g
npm install yarn@latest -g

## setup vim plug
git clone https://github.com/github/copilot.vim.git \
  ~/.config/nvim/pack/github/start/copilot.vim

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall
vim +Copilot +setup



## setup vim
printf "${Y}Setting up Vim\n${N}"
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Done!
printf "${Y}Finished!\n${B}Please restart your device to apply\n${N}"
