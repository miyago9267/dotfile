-- 固定區塊版面：判斷視窗屬於哪個 dock，並提供「單一插槽」的關窗邏輯
-- 位置與尺寸由 edgy.nvim 負責（見 plugins.lua）；這裡只決定哪些視窗算 agent／底部面板
local M = {}

local function is_float(win)
  return vim.api.nvim_win_get_config(win).relative ~= ""
end

-- claudecode.nvim 走 snacks terminal；Leaf 預覽也是 snacks_terminal，但它是浮窗，所以必須排除浮窗
function M.is_claude_win(buf, win)
  if vim.bo[buf].filetype ~= "snacks_terminal" or is_float(win) then
    return false
  end
  local info = vim.b[buf].snacks_terminal
  local cmd = info and info.cmd
  if type(cmd) == "table" then
    cmd = table.concat(cmd, " ")
  end
  return type(cmd) == "string" and cmd:find("claude", 1, true) ~= nil
end

-- agent.lua 開的 Codex／OpenCode／Gemini，buffer 在顯示前就標好 miyago_agent
function M.is_agent_win(buf, win)
  return vim.b[buf].miyago_agent ~= nil and not is_float(win)
end

-- Space tt／Ctrl-,／:Shell 的 terminal，buffer 標記 miyago_panel = "terminal"
function M.is_panel_win(buf, win)
  return vim.b[buf].miyago_panel == "terminal" and not is_float(win)
end

function M.is_trouble_win(buf, win)
  return vim.bo[buf].filetype == "trouble" and not is_float(win)
end

local function is_agent(win)
  local buf = vim.api.nvim_win_get_buf(win)
  return M.is_claude_win(buf, win) or M.is_agent_win(buf, win)
end

local function is_panel(win)
  local buf = vim.api.nvim_win_get_buf(win)
  return M.is_panel_win(buf, win) or M.is_trouble_win(buf, win)
end

local function edgy_loaded()
  return package.loaded["edgy.editor"] ~= nil and package.loaded["edgy.config"] ~= nil
end

-- 目前分頁的視窗分類：dock（edgy 管理）、editor（其餘非浮動）
local function editor_wins()
  if not edgy_loaded() then
    return {}
  end
  local wins = require("edgy.editor").list_wins()
  return wins.main, not vim.tbl_isempty(wins.edgy)
end

local ensuring = false

-- 沒有任何編輯視窗、卻有 dock 時，先補一個空的編輯視窗；否則 dock 全是固定尺寸，剩下的空間會被 cmdheight 吃掉
-- 開 dock 內容前呼叫（hide_agents／hide_panels／trouble），dock 才會從這個編輯視窗旁邊長出來
-- opts.keep_focus：補完後把焦點還給原本的視窗（啟動時用）
function M.ensure_main(opts)
  if ensuring or vim.fn.getcmdwintype() ~= "" then
    return
  end
  local main, has_dock = editor_wins()
  if not has_dock or not vim.tbl_isempty(main) then
    return
  end
  ensuring = true
  local prev = vim.api.nvim_get_current_win()
  local ok, err = pcall(vim.cmd, "botright new")
  ensuring = false
  if not ok then
    error(err)
  end
  if opts and opts.keep_focus and vim.api.nvim_win_is_valid(prev) then
    vim.api.nvim_set_current_win(prev)
  end
end

-- 只關視窗、不刪 buffer，所以 terminal 程序保留，之後可以再叫回來
local function hide(match, keep_buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and match(win) and vim.api.nvim_win_get_buf(win) ~= keep_buf then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

-- 開新 agent 前呼叫：關掉右側 dock 裡其他 agent 的視窗
function M.hide_agents(keep_buf)
  M.ensure_main()
  hide(is_agent, keep_buf)
end

-- 開 terminal 或 Trouble 前呼叫：關掉底部面板裡其他內容的視窗
function M.hide_panels(keep_buf)
  M.ensure_main()
  hide(is_panel, keep_buf)
end

-- 開 Trouble：它是非同步開窗，沒有結果時甚至不開窗。所以等 trouble buffer 真的出現後，
-- 才收掉底部原本的其他內容（terminal 或另一個 Trouble 模式）；沒有開窗（沒結果、toggle 關閉）就不動其他內容
function M.trouble(args)
  M.ensure_main()
  local id = vim.api.nvim_create_autocmd("FileType", {
    pattern = "trouble",
    once = true,
    callback = function(event)
      vim.schedule(function()
        hide(is_panel, event.buf)
      end)
    end,
  })
  vim.defer_fn(function()
    pcall(vim.api.nvim_del_autocmd, id)
  end, 1000)
  vim.cmd("Trouble " .. args)
end

function M.claude_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if M.is_claude_win(vim.api.nvim_win_get_buf(win), win) then
      return win
    end
  end
end

-- 該 buffer 是否有任何非浮動視窗顯示
function M.buf_win(buf)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf and not is_float(win) then
      return win
    end
  end
end

-- 取代 edgy 預設的 check_main：只剩 dock 時留一個「空的」編輯視窗，dock 才不會佔滿畫面
-- （edgy 預設會把最近的檔案 buffer 再開出來，會讓 :q 永遠關不掉）
function M.ensure_editor(event)
  local closing = tonumber(event and event.match)
  local main, has_dock = editor_wins()
  -- WinClosed 觸發時被關的視窗還在清單裡；先把空視窗開好再讓它關掉，nvim 才不會因為 dock 都是固定高度而把 cmdheight 撐大
  if has_dock and closing and main[closing] and vim.tbl_count(main) == 1 then
    vim.cmd("botright new")
  end
end

-- 在空的、沒名字的編輯視窗 :q 且沒有其他編輯視窗時，整個離開（交給 :qa，未存檔 buffer 照 confirm 詢問）
local function quit_when_empty_editor()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local main, has_dock = editor_wins()
  if not has_dock or is_float(win) or main[win] == nil or vim.tbl_count(main) > 1 then
    return
  end
  local empty = vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) == ""
    and not vim.bo[buf].modified and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
  if empty then
    vim.schedule(function()
      vim.cmd("qa")
    end)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("QuitPre", {
    group = vim.api.nvim_create_augroup("miyago_layout", { clear = true }),
    callback = quit_when_empty_editor,
  })
end

return M
