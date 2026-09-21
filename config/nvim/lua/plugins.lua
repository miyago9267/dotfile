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
        { "<leader>t", group = "Terminal" },
        { "<leader>u", group = "UI toggle" },
        { "<leader>w", group = "Window alias" },
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
  { "lewis6991/gitsigns.nvim", opts = {} },
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
