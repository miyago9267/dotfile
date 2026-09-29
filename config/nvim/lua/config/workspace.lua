-- Multi-root workspace（spec: docs/specs/nvim-workspace/SPEC.md）
-- hub 是一個只放 symlink 的目錄，給 cwd、nvim-tree 與搜尋用；對外的路徑（buffer、複製、agent）一律是真實路徑
local M = {}

M.state = nil -- { name, file, hub, prev_cwd, roots = { { name, path, link } } }
M.state_root = vim.fn.stdpath("state")
M.data_root = vim.fn.stdpath("data")
M.warn = function(msg) vim.notify(msg, vim.log.levels.WARN) end

local uv = vim.uv

local function store_dir()
  return M.data_root .. "/workspaces"
end

local function realpath(path)
  return uv.fs_realpath(path)
end

local function is_under(path, root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

-- VSCode 會寫整行註解和尾逗號（JSONC）；只處理這兩種
local function read_json(file)
  local lines = {}
  for _, line in ipairs(vim.fn.readfile(file)) do
    if not line:match("^%s*//") then
      table.insert(lines, line)
    end
  end
  local text = table.concat(lines, "\n"):gsub(",(%s*[%]}])", "%1")
  local ok, data = pcall(vim.json.decode, text)
  if not ok or type(data) ~= "table" then
    error("invalid workspace file: " .. file)
  end
  return data
end

local function write_json(file, data)
  local keys = vim.tbl_keys(data)
  table.sort(keys, function(a, b)
    if a == "folders" or b == "folders" then
      return a == "folders"
    end
    return a < b
  end)
  local out = { "{" }
  for i, key in ipairs(keys) do
    local comma = i < #keys and "," or ""
    if key == "folders" then
      table.insert(out, '  "folders": [')
      for j, folder in ipairs(data.folders) do
        table.insert(out, "    " .. vim.json.encode(folder) .. (j < #data.folders and "," or ""))
      end
      table.insert(out, "  ]" .. comma)
    else
      table.insert(out, "  " .. vim.json.encode(key) .. ": " .. vim.json.encode(data[key]) .. comma)
    end
  end
  table.insert(out, "}")
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  vim.fn.writefile(out, file)
end

local function resolve_folder_path(path, base)
  path = vim.fn.expand(path)
  if path:sub(1, 1) ~= "/" then
    path = base .. "/" .. path
  end
  path = vim.fs.normalize(path)
  return realpath(path) or path
end

--- 解析 .code-workspace，回傳 { { name, path } }；不存在的路徑也保留，由 build_hub 決定跳過
function M.parse(file)
  local data = read_json(file)
  local base = vim.fn.fnamemodify(file, ":p:h")
  local folders = {}
  for _, folder in ipairs(data.folders or {}) do
    if type(folder.path) == "string" then
      local path = resolve_folder_path(folder.path, base)
      table.insert(folders, { name = folder.name or vim.fs.basename(path), path = path })
    end
  end
  return folders
end

--- 重建 hub：只移除 hub 內的 symlink，再依 folders 建立；回傳實際建立的 roots
function M.build_hub(hub, folders)
  vim.fn.mkdir(hub, "p")
  for name, kind in vim.fs.dir(hub) do
    if kind == "link" then
      uv.fs_unlink(hub .. "/" .. name)
    end
  end

  local roots, used = {}, {}
  for _, folder in ipairs(folders) do
    local stat = uv.fs_stat(folder.path)
    if not stat or stat.type ~= "directory" then
      M.warn("workspace: skip missing folder " .. folder.path)
    else
      local name, n = folder.name, 1
      while used[name] do
        n = n + 1
        name = folder.name .. "-" .. n
      end
      used[name] = true
      local link = hub .. "/" .. name
      if uv.fs_lstat(link) then
        M.warn("workspace: " .. link .. " exists and is not a symlink, skipped")
      else
        uv.fs_symlink(folder.path, link)
        table.insert(roots, { name = name, path = folder.path, link = link })
      end
    end
  end
  return roots
end

local function workspace_name(file)
  return (vim.fs.basename(file):gsub("%.code%-workspace$", ""))
end

local function refresh_tree()
  local ok, api = pcall(require, "nvim-tree.api")
  if ok then
    pcall(api.tree.change_root, M.state and M.state.hub or vim.fn.getcwd())
    pcall(api.tree.reload)
  end
end

local function rebuild()
  M.state.roots = M.build_hub(M.state.hub, M.parse(M.state.file))
  refresh_tree()
end

--- 開啟 workspace：file 可以是路徑或 store 裡的名稱
function M.open(file)
  if not file:find("/") and not file:find("%.code%-workspace$") then
    file = store_dir() .. "/" .. file .. ".code-workspace"
  end
  file = vim.fn.fnamemodify(vim.fn.expand(file), ":p")
  if vim.fn.filereadable(file) == 0 then
    M.warn("workspace: file not found " .. file)
    return
  end

  local prev_cwd = M.state and M.state.prev_cwd or vim.fn.getcwd()
  local name = workspace_name(file)
  local hub = M.state_root .. "/workspace-hub/" .. name
  M.state = { name = name, file = file, hub = hub, prev_cwd = prev_cwd, roots = {} }
  M.state.roots = M.build_hub(hub, M.parse(file))
  M.state.hub = realpath(hub) or hub
  vim.cmd.cd(vim.fn.fnameescape(M.state.hub))
  refresh_tree()
end

function M.close()
  if not M.state then
    return
  end
  local prev = M.state.prev_cwd
  M.state = nil
  vim.cmd.cd(vim.fn.fnameescape(prev))
  refresh_tree()
end

local function edit_folders(fn)
  if not M.state then
    M.warn("workspace: no workspace open")
    return
  end
  local data = read_json(M.state.file)
  data.folders = data.folders or {}
  fn(data.folders)
  write_json(M.state.file, data)
  rebuild()
end

local function default_folder()
  local buf = vim.api.nvim_buf_get_name(0)
  local root = buf ~= "" and vim.fs.root(buf, ".git")
  return root or vim.fn.getcwd()
end

function M.add(dir)
  dir = realpath(vim.fn.expand(dir or default_folder()))
  if not dir then
    M.warn("workspace: folder not found")
    return
  end
  edit_folders(function(folders)
    table.insert(folders, { path = dir })
  end)
end

function M.remove(name)
  local target
  for _, root in ipairs(M.state and M.state.roots or {}) do
    if root.name == name then
      target = root.path
    end
  end
  if not target then
    M.warn("workspace: no folder named " .. tostring(name))
    return
  end
  local base = vim.fn.fnamemodify(M.state.file, ":h")
  edit_folders(function(folders)
    for i = #folders, 1, -1 do
      if resolve_folder_path(folders[i].path, base) == target then
        table.remove(folders, i)
      end
    end
  end)
end

function M.create(name, dir)
  local file = store_dir() .. "/" .. name .. ".code-workspace"
  if vim.fn.filereadable(file) == 1 then
    M.warn("workspace: " .. name .. " already exists")
    return
  end
  local path = realpath(vim.fn.expand(dir or default_folder()))
  write_json(file, { folders = { { path = path } } })
  M.open(file)
end

--- 真實路徑 -> hub 路徑；不在 workspace 內回傳 nil
function M.to_hub(path)
  if not M.state then
    return nil
  end
  path = realpath(path) or path
  for _, root in ipairs(M.state.roots) do
    if is_under(path, root.path) then
      return root.link .. path:sub(#root.path + 1)
    end
  end
end

local function source_path(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  if vim.bo[buf].filetype == "NvimTree" then
    local ok, api = pcall(require, "nvim-tree.api")
    local node = ok and api.tree.get_node_under_cursor()
    return node and node.absolute_path
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and name or nil
end

--- kind = "absolute"（真實路徑）或 "relative"（相對 cwd；workspace 中為 <folder>/<relpath>）
function M.path_for(buf, kind)
  local path = source_path(buf)
  if not path then
    return nil
  end
  local real = realpath(path) or path
  if kind == "absolute" then
    return real
  end
  local hub_path = M.to_hub(real)
  if hub_path then
    return hub_path:sub(#M.state.hub + 2)
  end
  local cwd = realpath(vim.fn.getcwd()) or vim.fn.getcwd()
  if is_under(real, cwd) and real ~= cwd then
    return real:sub(#cwd + 2)
  end
  return real
end

local function copy(kind, opts)
  local path = M.path_for(0, kind)
  if not path then
    M.warn("CopyPath: no file")
    return
  end
  if opts.range > 0 and vim.bo.filetype ~= "NvimTree" then
    path = path .. ":" .. (opts.line1 == opts.line2 and opts.line1 or (opts.line1 .. "-" .. opts.line2))
  end
  vim.fn.setreg('"', path)
  pcall(vim.fn.setreg, "+", path)
  vim.notify("Copied: " .. path)
end

--- 給 fzf-lua 的額外 opts；沒開 workspace 時回傳 {}，行為不變
function M.search_opts(kind)
  if not M.state then
    return {}
  end
  local ok, defaults = pcall(require, "fzf-lua.defaults")
  local d = ok and defaults.defaults or {}
  if kind == "files" then
    local fd = d.files and d.files.fd_opts or "--color=never --type f --hidden --exclude .git"
    return { cwd = M.state.hub, fd_opts = fd .. " --follow" }
  end
  local rg = d.grep and d.grep.rg_opts or "--column --line-number --no-heading --color=always --smart-case"
  return { cwd = M.state.hub, rg_opts = "--follow " .. rg }
end

function M.fzf(method)
  local kind = method:find("grep") and "grep" or "files"
  require("fzf-lua")[method](M.search_opts(kind))
end

--- nvim-tree update_focused_file.exclude：workspace 中接手 BufEnter，避免 root 跳到真實 repo
function M.tree_exclude(event)
  if not M.state then
    return false
  end
  local name = vim.api.nvim_buf_get_name(event.buf)
  local hub_path = name ~= "" and M.to_hub(name)
  if hub_path then
    vim.schedule(function()
      local ok, api = pcall(require, "nvim-tree.api")
      if ok then
        pcall(api.tree.find_file, { buf = hub_path })
      end
    end)
  end
  return true
end

--- nvim-tree on_attach：gy / Y 改用同一套路徑邏輯
function M.tree_on_attach(bufnr)
  local api = require("nvim-tree.api")
  api.config.mappings.default_on_attach(bufnr)
  local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }
  vim.keymap.set("n", "gy", "<cmd>CopyPath<CR>", vim.tbl_extend("force", opts, { desc = "Copy Absolute Path" }))
  vim.keymap.set("n", "Y", "<cmd>CopyRelativePath<CR>", vim.tbl_extend("force", opts, { desc = "Copy Relative Path" }))
end

local function pick(items, prompt, cb)
  if #items == 0 then
    M.warn("workspace: nothing to pick")
    return
  end
  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(items, {
      prompt = prompt .. "> ",
      actions = { default = function(sel) if sel[1] then cb(sel[1]) end end },
    })
  else
    vim.ui.select(items, { prompt = prompt }, function(item) if item then cb(item) end end)
  end
end

local function stored_names()
  local names = {}
  for name in vim.fs.dir(store_dir()) do
    if name:match("%.code%-workspace$") then
      table.insert(names, workspace_name(name))
    end
  end
  table.sort(names)
  return names
end

local subcommands = {
  open = function(arg)
    if arg then
      M.open(arg)
    else
      pick(stored_names(), "Workspace", M.open)
    end
  end,
  close = function() M.close() end,
  new = function(arg)
    if not arg then
      M.warn("usage: :Workspace new <name>")
      return
    end
    M.create(arg)
  end,
  add = function(arg) M.add(arg) end,
  remove = function(arg)
    if arg then
      M.remove(arg)
    else
      pick(vim.tbl_map(function(r) return r.name end, M.state and M.state.roots or {}), "Remove folder", M.remove)
    end
  end,
  list = function()
    if not M.state then
      print("no workspace open")
      return
    end
    local lines = { M.state.name .. " (" .. M.state.file .. ")" }
    for _, root in ipairs(M.state.roots) do
      table.insert(lines, "  " .. root.name .. " -> " .. root.path)
    end
    print(table.concat(lines, "\n"))
  end,
}

function M.setup()
  vim.api.nvim_create_user_command("Workspace", function(opts)
    local sub, arg = opts.fargs[1] or "open", opts.fargs[2]
    local fn = subcommands[sub]
    if not fn then
      M.warn("workspace: unknown subcommand " .. sub)
      return
    end
    local ok, err = pcall(fn, arg)
    if not ok then
      M.warn(tostring(err))
    end
  end, {
    nargs = "*",
    complete = function(lead, line)
      local args = vim.split(line, "%s+")
      if #args <= 2 then
        return vim.tbl_filter(function(s) return s:find(lead, 1, true) == 1 end, vim.tbl_keys(subcommands))
      end
      if args[2] == "open" then
        return stored_names()
      elseif args[2] == "remove" then
        return vim.tbl_map(function(r) return r.name end, M.state and M.state.roots or {})
      elseif args[2] == "add" then
        return vim.fn.getcompletion(lead, "dir")
      end
      return {}
    end,
    desc = "Multi-root workspace",
  })

  vim.api.nvim_create_user_command("CopyPath", function(opts) copy("absolute", opts) end,
    { range = true, desc = "Copy absolute path (with :line range)" })
  vim.api.nvim_create_user_command("CopyRelativePath", function(opts) copy("relative", opts) end,
    { range = true, desc = "Copy relative path (with :line range)" })

  -- 右鍵選單（VSCode 的 Copy Path / Copy Relative Path）
  vim.cmd([[
    nnoremenu PopUp.Copy\ Path <Cmd>CopyPath<CR>
    nnoremenu PopUp.Copy\ Relative\ Path <Cmd>CopyRelativePath<CR>
    vnoremenu PopUp.Copy\ Path :CopyPath<CR>
    vnoremenu PopUp.Copy\ Relative\ Path :CopyRelativePath<CR>
  ]])

  -- nvim foo.code-workspace：直接進 workspace，而不是打開 JSON
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("miyago_workspace", { clear = true }),
    nested = true,
    callback = function()
      local arg = vim.fn.argc() == 1 and vim.fn.argv(0) or nil
      if arg and arg:match("%.code%-workspace$") then
        local buf = vim.api.nvim_get_current_buf()
        M.open(arg)
        vim.cmd.enew()
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        local ok, api = pcall(require, "nvim-tree.api")
        if ok then
          pcall(api.tree.open)
        end
      end
    end,
  })
end

return M
