local M = {}

local layout = require("config.layout")

local shell_buf

-- 底部面板的 terminal：位置與高度交給 edgy；buffer 在顯示前先標記並設 filetype，edgy 才認得
-- 單一插槽：開啟前先收掉底部其他內容（只關視窗，terminal 程序保留）
local function open_terminal(cmd)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.b[buf].miyago_panel = "terminal"
  vim.bo[buf].filetype = "miyago_terminal"
  layout.hide_panels(buf)
  vim.api.nvim_open_win(buf, true, { split = "below", win = -1 })
  vim.fn.termopen(cmd or vim.o.shell)
  vim.cmd("startinsert")
  return buf
end

local function shell_alive()
  return shell_buf and vim.api.nvim_buf_is_valid(shell_buf) and vim.b[shell_buf].terminal_job_id
    and vim.fn.jobwait({ vim.b[shell_buf].terminal_job_id }, 0)[1] == -1
end

-- 顯示固定的那個 shell（沒有或已結束就開新的）；重複呼叫叫回同一個 buffer
local function show_shell()
  if shell_alive() then
    layout.hide_panels(shell_buf)
    local win = layout.buf_win(shell_buf)
    if not win then
      win = vim.api.nvim_open_win(shell_buf, true, { split = "below", win = -1 })
    else
      vim.api.nvim_set_current_win(win)
    end
    vim.cmd("startinsert")
    return
  end
  if shell_buf and vim.api.nvim_buf_is_valid(shell_buf) then
    vim.api.nvim_buf_delete(shell_buf, { force = true })
  end
  shell_buf = open_terminal()
end

local function terminal_toggle()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if layout.is_panel_win(vim.api.nvim_win_get_buf(win), win) then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  show_shell()
end

local function shell_command(opts)
  if opts.args == "" then
    show_shell()
  else
    open_terminal(opts.args)
  end
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

  -- 共用 VSCode 風格 keymap（config/vim/keymaps.vim），Vim 與 Neovim 同一份
  for _, k in ipairs(vim.g.miyago_keymaps or {}) do
    map(vim.split(k.modes, ""), k.lhs, k.rhs, { desc = k.desc, expr = k.expr == 1, remap = k.remap == 1, silent = k.loud ~= 1 })
  end

  -- VSCode Ctrl-/：切換註解（用內建 gc；多數 terminal 把 Ctrl-/ 送成 Ctrl-_）
  for _, lhs in ipairs({ "<C-/>", "<C-_>" }) do
    map("n", lhs, "gcc", { remap = true, desc = "Toggle comment" })
    map("v", lhs, "gc", { remap = true, desc = "Toggle comment" })
    map("i", lhs, "<C-o>gcc", { remap = true, desc = "Toggle comment" })
  end
  map("n", "<C-e>", tree_toggle, { desc = "Toggle file tree" })
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
  map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Terminal normal mode" })
end

return M
