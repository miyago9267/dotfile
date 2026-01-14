-- ~/.config/nvim/init.lua
-- 改进版配置 - 整合 mars.nvim 和 avante.nvim 功能

-- =====================
--   基础设置
-- =====================
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- 禁用 lspconfig deprecation 警告
vim.g.deprecation_warnings = false
vim.lsp.set_log_level("ERROR")  -- 只顯示錯誤，隱藏警告
-- Neovim UI 设置
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
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.laststatus = 3  -- 全局状态栏 (avante.nvim 推荐)

-- =====================
--   加载原有 .vimrc
-- =====================
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.cmd("silent! source ~/.vimrc")
    vim.cmd("runtime! plugin/**/*.vim")
    -- 启动时不自动打开 NERDTree，改为手动 F4 触发
  end
})

-- =====================
--   Lazy.nvim 初始化
-- =====================
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

-- =====================
--   插件配置
-- =====================
require("lazy").setup({
  -- 原有插件保留
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lewis6991/gitsigns.nvim" },
  { "norcalli/nvim-colorizer.lua" },
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "sainnhe/edge" },

  -- === Mars.nvim 借鉴的插件 ===
  
  -- Telescope 模糊查找（核心功能）
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons'
    },
    config = function()
      require('telescope').setup({
        defaults = {
          mappings = {
            i = {
              ['<C-j>'] = require('telescope.actions').move_selection_next,
              ['<C-k>'] = require('telescope.actions').move_selection_previous,
            },
          },
        },
      })
    end,
  },

  -- Leap 快速跳轉
  {
    'ggandor/leap.nvim',
    config = function()
      local leap = require('leap')
      -- 使用新的 mapping 方式
      vim.keymap.set({'n', 'x', 'o'}, 's', '<Plug>(leap-forward)')
      vim.keymap.set({'n', 'x', 'o'}, 'S', '<Plug>(leap-backward)')
      vim.keymap.set({'n', 'x', 'o'}, 'gs', '<Plug>(leap-from-window)')
    end,
  },

  -- vim-tmux-navigator: Neovim 和 tmux 無縫切換
  {
    'christoomey/vim-tmux-navigator',
    lazy = false,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
    },
  },

  -- Which-key 快捷键提示
  {
    'folke/which-key.nvim',
    event = "VeryLazy",
    config = function()
      require("which-key").setup()
    end,
  },

  -- Neogit - Git 界面
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('neogit').setup({})
    end,
  },

  -- Todo comments 高亮
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
    end,
  },

  -- Grug-far 查找替换
  {
    'MagicDuck/grug-far.nvim',
    config = function()
      require('grug-far').setup()
    end,
  },

  -- === Avante.nvim AI 辅助 ===
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-telescope/telescope.nvim",
      -- 如果使用 copilot，需要這個依賴
      {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
          require("copilot").setup({
            suggestion = { enabled = false },
            panel = { enabled = false },
          })
        end,
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
    opts = {
      -- 選擇你的 AI 提供商
      -- provider = "claude",    -- 使用 Claude (需要 AVANTE_ANTHROPIC_API_KEY)
      -- provider = "openai",    -- 使用 OpenAI (需要 AVANTE_OPENAI_API_KEY)
      provider = "copilot",      -- 使用 GitHub Copilot (需要 Copilot 訂閱)
      
      behaviour = {
        auto_suggestions = false,
        auto_set_highlight_group = true,
        auto_apply_diff_after_generation = false,
      },
      mappings = {
        ask = "<leader>aa",
        edit = "<leader>ae",
        refresh = "<leader>ar",
        toggle = {
          default = "<leader>at",
          debug = "<leader>ad",
          hint = "<leader>ah",
          suggestion = "<leader>as",
        },
      },
    },
  },

  -- LSP 支持
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      require('mason').setup()
      require('mason-lspconfig').setup({
        -- gopls 需要 Go >= 1.23.4，暫時移除自動安裝
        ensure_installed = { 'lua_ls', 'ts_ls', 'pyright' }
      })
      
      -- LSP 基礎配置
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      
      -- 暫存 lspconfig 避免 deprecation 警告
      local lspconfig = require('lspconfig')
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.ts_ls.setup({ capabilities = capabilities })
      lspconfig.pyright.setup({ capabilities = capabilities })
      lspconfig.gopls.setup({ capabilities = capabilities })
    end,
  },

  -- Treesitter 語法高亮
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      -- 延遲載入避免模組路徑問題
      vim.schedule(function()
        local ok, configs = pcall(require, 'nvim-treesitter.configs')
        if ok then
          configs.setup({
            ensure_installed = { "lua", "vim", "vimdoc", "javascript", "typescript", "python", "go" },
            sync_install = false,
            auto_install = true,
            highlight = { 
              enable = true,
              additional_vim_regex_highlighting = false,
            },
            indent = { enable = true },
          })
        end
      end)
    end,
  },

  -- Mini.nvim 套件
  {
    'echasnovski/mini.nvim',
    config = function()
      require('mini.surround').setup()
      require('mini.comment').setup()
      require('mini.pairs').setup()
    end,
  },
})

-- =====================
--   插件配置
-- =====================

-- Lualine
require("lualine").setup({
  options = {
    theme = "auto",
    globalstatus = true,
  },
  sections = {
    lualine_c = { 'filename' },
    lualine_x = { 'filetype' },
  },
})

-- NvimTree (保留原有快捷键 F4)
require("nvim-tree").setup({
  view = {
    width = 30,
  },
})

-- Gitsigns
require("gitsigns").setup({
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
})

-- Colorizer
require("colorizer").setup()

-- Bufferline
require("bufferline").setup()

-- =====================
--   快捷键配置
-- =====================

-- 保留原有 F4 快捷键
vim.keymap.set('n', '<F4>', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle NvimTree' })

-- Telescope 快捷键 (来自 mars.nvim)
vim.keymap.set('n', '<C-p>', '<cmd>Telescope find_files<CR>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>sf', '<cmd>Telescope find_files<CR>', { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sg', '<cmd>Telescope live_grep<CR>', { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sb', '<cmd>Telescope buffers<CR>', { desc = '[S]earch [B]uffers' })
vim.keymap.set('n', '<leader>sh', '<cmd>Telescope help_tags<CR>', { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', '<cmd>Telescope grep_string<CR>', { desc = '[S]earch current [W]ord' })

-- Neogit
vim.keymap.set('n', '<leader>ng', '<cmd>Neogit<CR>', { desc = '[N]eo[G]it' })

-- Grug-far 查找替换
vim.keymap.set('n', '<leader>gs', '<cmd>GrugFar<CR>', { desc = '[G]rug [S]earch and Replace' })

-- LSP 快捷键
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = '[G]oto [D]efinition' })
vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc = '[G]oto [R]eferences' })
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = '[G]oto [I]mplementation' })
vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = 'Hover Documentation' })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = '[R]e[n]ame' })
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = '[C]ode [A]ction' })

-- Buffer 导航
vim.keymap.set('n', '[b', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<CR>', { desc = 'Next buffer' })

-- 分屏导航 (保持与 tmux 兼容)
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to left split' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to bottom split' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to top split' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to right split' })

-- =====================
--   配色方案
-- =====================
vim.cmd("colorscheme edge")
