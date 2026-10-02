local layout = require("config.layout")

local M = {}

local agents = {
  claude = { command = { "claude" }, label = "Claude" },
  codex = { command = { "codex" }, label = "Codex" },
  opencode = { command = { "opencode" }, label = "OpenCode" },
  gemini = { command = { "gemini" }, label = "Gemini" },
}

local buffers = {}

local function available(agent)
  return vim.fn.executable(agent.command[1]) == 1
end

local function find_window(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
end

local function open_native(agent_name, toggle)
  local agent = agents[agent_name]
  local bufnr = buffers[agent_name]

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local win = find_window(bufnr)
    if win then
      if toggle then
        vim.api.nvim_win_close(win, true)
      else
        vim.api.nvim_set_current_win(win)
        vim.cmd("startinsert")
      end
      return
    end
  end

  local fresh = not (bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal")
  if fresh then
    bufnr = vim.api.nvim_create_buf(false, true)
    buffers[agent_name] = bufnr
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.api.nvim_buf_set_name(bufnr, "Agent://" .. agent_name)
    -- 顯示前先標記，edgy 才能認出這是 agent 並放進右側 dock
    vim.b[bufnr].miyago_agent = agent_name
    vim.bo[bufnr].filetype = "miyago_agent"
  end

  -- 單一插槽：換上新 agent 前先收掉其他 agent 的視窗（只關視窗，程序保留）
  layout.hide_agents(bufnr)
  -- 位置與寬度交給 edgy；這裡只開一個全高的右側 split
  vim.api.nvim_open_win(bufnr, true, { split = "right", win = -1 })

  if fresh then
    vim.fn.termopen(agent.command, {
      cwd = vim.fn.getcwd(),
      on_exit = function()
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.bo[bufnr].modified = false
          end
        end)
      end,
    })
  end

  vim.cmd("startinsert")
end

-- Claude 由 claudecode.nvim 開窗；Claude 沒在顯示時先收掉其他 agent，維持右側單一插槽
local function prepare_claude()
  if not layout.claude_win() then
    layout.hide_agents()
  end
end

local function toggle_claude()
  if vim.fn.exists(":ClaudeCode") == 2 then
    prepare_claude()
    vim.cmd("ClaudeCode")
  else
    vim.notify("Claude Code unavailable", vim.log.levels.WARN)
  end
end

function M.toggle(agent_name)
  local agent = agents[agent_name]
  if not agent then
    return
  end
  if not available(agent) then
    vim.notify(agent.label .. " CLI unavailable", vim.log.levels.WARN)
    return
  end
  if agent_name == "claude" then
    toggle_claude()
  else
    open_native(agent_name, true)
  end
end

local function selection()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = vim.fn.getline(start_line, end_line)
  return table.concat(lines, "\n")
end

function M.send_selection(agent_name)
  local text = selection()
  if text == "" then
    return
  end

  if agent_name == "claude" and vim.fn.exists(":ClaudeCodeSend") == 2 then
    prepare_claude()
    vim.cmd("ClaudeCodeSend")
    return
  end

  local agent = agents[agent_name]
  if not agent or not available(agent) then
    return
  end
  if agent_name == "claude" then
    toggle_claude()
    return
  end
  open_native(agent_name, false)
  local bufnr = buffers[agent_name]
  local job_id = bufnr and vim.b[bufnr].terminal_job_id
  if job_id then
    vim.fn.chansend(job_id, text .. "\n")
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Agent", function(opts)
    M.toggle(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return { "claude", "codex", "opencode", "gemini" }
    end,
    desc = "Toggle an interactive Agent panel",
  })

  vim.api.nvim_create_user_command("AgentSend", function(opts)
    M.send_selection(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return { "claude", "codex", "opencode", "gemini" }
    end,
    range = true,
    desc = "Send the selected text to an Agent",
  })
end

return M
