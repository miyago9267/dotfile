-- VSCode-style floating search/replace panel
local M = {}
local api = vim.api
local ns = api.nvim_create_namespace('vsearch')

local state = {
  open = false,
  win = nil,
  buf = nil,
  source_win = nil,
  source_buf = nil,
  use_regex = false,
  matches = {},
  match_idx = 0,
}

-- Find all matches in source buffer
local function find_matches(pattern)
  state.matches = {}
  if not pattern or pattern == '' then return end

  local buf = state.source_buf
  if not buf or not api.nvim_buf_is_valid(buf) then return end

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  for lnum, line in ipairs(lines) do
    local start = 1
    while start <= #line do
      local ok, s, e
      if state.use_regex then
        ok, s, e = pcall(string.find, line, pattern, start)
      else
        ok = true
        s, e = line:find(vim.pesc(pattern), start)
      end
      if not ok or not s then break end
      if e < s then break end -- avoid infinite loop on empty match
      table.insert(state.matches, { lnum = lnum - 1, col_start = s - 1, col_end = e })
      start = e + 1
    end
  end
end

-- Highlight matches in source buffer
local function update_highlights(pattern)
  local buf = state.source_buf
  if not buf or not api.nvim_buf_is_valid(buf) then return end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  find_matches(pattern)

  for i, m in ipairs(state.matches) do
    local hl = (i == state.match_idx) and 'CurSearch' or 'Search'
    api.nvim_buf_add_highlight(buf, ns, hl, m.lnum, m.col_start, m.col_end)
  end
end

-- Jump to match by index
local function jump_to_match(idx)
  if #state.matches == 0 then return end
  state.match_idx = ((idx - 1) % #state.matches) + 1
  local m = state.matches[state.match_idx]
  if state.source_win and api.nvim_win_is_valid(state.source_win) then
    api.nvim_win_set_cursor(state.source_win, { m.lnum + 1, m.col_start })
    api.nvim_win_call(state.source_win, function() vim.cmd('normal! zz') end)
  end
  -- refresh highlights to update CurSearch
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  update_highlights(lines[1] or '')
  update_status_line()
end

-- Get search and replace text from panel buffer
local function get_fields()
  if not state.buf or not api.nvim_buf_is_valid(state.buf) then return '', '' end
  local lines = api.nvim_buf_get_lines(state.buf, 0, -1, false)
  return lines[1] or '', lines[2] or ''
end

-- Update the virtual text status
local function update_status_line()
  if not state.buf or not api.nvim_buf_is_valid(state.buf) then return end
  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

  local regex_icon = state.use_regex and '[.*]' or '[Ab]'
  local count_text
  if #state.matches == 0 then
    count_text = 'No results'
  else
    count_text = string.format('%d/%d', state.match_idx, #state.matches)
  end
  local status = string.format(' %s  %s', regex_icon, count_text)

  api.nvim_buf_set_extmark(state.buf, ns, 0, 0, {
    virt_text = { { status, 'Comment' } },
    virt_text_pos = 'right_align',
  })

  -- Replace line hint
  api.nvim_buf_set_extmark(state.buf, ns, 1, 0, {
    virt_text = { { ' Enter:next  S-Enter:prev  C-r:replace  C-a:all  A-r:regex  Esc:close', 'Comment' } },
    virt_text_pos = 'right_align',
  })
end

-- Replace current match
local function replace_current()
  if #state.matches == 0 or state.match_idx == 0 then return end
  local _, replacement = get_fields()
  local m = state.matches[state.match_idx]
  local buf = state.source_buf
  if not buf or not api.nvim_buf_is_valid(buf) then return end

  local line = api.nvim_buf_get_lines(buf, m.lnum, m.lnum + 1, false)[1]
  local before = line:sub(1, m.col_start)
  local after = line:sub(m.col_end + 1)
  api.nvim_buf_set_lines(buf, m.lnum, m.lnum + 1, false, { before .. replacement .. after })

  -- Re-search and keep position
  local search = get_fields()
  update_highlights(search)
  if state.match_idx > #state.matches then state.match_idx = 1 end
  if #state.matches > 0 then jump_to_match(state.match_idx) end
end

-- Replace all matches
local function replace_all()
  if #state.matches == 0 then return end
  local search, replacement = get_fields()
  local buf = state.source_buf
  if not buf or not api.nvim_buf_is_valid(buf) then return end

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if state.use_regex then
      local ok, result = pcall(string.gsub, line, search, replacement)
      if ok then lines[i] = result end
    else
      lines[i] = line:gsub(vim.pesc(search), replacement)
    end
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  update_highlights(search)
  state.match_idx = 0
  update_status_line()
end

function M.close()
  if not state.open then return end
  state.open = false

  -- Clear highlights
  if state.source_buf and api.nvim_buf_is_valid(state.source_buf) then
    api.nvim_buf_clear_namespace(state.source_buf, ns, 0, -1)
  end

  -- Close window
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end

  -- Delete buffer
  if state.buf and api.nvim_buf_is_valid(state.buf) then
    api.nvim_buf_delete(state.buf, { force = true })
  end

  state.win = nil
  state.buf = nil
  state.matches = {}
  state.match_idx = 0

  -- Return focus to source window
  if state.source_win and api.nvim_win_is_valid(state.source_win) then
    api.nvim_set_current_win(state.source_win)
  end
end

function M.open()
  if state.open then
    -- If already open, focus the search panel
    if state.win and api.nvim_win_is_valid(state.win) then
      api.nvim_set_current_win(state.win)
      api.nvim_win_set_cursor(state.win, { 1, 0 })
      vim.cmd('startinsert!')
    end
    return
  end

  state.source_win = api.nvim_get_current_win()
  state.source_buf = api.nvim_get_current_buf()
  state.use_regex = false
  state.matches = {}
  state.match_idx = 0

  -- Create panel buffer (2 lines: search, replace)
  state.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(state.buf, 0, -1, false, { '', '' })
  vim.bo[state.buf].buftype = 'nofile'
  vim.bo[state.buf].filetype = 'vsearch'

  -- Calculate floating window position (top-right, like VSCode)
  local editor_width = api.nvim_get_option_value('columns', {})
  local win_width = math.min(60, math.floor(editor_width * 0.5))
  local win_col = editor_width - win_width - 2

  state.win = api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    row = 0,
    col = win_col,
    width = win_width,
    height = 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Search / Replace ',
    title_pos = 'center',
  })

  vim.wo[state.win].winhl = 'Normal:NormalFloat,FloatBorder:FloatBorder'
  state.open = true

  -- Live search on text change
  local augroup = api.nvim_create_augroup('vsearch', { clear = true })
  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    buffer = state.buf,
    callback = function()
      local search = get_fields()
      update_highlights(search)
      -- Auto-jump to first match when typing
      if #state.matches > 0 and state.match_idx == 0 then
        state.match_idx = 1
        jump_to_match(1)
      elseif #state.matches > 0 then
        update_highlights(search)
        update_status_line()
      else
        update_status_line()
      end
    end,
  })

  -- Close when leaving the panel
  api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    buffer = state.buf,
    callback = function()
      vim.schedule(M.close)
    end,
  })

  -- Keybindings inside the panel
  local opts = { buffer = state.buf, noremap = true, silent = true }

  -- Esc to close
  vim.keymap.set({ 'n', 'i' }, '<Esc>', M.close, opts)

  -- Enter = next match, Shift+Enter = prev match
  vim.keymap.set('i', '<CR>', function()
    jump_to_match(state.match_idx + 1)
  end, opts)
  vim.keymap.set('i', '<S-CR>', function()
    jump_to_match(state.match_idx - 1)
  end, opts)

  -- Ctrl+R = replace current
  vim.keymap.set('i', '<C-r>', replace_current, opts)

  -- Ctrl+A = replace all
  vim.keymap.set('i', '<C-a>', replace_all, opts)

  -- Alt+R = toggle regex
  vim.keymap.set('i', '<A-r>', function()
    state.use_regex = not state.use_regex
    local search = get_fields()
    update_highlights(search)
    update_status_line()
  end, opts)

  -- Tab to move between search and replace lines
  vim.keymap.set('i', '<Tab>', function()
    local cursor = api.nvim_win_get_cursor(state.win)
    local new_row = cursor[1] == 1 and 2 or 1
    api.nvim_win_set_cursor(state.win, { new_row, 999 })
  end, opts)

  -- Start in insert mode on search line
  vim.cmd('startinsert!')
  update_status_line()
end

-- Toggle: open if closed, close if open
function M.toggle()
  if state.open then
    M.close()
  else
    M.open()
  end
end

return M
