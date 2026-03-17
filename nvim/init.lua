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

  -- Toggleterm (VSCode-style integrated terminal)
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    opts = {
      size = 15,
      open_mapping = [[<C-`>]],
      direction = 'horizontal',
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      persist_size = true,
    },
  },

  -- Indent guides (VSCode-style indent lines)
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = { char = '|' },
      scope = { enabled = true, show_start = false, show_end = false },
    },
  },

  -- nvim-cmp autocompletion (VSCode-style autocomplete popup)
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            local copilot = require('copilot.suggestion')
            if copilot.is_visible() then
              copilot.accept()
            elseif cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<C-u>'] = cmp.mapping.scroll_docs(-4),
          ['<C-d>'] = cmp.mapping.scroll_docs(4),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, {
          { name = 'buffer' },
          { name = 'path' },
        }),
      })
    end,
  },

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

  -- Flash.nvim 快速跳轉 + 增強搜尋 (取代 leap.nvim)
  -- 用 / 搜尋時會在每個 match 上顯示 label，按 label 直接跳過去，不用按 n
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {
      modes = {
        search = { enabled = true },  -- 增強 / 和 ? 搜尋
        char = { enabled = true },    -- 增強 f/F/t/T
      },
    },
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash jump' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash treesitter select' },
    },
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
      local wk = require("which-key")
      wk.setup()
      wk.add({
        { "<leader>s", group = "Search" },
        { "<leader>g", group = "Git" },
        { "<leader>c", group = "Code / Claude" },
        { "<leader>n", group = "Neogit" },
        { "<leader>r", group = "Refactor" },
        { "<leader>t", group = "Terminal" },
      })
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

  -- === Claude Code Integration ===
  {
    "coder/claudecode.nvim",
    lazy = false,
    config = function()
      require("claudecode").setup({
        terminal = {
          split_side = "right",
          split_width_percentage = 0.4,
        },
      })
    end,
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<CR>", desc = "Code > Claude toggle" },
      { "<leader>cs", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "Code > Claude send selection" },
    },
  },

  -- === Copilot (從 avante dependencies 獨立出來) ===
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = false,  -- 由 nvim-cmp 的 Tab 統一處理
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = { enabled = false },
      })
    end,
  },

  -- Render Markdown
  {
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {
      file_types = { "markdown" },
    },
    ft = { "markdown" },
  },

  -- === Avante.nvim AI（已停用，改用嵌入式 Claude Code）===
  --[[
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
    },
    opts = {
      provider = vim.env.AVANTE_PROVIDER or "claude-code",
      providers = {
        ["claude-code"] = {
          command = "npx",
          args = { "-y", "@zed-industries/claude-agent-acp" },
          env = {
            NODE_NO_WARNINGS = "1",
            ACP_PATH_TO_CLAUDE_CODE_EXECUTABLE = vim.fn.exepath("claude"),
            ACP_PERMISSION_MODE = "bypassPermissions",
          },
        },
      },
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
  --]]

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
        ensure_installed = { 'lua_ls', 'ts_ls', 'pyright' }
      })
      
      -- 使用相容層設定 LSP,支援 Neovim 0.10 和 0.11+
      require('compat').setup_lsp()
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
vim.keymap.set('n', '<C-p>', '<cmd>Telescope find_files<CR>', { desc = 'Search > Find files' })
vim.keymap.set('n', '<leader>sf', '<cmd>Telescope find_files<CR>', { desc = 'Search > Find files' })
vim.keymap.set('n', '<leader>sg', '<cmd>Telescope live_grep<CR>', { desc = 'Search > Grep' })
vim.keymap.set('n', '<leader>sb', '<cmd>Telescope buffers<CR>', { desc = 'Search > Buffers' })
vim.keymap.set('n', '<leader>sh', '<cmd>Telescope help_tags<CR>', { desc = 'Search > Help tags' })
vim.keymap.set('n', '<leader>sw', '<cmd>Telescope grep_string<CR>', { desc = 'Search > Current word' })

-- Neogit
vim.keymap.set('n', '<leader>ng', '<cmd>Neogit<CR>', { desc = 'Neogit > Open' })

-- Diffview (git tree / file history)
vim.keymap.set('n', '<leader>gd', '<cmd>DiffviewOpen<CR>', { desc = 'Git > Diff view' })
vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', { desc = 'Git > File history' })
vim.keymap.set('n', '<leader>gH', '<cmd>DiffviewFileHistory<CR>', { desc = 'Git > Repo history' })
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewClose<CR>', { desc = 'Git > Diff close' })

-- Grug-far (Search 分組)
vim.keymap.set('n', '<leader>sr', '<cmd>GrugFar<CR>', { desc = 'Search > Replace (Grug-far)' })

-- j/k 交換：j=上 k=下 (Miyago 習慣)
vim.keymap.set({'n', 'v', 'o'}, 'j', 'k', { noremap = true })
vim.keymap.set({'n', 'v', 'o'}, 'k', 'j', { noremap = true })

-- LSP 快捷鍵
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = 'LSP > Go to definition' })
vim.keymap.set('n', 'gr', vim.lsp.buf.references, { desc = 'LSP > References' })
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { desc = 'LSP > Implementation' })
vim.keymap.set('n', 'K', vim.lsp.buf.hover, { desc = 'LSP > Hover documentation' })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = 'Refactor > Rename' })
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code > Action' })

-- Buffer
vim.keymap.set('n', '[b', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<CR>', { desc = 'Next buffer' })

-- Window navigation is handled by vim-tmux-navigator plugin
-- The plugin already defines <C-h/j/k/l> for seamless navigation between Neovim and tmux

-- VSCode style features

-- Ctrl/Cmd + C/X/V/Z/A (VSCode style)
-- Copy (visual mode)
vim.keymap.set('v', '<C-c>', '"+y', { desc = 'Copy (VSCode style)' })
vim.keymap.set('v', '<D-c>', '"+y', { desc = 'Copy (Mac Cmd+C)' })
-- Cut (visual mode)
vim.keymap.set('v', '<C-x>', '"+d', { desc = 'Cut (VSCode style)' })
vim.keymap.set('v', '<D-x>', '"+d', { desc = 'Cut (Mac Cmd+X)' })
-- Paste (normal/insert mode)
vim.keymap.set('n', '<C-v>', '"+p', { desc = 'Paste (VSCode style)' })
vim.keymap.set('n', '<D-v>', '"+p', { desc = 'Paste (Mac Cmd+V)' })
vim.keymap.set('i', '<C-v>', '<C-r>+', { desc = 'Paste in insert mode' })
vim.keymap.set('i', '<D-v>', '<C-r>+', { desc = 'Paste in insert mode (Mac)' })
-- Undo
vim.keymap.set('n', '<C-z>', 'u', { desc = 'Undo (VSCode style)' })
vim.keymap.set('i', '<C-z>', '<C-o>u', { desc = 'Undo in insert mode' })
-- Select all
vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select all (VSCode style)' })
vim.keymap.set('n', '<D-a>', 'ggVG', { desc = 'Select all (Mac Cmd+A)' })

-- Sudo save when forgot to use sudo
vim.api.nvim_create_user_command('W', function()
  vim.cmd('w !sudo tee % > /dev/null')
end, { bang = true, desc = 'Save with sudo' })

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

-- 保留 vim 原生的移動行為
-- 方向鍵和 hjkl 都可以正常使用,沒有額外的智慧移動功能

-- 平板友善的方向鍵替代方案 (Alt + IJKL)
-- 適合在沒有實體方向鍵的環境使用,不會與 vim 預設快捷鍵衝突
vim.keymap.set({'n', 'i', 'v'}, '<A-i>', '<Up>', { desc = '上移 (平板友善)' })
vim.keymap.set({'n', 'i', 'v'}, '<A-k>', '<Down>', { desc = '下移 (平板友善)' })
vim.keymap.set({'n', 'i', 'v'}, '<A-j>', '<Left>', { desc = '左移 (平板友善)' })
vim.keymap.set({'n', 'i', 'v'}, '<A-l>', '<Right>', { desc = '右移 (平板友善)' })

-- VSCode-style: Ctrl+F / Cmd+F for in-file search/replace panel
vim.keymap.set('n', '<C-f>', function() require('vsearch').open() end, { desc = 'Search in file' })
vim.keymap.set('n', '<D-f>', function() require('vsearch').open() end, { desc = 'Search in file (Mac)' })

-- VSCode-style: Ctrl+S / Cmd+S to save
vim.keymap.set({'n', 'i', 'v'}, '<C-s>', '<cmd>w<CR>', { desc = 'Save file' })
vim.keymap.set({'n', 'i', 'v'}, '<D-s>', '<cmd>w<CR>', { desc = 'Save file (Mac)' })

-- VSCode-style: Ctrl+B / Cmd+B to toggle sidebar
vim.keymap.set('n', '<C-b>', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle sidebar' })
vim.keymap.set('n', '<D-b>', '<cmd>NvimTreeToggle<CR>', { desc = 'Toggle sidebar (Mac)' })

-- VSCode-style: Ctrl+Shift+F / Cmd+Shift+F for global search
vim.keymap.set('n', '<C-S-f>', '<cmd>Telescope live_grep<CR>', { desc = 'Global search' })
vim.keymap.set('n', '<D-S-f>', '<cmd>Telescope live_grep<CR>', { desc = 'Global search (Mac)' })

-- VSCode-style: Ctrl+Shift+P / Cmd+Shift+P for command palette
vim.keymap.set('n', '<C-S-p>', '<cmd>Telescope commands<CR>', { desc = 'Command palette' })
vim.keymap.set('n', '<D-S-p>', '<cmd>Telescope commands<CR>', { desc = 'Command palette (Mac)' })

-- VSCode-style: Ctrl+Shift+H / Cmd+Shift+H for search and replace
vim.keymap.set('n', '<C-S-h>', '<cmd>GrugFar<CR>', { desc = 'Search > Replace (Grug-far)' })
vim.keymap.set('n', '<D-S-h>', '<cmd>GrugFar<CR>', { desc = 'Search > Replace (Grug-far, Mac)' })

-- VSCode-style: Alt+Shift+Up/Down to duplicate line
vim.keymap.set('n', '<A-S-Up>', '<cmd>t .-1<CR>', { desc = 'Duplicate line up' })
vim.keymap.set('n', '<A-S-Down>', '<cmd>t .<CR>', { desc = 'Duplicate line down' })
vim.keymap.set('i', '<A-S-Up>', '<Esc><cmd>t .-1<CR>gi', { desc = 'Duplicate line up (insert)' })
vim.keymap.set('i', '<A-S-Down>', '<Esc><cmd>t .<CR>gi', { desc = 'Duplicate line down (insert)' })
vim.keymap.set('v', '<A-S-Up>', ":t '<-1<CR>gv", { desc = 'Duplicate selection up' })
vim.keymap.set('v', '<A-S-Down>', ":t '><CR>gv", { desc = 'Duplicate selection down' })

-- VSCode-style: Ctrl+Shift+K to delete line
vim.keymap.set('n', '<C-S-k>', '<cmd>d<CR>', { desc = 'Delete line' })
vim.keymap.set('i', '<C-S-k>', '<Esc><cmd>d<CR>gi', { desc = 'Delete line (insert)' })

-- VSCode-style: F2 for rename, F12 for go to definition
vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, { desc = 'Rename symbol' })
vim.keymap.set('n', '<F12>', vim.lsp.buf.definition, { desc = 'Go to definition' })

-- Fn 鍵替代方案（MacBook / iPad 沒有實體 Fn 鍵）
-- F2 (Rename)  -> Space r n 或 Space r r
-- F4 (NvimTree) -> Ctrl+B / Cmd+B
-- F12 (Definition) -> gd
vim.keymap.set('n', '<leader>rr', vim.lsp.buf.rename, { desc = 'Refactor > Rename (F2 替代)' })

-- VSCode-style: Ctrl+Tab / Ctrl+Shift+Tab for buffer switching
vim.keymap.set('n', '<C-Tab>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<C-S-Tab>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })

-- VSCode-style: Ctrl+Shift+[ / ] for fold/unfold
vim.keymap.set('n', '<C-S-[>', 'zc', { desc = 'Fold' })
vim.keymap.set('n', '<C-S-]>', 'zo', { desc = 'Unfold' })

-- VSCode-style: Cmd+J to toggle bottom terminal (Ctrl+J 已被 tmux-navigator 佔用)
vim.keymap.set({'n', 't'}, '<D-j>', '<cmd>ToggleTerm<CR>', { desc = 'Terminal > Toggle' })
vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<CR>', { desc = 'Terminal > Toggle' })
-- Terminal mode: Esc 跳回 normal mode，再按 Space t t 就能關
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { desc = 'Terminal > Exit to normal' })

-- VSCode-style: Ctrl+Shift+I / Cmd+Shift+I to toggle AI agent sidebar (Avante)
-- 已停用 Avante，改用嵌入式 Claude Code
-- vim.keymap.set('n', '<C-S-i>', '<cmd>AvanteToggle<CR>', { desc = 'Toggle AI sidebar' })
-- vim.keymap.set('n', '<D-S-i>', '<cmd>AvanteToggle<CR>', { desc = 'Toggle AI sidebar (Mac)' })

-- VSCode-style: Ctrl+W / Cmd+W to close current buffer (tab)
vim.keymap.set('n', '<C-w>', '<cmd>bdelete<CR>', { desc = 'Close tab' })
vim.keymap.set('n', '<D-w>', '<cmd>bdelete<CR>', { desc = 'Close tab (Mac)' })

-- VSCode-style: Redo
vim.keymap.set('n', '<C-S-z>', '<C-r>', { desc = 'Redo' })
vim.keymap.set('n', '<D-S-z>', '<C-r>', { desc = 'Redo (Mac)' })
vim.keymap.set('n', '<C-y>', '<C-r>', { desc = 'Redo (Windows style)' })
vim.keymap.set('i', '<C-S-z>', '<C-o><C-r>', { desc = 'Redo in insert mode' })
vim.keymap.set('i', '<D-S-z>', '<C-o><C-r>', { desc = 'Redo in insert mode (Mac)' })

-- VSCode-style: Ctrl+G to go to line
vim.keymap.set('n', '<C-g>', ':', { desc = 'Go to line (輸入行號)' })

-- VSCode-style: Tab / Shift+Tab for indent in visual mode
vim.keymap.set('v', '<Tab>', '>gv', { desc = 'Indent selection' })
vim.keymap.set('v', '<S-Tab>', '<gv', { desc = 'Dedent selection' })

-- =====================
--   Colorscheme
-- =====================
vim.cmd("colorscheme edge")

