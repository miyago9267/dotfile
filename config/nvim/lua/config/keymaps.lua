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

local function navigate_window(direction, tmux_command)
  if vim.fn.exists(":" .. tmux_command) == 2 then
    vim.cmd(tmux_command)
  else
    vim.cmd("wincmd " .. direction)
  end
end

local zoom_restore

local function toggle_zoom()
  if zoom_restore then
    vim.cmd(zoom_restore)
    zoom_restore = nil
    return
  end

  zoom_restore = vim.fn.winrestcmd()
  vim.cmd("wincmd _")
  vim.cmd("wincmd |")
end

local function resize_width(amount)
  vim.cmd("vertical resize " .. (amount > 0 and "+" .. amount or amount))
end

local function resize_height(amount)
  vim.cmd("resize " .. (amount > 0 and "+" .. amount or amount))
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

  map("n", "<leader>aa", function() require("config.agent").toggle("claude") end, { desc = "Agent: Claude" })
  map("n", "<leader>ac", function() require("config.agent").toggle("codex") end, { desc = "Agent: Codex" })
  map("n", "<leader>ao", function() require("config.agent").toggle("opencode") end, { desc = "Agent: OpenCode" })
  map("n", "<leader>ag", function() require("config.agent").toggle("gemini") end, { desc = "Agent: Gemini" })
  map("v", "<leader>as", function() require("config.agent").send_selection("claude") end, { desc = "Agent: send to Claude" })
  map("v", "<leader>ac", function() require("config.agent").send_selection("codex") end, { desc = "Agent: send to Codex" })
  map("v", "<leader>ao", function() require("config.agent").send_selection("opencode") end, { desc = "Agent: send to OpenCode" })
  map("v", "<leader>ag", function() require("config.agent").send_selection("gemini") end, { desc = "Agent: send to Gemini" })

  vim.api.nvim_create_user_command("Shell", shell_command, {
    nargs = "*",
    complete = "shellcmd",
    desc = "Run a shell command in a terminal split",
  })

  map("n", "<leader>un", toggle_numbers, { desc = "Toggle line numbers" })
  map("n", "<leader>uf", tree_toggle, { desc = "Toggle file tree" })
  map("n", "<leader>ub", toggle_transparency, { desc = "Toggle transparent background" })
  map("n", "<leader>uc", function() vim.opt.cursorline = not vim.opt.cursorline:get() end, { desc = "Toggle cursorline" })

  map("n", "<leader>-", "<cmd>split<CR>", { desc = "Split horizontal" })
  map("n", "<leader>|", "<cmd>vsplit<CR>", { desc = "Split vertical" })
  map("n", "<leader>h", function() navigate_window("h", "TmuxNavigateLeft") end, { desc = "Window left" })
  map("n", "<leader>j", function() navigate_window("j", "TmuxNavigateDown") end, { desc = "Window down" })
  map("n", "<leader>k", function() navigate_window("k", "TmuxNavigateUp") end, { desc = "Window up" })
  map("n", "<leader>l", function() navigate_window("l", "TmuxNavigateRight") end, { desc = "Window right" })
  map("n", "<leader>H", function() resize_width(-2) end, { desc = "Shrink window width" })
  map("n", "<leader>L", function() resize_width(2) end, { desc = "Grow window width" })
  map("n", "<leader>K", function() resize_height(-2) end, { desc = "Shrink window height" })
  map("n", "<leader>J", function() resize_height(2) end, { desc = "Grow window height" })
  map("n", "<leader>=", "<C-w>=", { desc = "Equalize windows" })
  map("n", "<leader>z", toggle_zoom, { desc = "Toggle window zoom" })

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
  map("n", "<leader>b?", "<cmd>BufferLinePick<CR>", { desc = "Pick buffer" })
  map("n", "<leader>bq", "<cmd>BufferLinePickClose<CR>", { desc = "Pick and close buffer" })
  map("n", "<leader>b<", "<cmd>BufferLineMovePrev<CR>", { desc = "Move buffer left" })
  map("n", "<leader>b>", "<cmd>BufferLineMoveNext<CR>", { desc = "Move buffer right" })
  map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", { desc = "Close other buffers" })
  map("n", "<leader>bl", "<cmd>BufferLineCloseLeft<CR>", { desc = "Close buffers left" })
  map("n", "<leader>br", "<cmd>BufferLineCloseRight<CR>", { desc = "Close buffers right" })
  map("n", "<leader>bP", "<cmd>BufferLineTogglePin<CR>", { desc = "Toggle pin" })
  map("n", "<leader>bd", "<cmd>BufferLineSortByDirectory<CR>", { desc = "Sort by directory" })
  map("n", "<leader>be", "<cmd>BufferLineSortByExtension<CR>", { desc = "Sort by extension" })
  map("n", "<leader>c", "<cmd>tabnew<CR>", { desc = "New tab" })
  map("n", "<leader>[", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
  map("n", "<leader>]", "<cmd>tabnext<CR>", { desc = "Next tab" })
  map("n", "<leader>x", "<cmd>tabclose<CR>", { desc = "Close tab" })
  map("n", "<leader><Tab>", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
  for index = 1, 9 do
    map("n", "<leader>" .. index, "<cmd>tabnext " .. index .. "<CR>", { desc = "Go to tab " .. index })
  end
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
