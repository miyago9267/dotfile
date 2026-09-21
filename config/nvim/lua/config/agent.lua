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

local function panel_width()
  return math.max(32, math.floor(vim.o.columns * 0.30))
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

  vim.cmd("botright vsplit")
  vim.cmd("vertical resize " .. panel_width())

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
    vim.api.nvim_win_set_buf(0, bufnr)
  else
    bufnr = vim.api.nvim_create_buf(false, true)
    buffers[agent_name] = bufnr
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.api.nvim_buf_set_name(bufnr, "Agent://" .. agent_name)
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

local function toggle_claude()
  if vim.fn.exists(":ClaudeCode") == 2 then
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
