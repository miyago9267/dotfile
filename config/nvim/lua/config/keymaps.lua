local M = {}

local function terminal_toggle()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "terminal" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  vim.cmd("botright split | resize 12 | terminal")
  vim.cmd("startinsert")
end

local function shell_command(opts)
  if opts.args == "" then
    vim.cmd("botright split | resize 12 | terminal")
  else
    vim.cmd("botright split | resize 12 | terminal " .. opts.args)
  end
  vim.cmd("startinsert")
end

local function toggle_numbers()
  vim.opt.number = not vim.opt.number:get()
  vim.opt.relativenumber = vim.opt.number:get()
end

local function toggle_transparency()
  vim.g.miyago_transparent = not vim.g.miyago_transparent
  if vim.g.miyago_transparent then
    vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
    vim.cmd("highlight NormalFloat guibg=NONE ctermbg=NONE")
    vim.cmd("highlight SignColumn guibg=NONE ctermbg=NONE")
    vim.cmd("highlight EndOfBuffer guibg=NONE ctermbg=NONE")
    vim.cmd("highlight NvimTreeNormal guibg=NONE ctermbg=NONE")
  else
    vim.cmd.colorscheme("edge")
  end
end

local function tree_toggle()
  if vim.fn.exists(":NvimTreeToggle") == 2 then
    vim.cmd("NvimTreeToggle")
  else
    vim.notify("file tree unavailable", vim.log.levels.WARN)
  end
end

function M.setup()
  local map = vim.keymap.set

  map({ "n", "v", "o" }, "j", "k", { noremap = true, silent = true, desc = "Move up" })
  map({ "n", "v", "o" }, "k", "j", { noremap = true, silent = true, desc = "Move down" })
  map({ "n", "i", "v" }, "<C-s>", "<cmd>write<CR>", { desc = "Save" })
  map("n", "<C-z>", "u", { desc = "Undo" })
  map("i", "<C-z>", "<C-o>u", { desc = "Undo" })
  map("n", "<C-f>", "/", { desc = "Search in file" })
  map("n", "<D-f>", "/", { desc = "Search in file" })
  map("n", "<C-e>", tree_toggle, { desc = "Toggle file tree" })
  map("n", "<D-b>", tree_toggle, { desc = "Toggle file tree" })
  map("n", "<leader>tt", terminal_toggle, { desc = "Toggle terminal" })
  map("n", "<C-,>", terminal_toggle, { desc = "Toggle terminal" })
  map("n", "<leader>ts", "<cmd>Shell<CR>", { desc = "Open shell" })

  vim.api.nvim_create_user_command("Shell", shell_command, {
    nargs = "*",
    complete = "shellcmd",
    desc = "Run a shell command in a terminal split",
  })

  map("n", "<leader>un", toggle_numbers, { desc = "Toggle line numbers" })
  map("n", "<leader>uf", tree_toggle, { desc = "Toggle file tree" })
  map("n", "<leader>ub", toggle_transparency, { desc = "Toggle transparent background" })
  map("n", "<leader>uc", function() vim.opt.cursorline = not vim.opt.cursorline:get() end, { desc = "Toggle cursorline" })

  -- F-keys remain compatibility aliases for older keyboards and remote sessions.
  map("n", "<F1>", toggle_transparency, { desc = "Toggle transparent background" })
  map("n", "<F3>", toggle_numbers, { desc = "Toggle line numbers" })
  map("n", "<F4>", tree_toggle, { desc = "Toggle file tree" })
  map("n", "<F12>", "<C-]>", { desc = "Jump to tag definition" })

  vim.api.nvim_create_user_command("ToggleNumber", toggle_numbers, { desc = "Toggle line numbers" })
  vim.api.nvim_create_user_command("ToggleFileTree", tree_toggle, { desc = "Toggle file tree" })
  vim.api.nvim_create_user_command("ToggleTransparency", toggle_transparency, { desc = "Toggle transparent background" })
  vim.api.nvim_create_user_command("ToggleCursorline", function()
    vim.opt.cursorline = not vim.opt.cursorline:get()
  end, { desc = "Toggle cursorline" })

  map("n", "<leader>bb", "<cmd>buffers<CR>", { desc = "List buffers" })
  map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
  map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
  map("n", "<C-Left>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
  map("n", "<C-Right>", "<cmd>bnext<CR>", { desc = "Next buffer" })
  map("n", "<leader>bc", "<cmd>enew<CR>", { desc = "New buffer" })
  map("n", "<leader>bx", "<cmd>bdelete<CR>", { desc = "Close buffer" })
  map("n", "<leader>wv", "<cmd>vsplit<CR>", { desc = "Vertical split" })
  map("n", "<leader>ws", "<cmd>split<CR>", { desc = "Horizontal split" })
  map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
  map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
  map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
  map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
  map("n", "<C-\\>", "<C-w>p", { desc = "Previous window" })
  map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Terminal normal mode" })

end

return M
