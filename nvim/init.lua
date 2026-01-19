-- ~/.config/nvim/init.lua

-- =====================
--   Base Settings
-- =====================
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.deprecation_warnings = false
vim.lsp.set_log_level("ERROR")
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
vim.opt.laststatus = 3

-- =====================
--   Load .vimrc
-- =====================
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.cmd("silent! source ~/.vimrc")
    vim.cmd("runtime! plugin/**/*.vim")
  end
})

-- =====================
--   Lazy.nvim Initialization
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
--   Plugin Setting
-- =====================
require("lazy").setup({
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lewis6991/gitsigns.nvim" },
  { "norcalli/nvim-colorizer.lua" },
  { "akinsho/bufferline.nvim", version = "*", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "sainnhe/edge" },
  
  -- nerdcommenter for VSCode-style commenting
  { "preservim/nerdcommenter" },

  -- === Mars.nvim ===
  
  -- Telescope
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
      vim.keymap.set({'n', 'x', 'o'}, 's', '<Plug>(leap-forward)')
      vim.keymap.set({'n', 'x', 'o'}, 'S', '<Plug>(leap-backward)')
      vim.keymap.set({'n', 'x', 'o'}, 'gs', '<Plug>(leap-from-window)')
    end,
  },

  -- vim-tmux-navigator
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

  -- Which-key
  {
    'folke/which-key.nvim',
    event = "VeryLazy",
    config = function()
      require("which-key").setup()
    end,
  },

  -- Neogit
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

  -- Todo comments Highlight
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
    end,
  },

  -- Grug-far 
  {
    'MagicDuck/grug-far.nvim',
    config = function()
      require('grug-far').setup()
    end,
  },

  -- === Avante.nvim AI ===
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
      -- provider = "claude",
      -- provider = "openai",
      provider = "copilot", 
      
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

  -- LSP
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
      
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      
      -- 使用 lspconfig
      local lspconfig = require('lspconfig')
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.ts_ls.setup({ capabilities = capabilities })
      lspconfig.pyright.setup({ capabilities = capabilities })
      lspconfig.gopls.setup({ capabilities = capabilities })
    end,
  },

  -- Treesitter Highlighting
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
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

  -- Mini.nvim
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
--   Plugin Setting
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

-- NvimTree
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
--   Keybindings
-- =====================

-- Nerdtree
vim.keymap.set('n', '<F4>', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle NvimTree' })

-- Telescope
vim.keymap.set('n', '<C-p>', '<cmd>Telescope find_files<CR>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>sf', '<cmd>Telescope find_files<CR>', { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sg', '<cmd>Telescope live_grep<CR>', { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sb', '<cmd>Telescope buffers<CR>', { desc = '[S]earch [B]uffers' })
vim.keymap.set('n', '<leader>sh', '<cmd>Telescope help_tags<CR>', { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', '<cmd>Telescope grep_string<CR>', { desc = '[S]earch current [W]ord' })

-- Neogit
vim.keymap.set('n', '<leader>ng', '<cmd>Neogit<CR>', { desc = '[N]eo[G]it' })

-- Grug-far
vim.keymap.set('n', '<leader>gs', '<cmd>GrugFar<CR>', { desc = '[G]rug [S]earch and Replace' })

-- LSP 快捷键
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = '[G]oto [D]efinition' })
vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc = '[G]oto [R]eferences' })
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = '[G]oto [I]mplementation' })
vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = 'Hover Documentation' })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = '[R]e[n]ame' })
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = '[C]ode [A]ction' })

-- Buffer
vim.keymap.set('n', '[b', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<CR>', { desc = 'Next buffer' })

-- Window navigation is handled by vim-tmux-navigator plugin
-- The plugin already defines <C-h/j/k/l> for seamless navigation between Neovim and tmux

-- VSCode style features
-- Alt + move lines up/down
vim.keymap.set('n', '<A-Up>', ':m .-2<CR>==', { desc = 'Move line up (VSCode style)' })
vim.keymap.set('n', '<A-Down>', ':m .+1<CR>==', { desc = 'Move line down (VSCode style)' })
vim.keymap.set('i', '<A-Up>', '<Esc>:m .-2<CR>==gi', { desc = 'Move line up in insert mode' })
vim.keymap.set('i', '<A-Down>', '<Esc>:m .+1<CR>==gi', { desc = 'Move line down in insert mode' })
vim.keymap.set('v', '<A-Up>', ":m '<-2<CR>gv=gv", { desc = 'Move selected lines up' })
vim.keymap.set('v', '<A-Down>', ":m '>+1<CR>gv=gv", { desc = 'Move selected lines down' })

-- Ctrl + / to toggle comments
vim.keymap.set('n', '<C-/>', '<Plug>NERDCommenterToggle', { desc = 'Toggle comment (VSCode style)' })
vim.keymap.set('n', '<D-/>', '<Plug>NERDCommenterToggle', { desc = 'Toggle comment (Mac Cmd+/)' })
vim.keymap.set('v', '<C-/>', '<Plug>NERDCommenterToggle', { desc = 'Toggle comment for selection' })
vim.keymap.set('v', '<D-/>', '<Plug>NERDCommenterToggle', { desc = 'Toggle comment for selection (Mac)' })
vim.keymap.set('i', '<C-/>', '<Esc><Plug>NERDCommenterToggle gi', { desc = 'Toggle comment in insert mode' })
vim.keymap.set('i', '<D-/>', '<Esc><Plug>NERDCommenterToggle gi', { desc = 'Toggle comment in insert mode (Mac)' })

-- VSCode style cursor movement (smart jump at file boundaries)
local function smart_cursor_move(key)
  local current_line = vim.fn.line('.')
  local total_lines = vim.fn.line('$')
  
  if key == 'j' or key == '<Down>' then
    if current_line >= total_lines then
      vim.cmd('normal! $')
    else
      vim.cmd('normal! ' .. key)
    end
  elseif key == 'k' or key == '<Up>' then
    if current_line <= 1 then
      vim.cmd('normal! 0')
    else
      vim.cmd('normal! ' .. key)
    end
  end
end

vim.keymap.set('n', 'j', function() smart_cursor_move('j') end, { desc = 'Smart down (VSCode style)' })
vim.keymap.set('n', 'k', function() smart_cursor_move('k') end, { desc = 'Smart up (VSCode style)' })
vim.keymap.set('n', '<Down>', function() smart_cursor_move('<Down>') end, { desc = 'Smart down arrow (VSCode style)' })
vim.keymap.set('n', '<Up>', function() smart_cursor_move('<Up>') end, { desc = 'Smart up arrow (VSCode style)' })

-- =====================
--   Colorscheme
-- =====================
vim.cmd("colorscheme edge")
