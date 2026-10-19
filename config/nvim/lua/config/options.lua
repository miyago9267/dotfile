local M = {}

function M.setup()
  vim.g.deprecation_warnings = false
  vim.opt.relativenumber = true
  vim.opt.termguicolors = true
  vim.opt.timeoutlen = 500
  vim.opt.ignorecase = true
  vim.opt.smartcase = true
  vim.opt.laststatus = 3
  -- 開關 dock 時編輯器內容不跳動（edgy 建議）
  vim.opt.splitkeep = "screen"
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
