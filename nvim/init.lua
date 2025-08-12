-- ~/.config/nvim/init.lua

-- Neovim 專屬 UI 設定
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.clipboard = 'unnamedplus'
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.scrolloff = 5
vim.opt.signcolumn = "yes"
vim.g.mapleader = " "


vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.cmd("silent! source ~/.vimrc")
    vim.cmd("runtime! plugin/**/*.vim")
    vim.cmd("silent! NERDTree | wincmd p")
  end
})

-- lazy.nvim plugin manager 初始化
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "nvim-lualine/lualine.nvim", opts = {} },
  { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lewis6991/gitsigns.nvim" },
  { "norcalli/nvim-colorizer.lua" },
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "sainnhe/edge" },
})

-- 插件初始化（Neovim only）
require("lualine").setup({
  options = {
    theme = "auto",
    section_separators = '',
    component_separators = ''
  }
})

require("nvim-tree").setup()

-- 啟動自動開啟 nvim-tree
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("nvim-tree.api").tree.open()
  end
})

-- <F4> 綁定為 nvim-tree 開關，與 .vimrc NERDTreeToggle 行為一致
vim.keymap.set('n', '<F4>', function()
  require("nvim-tree.api").tree.toggle()
end, { noremap = true, silent = true })
require("gitsigns").setup()
require("colorizer").setup()
require("bufferline").setup()

-- 使用 Neovim colorscheme
vim.cmd("colorscheme edge")
