local M = {}

function M.setup()
  vim.g.mapleader = " "
  vim.g.maplocalleader = " "
  vim.g.deprecation_warnings = false
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.termguicolors = true
  vim.opt.clipboard = "unnamedplus"
  vim.opt.tabstop = 4
  vim.opt.shiftwidth = 4
  vim.opt.expandtab = true
  vim.opt.smartindent = true
  vim.opt.cursorline = true
  vim.opt.scrolloff = 5
  vim.opt.signcolumn = "yes"
  vim.opt.updatetime = 300
  vim.opt.timeoutlen = 500
  vim.opt.mouse = "a"
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
  vim.opt.splitbelow = true
  vim.opt.splitright = true
  vim.opt.laststatus = 3
  vim.opt.showmode = false
  vim.opt.autoread = true
  vim.opt.confirm = true
  vim.opt.undofile = true
  vim.opt.swapfile = false
  vim.opt.backup = false
  vim.opt.writebackup = false
  vim.opt.completeopt = { "menu", "menuone", "noselect" }

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = vim.api.nvim_create_augroup("miyago_core", { clear = true }),
    callback = function() vim.cmd("silent! checktime") end,
  })
end

return M
