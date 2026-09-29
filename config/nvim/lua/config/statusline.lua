-- 對齊 ~/.p10k.zsh 的 lean 風格：透明底、segment 之間只用空白、顏色沿用 p10k 的 xterm-256 色號
local M = {}

local c = {
  dir = "#0087af", -- 31  DIR
  anchor = "#00afff", -- 39  DIR_ANCHOR
  shortened = "#8787af", -- 103 DIR_SHORTENED
  clean = "#5fd700", -- 76  VCS_CLEAN / PROMPT_CHAR_OK
  modified = "#d7af00", -- 178 VCS_MODIFIED
  error = "#ff0000", -- 196 PROMPT_CHAR_ERROR
  status_err = "#d70000", -- 160 STATUS_ERROR
  time = "#5f8787", -- 66  TIME
  exec = "#87875f", -- 101 COMMAND_EXECUTION_TIME
  frame = "#585858", -- 240 MULTILINE prefix
}

-- p10k 的 prompt_char：insert ❯、normal ❮、visual V、replace ▶
local mode_char = {
  n = { "❮", c.clean },
  i = { "❯", c.clean },
  v = { "V", c.modified },
  V = { "V", c.modified },
  ["\22"] = { "V", c.modified },
  R = { "▶", c.error },
  c = { ":", c.anchor },
  t = { "❯", c.anchor },
}

local function current_mode()
  return mode_char[vim.fn.mode():sub(1, 1)] or { vim.fn.mode(), c.frame }
end

-- 相對 cwd 的目錄，太長時像 p10k 一樣縮短中間層
local function dir()
  if vim.bo.buftype ~= "" then
    return ""
  end
  local path = vim.fn.expand("%:~:.:h")
  if path == "." or path == "" then
    return ""
  end
  if #path > 40 then
    path = vim.fn.pathshorten(path)
  end
  return path .. "/"
end

local function transparent_theme()
  local fg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg
  local section = { fg = fg and string.format("#%06x", fg) or nil, bg = "NONE" }
  local mode = { a = section, b = section, c = section }
  return { normal = mode, insert = mode, visual = mode, replace = mode, command = mode, inactive = mode }
end

local function config()
  return {
    options = {
      theme = transparent_theme(),
      globalstatus = true,
      component_separators = "",
      section_separators = "",
      disabled_filetypes = { statusline = {} },
    },
    sections = {
      lualine_a = {
        { function() return "\u{f179}" end, padding = { left = 1, right = 0 } },
        {
          function() return current_mode()[1] end,
          color = function() return { fg = current_mode()[2], gui = "bold" } end,
        },
      },
      lualine_b = {
        { dir, color = { fg = c.dir }, padding = { left = 1, right = 0 } },
        { "filename", path = 0, color = { fg = c.anchor, gui = "bold" }, padding = { left = 0, right = 1 },
          symbols = { modified = "●", readonly = "\u{f023}", unnamed = "[No Name]", newfile = "[New]" } },
      },
      lualine_c = {
        { "branch", icon = "\u{e0a0}", color = { fg = c.clean } },
        {
          "diff",
          symbols = { added = "+", modified = "!", removed = "-" },
          diff_color = {
            added = { fg = c.clean },
            modified = { fg = c.modified },
            removed = { fg = c.status_err },
          },
          padding = { left = 0, right = 1 },
        },
      },
      lualine_x = {
        { "diagnostics", symbols = { error = "\u{f057} ", warn = "\u{f071} ", info = "\u{f05a} ", hint = "\u{f0335} " } },
        { "filetype", colored = false, color = { fg = c.exec } },
      },
      lualine_y = {
        { "progress", color = { fg = c.time } },
      },
      lualine_z = {
        { "location", color = { fg = c.time } },
      },
    },
  }
end

function M.setup()
  require("lualine").setup(config())

  -- colorscheme 切換（例如透明背景 toggle）後重建透明 theme
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("miyago_statusline", { clear = true }),
    callback = function()
      require("lualine").setup(config())
    end,
  })
end

return M
