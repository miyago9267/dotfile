local function copilot_ready()
  if vim.fn.executable("node") ~= 1 then
    return false
  end

  local xdg_config = vim.env.XDG_CONFIG_HOME
  local config_dir = xdg_config and xdg_config ~= "" and xdg_config or vim.fn.expand("~/.config")
  return vim.fn.filereadable(config_dir .. "/github-copilot/apps.json") == 1
end

return {
  {
    "sainnhe/edge",
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.edge_style = "neon"
      vim.g.edge_enable_italic = true
      vim.g.edge_disable_italic_comment = true
      vim.cmd.colorscheme("edge")
    end,
  },
  {
    -- 對齊 p10k lean：透明底、無分隔箭頭、只靠前景色區分 segment
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("config.statusline").setup()
    end,
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 200,
      spec = {
        { "<leader>a", group = "Agent" },
        { "<leader>b", group = "Buffer" },
        { "<leader>d", group = "Diagnostics" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>t", group = "Terminal" },
        { "<leader>u", group = "UI toggle" },
        { "<leader>w", group = "Window" },
      },
    },
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        mode = "buffers",
        numbers = "ordinal",
        diagnostics = "nvim_lsp",
        separator_style = "slant",
        always_show_bufferline = true,
        show_buffer_close_icons = true,
        show_close_icon = false,
        right_mouse_command = "bdelete %d",
        middle_mouse_command = "bdelete %d",
        offsets = {
          {
            filetype = "NvimTree",
            text = "File Tree",
            text_align = "left",
            separator = true,
          },
        },
      },
    },
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      hijack_cursor = true,
      sync_root_with_cwd = true,
      update_focused_file = {
        enable = true,
        update_root = true,
        -- workspace 中由 config.workspace 接手定位，避免 root 跳到真實 repo
        exclude = function(event) return require("config.workspace").tree_exclude(event) end,
      },
      on_attach = function(bufnr) require("config.workspace").tree_on_attach(bufnr) end,
      view = { width = 32, side = "left" },
      renderer = { group_empty = true, highlight_git = "name" },
      filters = { dotfiles = false },
    },
  },
  {
    -- 全域搜尋：與 Vim 共用 fzf binary，內容搜尋走 rg
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    keys = {
      -- 走 config.workspace：workspace 中會跟進 hub 裡的 symlink，平常行為不變
      { "<C-p>", function() require("config.workspace").fzf("files") end, desc = "Find files" },
      { "<leader>ff", function() require("config.workspace").fzf("files") end, desc = "Find files" },
      { "<leader>fg", function() require("config.workspace").fzf("live_grep") end, desc = "Search text in project" },
      { "<leader>fw", function() require("config.workspace").fzf("grep_cword") end, desc = "Search word under cursor" },
      { "<leader>fw", function() require("config.workspace").fzf("grep_visual") end, mode = "v", desc = "Search selection" },
      { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "Find buffers" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<CR>", desc = "Recent files" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      -- GitLens 風格：游標所在行尾顯示 blame
      current_line_blame = true,
      current_line_blame_opts = { delay = 300, virt_text_pos = "eol" },
      current_line_blame_formatter = "   <author>, <author_time:%R> • <summary>",
    },
    keys = {
      { "<leader>gb", "<cmd>Gitsigns blame_line full=true<CR>", desc = "Blame current line" },
      { "<leader>gB", "<cmd>Gitsigns blame<CR>", desc = "Blame whole file" },
      { "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", desc = "Preview hunk" },
      { "<leader>gt", "<cmd>Gitsigns toggle_current_line_blame<CR>", desc = "Toggle inline blame" },
      { "]h", "<cmd>Gitsigns next_hunk<CR>", desc = "Next git hunk" },
      { "[h", "<cmd>Gitsigns prev_hunk<CR>", desc = "Prev git hunk" },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
    },
    config = function()
      require("config.completion").setup_cmp()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("config.lsp").setup()
    end,
  },
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    cond = copilot_ready,
    config = function()
      require("config.completion").setup_copilot()
    end,
    keys = {
      { "<leader>ap", "<cmd>CopilotToggle<CR>", desc = "Toggle Copilot suggestions" },
    },
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>" },
      { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
    },
  },
  {
    -- main branch 需要 tree-sitter CLI 編 parser；沒有 CLI 時只用 Neovim 內建 parser
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local langs = {
        "bash", "c", "css", "diff", "dockerfile", "gitcommit", "go", "gomod", "hcl",
        "html", "javascript", "json", "lua", "markdown", "markdown_inline", "python",
        "query", "regex", "rust", "terraform", "toml", "tsx", "typescript", "vim",
        "vimdoc", "vue", "xml", "yaml",
      }
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(langs)
      end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("miyago_treesitter", { clear = true }),
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { show_start = false, show_end = false },
      exclude = { filetypes = { "help", "lazy", "NvimTree", "trouble", "which-key" } },
    },
  },
  {
    -- VSCode 的 Problems 面板
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>dd", "<cmd>Trouble diagnostics toggle<CR>", desc = "Problems (project)" },
      { "<leader>db", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Problems (buffer)" },
      { "<leader>ds", "<cmd>Trouble symbols toggle focus=false<CR>", desc = "Symbols outline" },
      { "<leader>dr", "<cmd>Trouble lsp toggle focus=false win.position=right<CR>", desc = "LSP references" },
      { "<leader>dl", function() vim.diagnostic.open_float() end, desc = "Line diagnostics" },
    },
  },
  {
    -- 存檔自動 format；沒裝對應 formatter 時退回 LSP format
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format", "black", stop_after_first = true },
        go = { "goimports", "gofmt", stop_after_first = true },
        rust = { "rustfmt" },
        sh = { "shfmt" },
        toml = { "taplo" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        vue = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },
      },
      default_format_opts = { lsp_format = "fallback" },
      format_on_save = function()
        if vim.g.miyago_autoformat == false then
          return
        end
        return { timeout_ms = 1000 }
      end,
    },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, mode = { "n", "v" }, desc = "Format" },
      {
        "<leader>uF",
        function()
          vim.g.miyago_autoformat = vim.g.miyago_autoformat == false
          vim.notify("Format on save: " .. (vim.g.miyago_autoformat and "on" or "off"))
        end,
        desc = "Toggle format on save",
      },
    },
  },
  {
    "coder/claudecode.nvim",
    lazy = false,
    cond = function() return vim.fn.executable("claude") == 1 end,
    opts = { terminal = { split_side = "right", split_width_percentage = 0.30 } },
  },
}
