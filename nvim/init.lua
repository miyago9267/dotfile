-- ~/.config/nvim/init.lua

-- 基礎設定
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

-- leader 鍵
vim.g.mapleader = " "

-- lazy.nvim plugin manager
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
  { "nvim-tree/nvim-web-devicons" },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "nvim-telescope/telescope.nvim", tag = '0.1.2', dependencies = { "nvim-lua/plenary.nvim" } },
  { "neovim/nvim-lspconfig" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "jose-elias-alvarez/null-ls.nvim" },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },

  -- 新增對應 .vimrc plugin 替代的 Neovim-native 插件
  { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "preservim/nerdcommenter" }, -- 保留與 Vim 相同的註解體驗
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lewis6991/gitsigns.nvim" }, -- 替代 nerdtree-git-plugin
  { "kyazdani42/nvim-web-devicons" },
  { "norcalli/nvim-colorizer.lua" }, -- 對應 vim-css-color
  { "lukas-reineke/headlines.nvim" }, -- 對應 lightline-trailing-whitespace
  { "mfussenegger/nvim-dap" }, -- 可選：tagbar 的 LSP 替代方案
  { "sainnhe/edge" }, -- 保留 edge colorscheme
})

-- LSP 設定
local lspconfig = require("lspconfig")
lspconfig.tsserver.setup({})
lspconfig.lua_ls.setup({
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } }
    }
  }
})

-- nvim-cmp 設定
local cmp = require("cmp")
cmp.setup({
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end
  },
  mapping = cmp.mapping.preset.insert({
    ['<CR>'] = cmp.mapping.confirm({ select = true })
  }),
  sources = {
    { name = "nvim_lsp" }
  }
})

-- null-ls 設定
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    null_ls.builtins.formatting.prettier,
    null_ls.builtins.diagnostics.eslint
  }
})

-- treesitter 設定
require("nvim-treesitter.configs").setup({
  highlight = { enable = true },
  indent = { enable = true }
})

-- lualine 狀態列
require("lualine").setup({
  options = {
    theme = "auto",
    section_separators = '',
    component_separators = ''
  }
})

-- bufferline
require("bufferline").setup{}

-- gitsigns
require("gitsigns").setup()

-- nvim-tree
require("nvim-tree").setup()

-- nerdcommenter: 保持 keymap 與 Vim 相容性
vim.api.nvim_set_keymap("n", "<leader>c<space>", ":call NERDComment(0, 'toggle')<CR>", { noremap = true, silent = true })

-- colorizer
require("colorizer").setup()

-- edge colorscheme
vim.cmd("colorscheme edge")

-- 若存在 .vimrc，載入其基本設定（不含 plugin）
local vimrc_path = vim.fn.expand("~/.vimrc")
if vim.fn.filereadable(vimrc_path) == 1 then
  vim.cmd("source " .. vimrc_path)
end
