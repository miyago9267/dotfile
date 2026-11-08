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

  if vim.fn.has("win32") == 1 then
    -- :terminal 與 :! 改走 PowerShell 7，不落回 cmd.exe
    if vim.fn.executable("pwsh") == 1 then
      vim.opt.shell = "pwsh"
      vim.opt.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';"
      vim.opt.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'
      vim.opt.shellpipe = '2>&1 | %%{ "$_" } | Tee-Object %s; exit $LastExitCode'
      vim.opt.shellquote = ""
      vim.opt.shellxquote = ""
    end
    -- tree-sitter CLI 在 Windows 預設找 MSVC cl.exe；有 mingw gcc 時改用它編 parser
    if not vim.env.CC and vim.fn.executable("cl") == 0 and vim.fn.executable("gcc") == 1 then
      vim.env.CC = "gcc"
    end
  end

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = vim.api.nvim_create_augroup("miyago_core", { clear = true }),
    callback = function() vim.cmd("silent! checktime") end,
  })
end

return M
