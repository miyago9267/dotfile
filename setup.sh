#!/bin/bash

# Safe
exit

# color
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

printf "${YELLOW}Installing\n${NC}"

# installing curl && git
sudo apt install curl git zsh python python-pip neovim gawk -y


curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
# install zsh & zplug
chsh -s $(which zsh)

# install powerline
pip install --user powerline-status

# nodejs & npm & nvm
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
nvm install node
npm install npm@lastest -g
npm install
npm install yarm
yarm install


# setup font
mkdir -p ~/.local/share/fonts
# curl -LO https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/SourceCodePro/Regular/complete/Sauce%20Code%20Pro%20Nerd%20Font%20Complete%20Mono.ttf
curl -LO https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
old_filename=`ls | grep ttf`
new_filename=`echo $old_filename | sed "s/%20/ /g"`
mv "$old_filename" "$new_filename"
mv "$new_filename" ~/.local/share/fonts
sudo fc-cache -f -v

#setup powerline font
# curl https://github.com/powerline/powerline/raw/develop/font/PowerlineSymbols.otf
# curl https://github.com/powerline/powerline/raw/develop/font/10-powerline-symbols.conf
# mkdir -p ~/.font/
# mkdir -p ~/.config/
# mkdir -p ~/.config/fontconfig/
# mkdir -p ~/.config/fontconfig/conf.d/
# fc-cache -vf ~/.fonts/
# mv PowerlineSymbols.otf ~/.fonts/
# mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/

# get p10k.
sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# build link
printf "${Y}Building link to dotfiles${N}\n"
filepath=$(realpath "$0")
dir=$(dirname "$filepath")
mkdir -p ~/.config/nvim
ln -sf $dir/.bashrc ~/.bashrc
ln -sf $dir/.zshrc ~/.zshrc
ln -sf $dir/.p10k.zsh ~/.p10k.zsh
ln -sf $dir/.vimrc ~/.vimrc
ln -sf $dir/.tmux.conf ~/.tmux.conf
ln -sf $dir/init.vim ~/.config/nvim/init.vim

# setup vim plug
# printf "${Y}Setting up Vundle for vim\n${N}"
# git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall

# setup vim
printf "${Y}Setting up Vim\n${N}"
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# set antigen
# curl -sL git.io/antigen > ~/.antigen.zsh

# fin
printf "${Y}Finished!\nPlease restart your device to apply\n${N}"
