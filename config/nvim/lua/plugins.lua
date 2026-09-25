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
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "edge",
        globalstatus = true,
        component_separators = "│",
        section_separators = "",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
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
      update_focused_file = { enable = true, update_root = true },
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
      { "<C-p>", "<cmd>FzfLua files<CR>", desc = "Find files" },
      { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "Search text in project" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<CR>", desc = "Search word under cursor" },
      { "<leader>fw", "<cmd>FzfLua grep_visual<CR>", mode = "v", desc = "Search selection" },
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
    "coder/claudecode.nvim",
    lazy = false,
    cond = function() return vim.fn.executable("claude") == 1 end,
    opts = { terminal = { split_side = "right", split_width_percentage = 0.30 } },
  },
}
