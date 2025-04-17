#!/bin/sh
git clone https://github.com/github/copilot.vim.git   ~/.config/nvim/pack/github/start/copilot.vim

curl -fLo ~/.vim/autoload/plug.vim --create-dirs   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +PlugInstall +qall
vim +Copilot +setup
curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" --create-dirs   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
