#!/bin/sh

# 安裝 vim-plug（僅限 Vim 使用）
echo "Installing vim-plug for Vim..."
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# 執行 PlugInstall 安裝 Vim 的插件
vim +PlugInstall +qall

# 提醒用戶 Neovim 現已使用 init.lua 與 lazy.nvim 管理 plugin
echo "✅ Vim 插件已安裝完成。Neovim 請透過 ~/.config/nvim/init.lua 自動安裝 Lazy.nvim 插件。"
