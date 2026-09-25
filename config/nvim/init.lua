local vimrc = vim.fn.expand("~/.vimrc")
if vim.fn.filereadable(vimrc) == 1 then
  vim.cmd("silent! source " .. vim.fn.fnameescape(vimrc))
end

-- 太舊的 Neovim（例如 apt 裝的 0.4~0.9）跑不動 plugin 層，只保留 base.vim 的基本設定
if vim.fn.has("nvim-0.10") == 0 then
  vim.api.nvim_echo({ { "Neovim < 0.10: plugins disabled, run setup_neovim.sh to upgrade", "WarningMsg" } }, true, {})
  return
end

require("config.options").setup()

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) and vim.fn.executable("git") == 1 then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end

if vim.loop.fs_stat(lazypath) then
  vim.opt.rtp:prepend(lazypath)
  require("lazy").setup(require("plugins"), {
    change_detection = { notify = false },
    checker = { enabled = false },
  })
else
  vim.notify("lazy.nvim unavailable; running with core Neovim only", vim.log.levels.WARN)
end

require("config.keymaps").setup()
require("config.agent").setup()
