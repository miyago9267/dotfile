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
    cond = function() return vim.fn.executable("claude") == 1 end,
    keys = {
      { "<leader>aa", "<cmd>ClaudeCode<CR>", desc = "AI: Claude toggle" },
      { "<leader>as", "<cmd>ClaudeCodeSend<CR>", mode = "v", desc = "AI: send selection" },
    },
    opts = { terminal = { split_side = "right", split_width_percentage = 30 } },
  },
}
