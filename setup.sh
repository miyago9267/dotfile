#!/bin/bash

# Safe
exit

# color
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

printf "${Y}Installing\n${N}"

# installing curl && git
if [ -x "$(command -v apt)" ]; then
    cmd="sudo apt install"
    packages=("zsh" "git" "curl" "neovim" "gawk" "tmux" "libtool" "autoconf" "automake" "cmake" "libncurses5-dev" "g++" "clang")
elif [ -x "$(command -v pacman)" ]; then
    cmd="pacman -S --noconfirm"
    packages=("zsh" "git" "curl" "neovim" "python-pynvim" "tmux" "cmake" "g++" "clang")
else 
    printf "${R}No package manager found\n${N}"
    exit
fi 

for pkg in $packages; do
    printf "${Y}Installing ${pkg}\n"
    eval "$cmd $package"
done

curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
# install zsh & zplug
if [ ! -x "$(command -v zsh)" ]; then
   chsh -s $(which zsh)
fi

# install powerline
pip install --user powerline-status

# setup font
mkdir -p ~/.local/share/fonts
curl -LO https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
old_filename=`ls | grep ttf`
new_filename=`echo $old_filename | sed "s/%20/ /g"`
mv "$old_filename" "$new_filename"
mv "$new_filename" ~/.local/share/fonts
sudo fc-cache -f -v

# get p10k.
sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# build link
printf "${Y}Building link to dotfiles${N}\n"
mkdir ~/.config
filepath=$(realpath "$0")
dir=$(dirname "$filepath")
mkdir -p ~/.config/nvim
ln -sf $dir/.bashrc ~/.bashrc
ln -sf $dir/.zshrc ~/.zshrc
ln -sf $dir/.p10k.zsh ~/.p10k.zsh
ln -sf $dir/.vimrc ~/.vimrc
ln -sf $dir/.tmux.conf ~/.tmux.conf
ln -sf $dir/nvim ~/.config/nvim
ln -sf $dir/script ~/script

# setup vim plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall

# setup vim
printf "${Y}Setting up Vim\n${N}"
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# fin
printf "${Y}Finished!\nPlease restart your device to apply\n${N}"
