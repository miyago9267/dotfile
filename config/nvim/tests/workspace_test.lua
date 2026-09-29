-- 執行：nvim --headless -u NONE -l config/nvim/tests/workspace_test.lua
-- 純 assert；fixture 放在 temp 目錄，hub 用 XDG_STATE_HOME 導到 temp，不碰真實環境
local config_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config_dir)

local tmp = vim.uv.fs_realpath((vim.fn.tempname():gsub("[^/]+$", ""))) .. "/ws-test-" .. vim.uv.getpid()
vim.fn.mkdir(tmp, "p")
local ws = require("config.workspace")
ws.state_root = tmp .. "/state"
ws.data_root = tmp .. "/data"
ws.setup()

local failures, passed = {}, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    table.insert(failures, name .. ": " .. tostring(err))
  end
end
local function eq(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error((msg or "") .. " expected " .. vim.inspect(expected) .. " got " .. vim.inspect(actual), 2)
  end
end
local function write(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(vim.split(content, "\n"), path)
end

-- fixture：兩個 repo、一個同名 repo、一個不存在的路徑
write(tmp .. "/code/api/src/x.ts", "line1\nline2\nline3")
write(tmp .. "/code/web/index.html", "<p>hi</p>")
write(tmp .. "/other/api/readme.md", "dup")
local ws_file = tmp .. "/proj/demo.code-workspace"
write(ws_file, [[
{
  // 整行註解
  "folders": [
    { "path": "../code/api" },
    { "path": "]] .. tmp .. [[/code/web", "name": "frontend" },
    { "path": "../other/api" },
    { "path": "../missing" },
  ],
  "settings": { "editor.tabSize": 2 },
}]])

local warnings = {}
ws.warn = function(msg) table.insert(warnings, msg) end

test("T1 parse relative/absolute/comments/trailing commas", function()
  local folders = ws.parse(ws_file)
  eq(#folders, 4)
  eq(folders[1].path, tmp .. "/code/api")
  eq(folders[2].path, tmp .. "/code/web")
  eq(folders[2].name, "frontend")
  eq(folders[3].name, "api")
end)

test("T1 parse ~ expansion", function()
  local f = tmp .. "/tilde.code-workspace"
  write(f, '{"folders":[{"path":"~/x"}]}')
  eq(ws.parse(f)[1].path, vim.fn.expand("~") .. "/x")
end)

test("T2 open builds hub symlinks and sets cwd", function()
  ws.open(ws_file)
  local hub = ws.state.hub
  eq(vim.fn.getcwd(), hub)
  eq(vim.uv.fs_readlink(hub .. "/api"), tmp .. "/code/api")
  eq(vim.uv.fs_readlink(hub .. "/frontend"), tmp .. "/code/web")
end)

test("T3 duplicate names get suffix", function()
  eq(vim.uv.fs_readlink(ws.state.hub .. "/api-2"), tmp .. "/other/api")
end)

test("T4 missing folder skipped with warning", function()
  eq(vim.uv.fs_lstat(ws.state.hub .. "/missing"), nil)
  assert(#warnings >= 1 and warnings[1]:find("missing"), "no warning for missing folder")
end)

test("T5 rebuild only removes symlinks inside hub", function()
  local hub = ws.state.hub
  ws.build_hub(hub, { { name = "frontend", path = tmp .. "/code/web" } })
  eq(vim.uv.fs_lstat(hub .. "/api"), nil)
  eq(vim.fn.filereadable(tmp .. "/code/api/src/x.ts"), 1, "target content deleted")
  ws.open(ws_file)
end)

test("T6 buffer name is real path and maps to hub", function()
  vim.cmd("edit api/src/x.ts")
  local real = vim.api.nvim_buf_get_name(0)
  eq(real, tmp .. "/code/api/src/x.ts")
  eq(ws.to_hub(real), ws.state.hub .. "/api/src/x.ts")
  eq(ws.to_hub(tmp .. "/elsewhere.txt"), nil)
end)

test("T7 copy absolute/relative with ranges", function()
  eq(ws.path_for(0, "absolute"), tmp .. "/code/api/src/x.ts")
  eq(ws.path_for(0, "relative"), "api/src/x.ts")
  vim.cmd("CopyPath")
  eq(vim.fn.getreg("+") ~= "" and vim.fn.getreg("+") or vim.fn.getreg('"'), tmp .. "/code/api/src/x.ts")
  vim.cmd("2CopyRelativePath")
  eq(vim.fn.getreg('"'), "api/src/x.ts:2")
  vim.cmd("1,3CopyRelativePath")
  eq(vim.fn.getreg('"'), "api/src/x.ts:1-3")
  vim.cmd("2,3CopyPath")
  eq(vim.fn.getreg('"'), tmp .. "/code/api/src/x.ts:2-3")
end)

test("T8 search opts follow symlinks in workspace", function()
  local files = ws.search_opts("files")
  assert(files.fd_opts:find("--follow"), "fd_opts missing --follow")
  eq(files.cwd, ws.state.hub)
  local grep = ws.search_opts("grep")
  assert(grep.rg_opts:find("--follow"), "rg_opts missing --follow")
end)

test("T12 agent cwd is hub", function()
  eq(vim.fn.getcwd(), ws.state.hub)
  eq(vim.fn.filereadable(ws.path_for(0, "relative")), 1, "relative path unreadable from hub")
end)

test("T10 close restores cwd and default behavior", function()
  local hub = ws.state.hub
  ws.close()
  eq(ws.state, nil)
  assert(vim.fn.getcwd() ~= hub, "cwd still hub")
  eq(ws.search_opts("files"), {})
  eq(ws.tree_exclude({ buf = 0 }), false)
end)

test("R6 add/remove update the workspace file", function()
  local f = ws.data_root .. "/workspaces/demo2.code-workspace"
  ws.create("demo2", tmp .. "/code/api")
  eq(vim.fn.getcwd(), ws.state.hub)
  ws.add(tmp .. "/code/web")
  eq(#ws.parse(f), 2)
  eq(vim.uv.fs_readlink(ws.state.hub .. "/web"), tmp .. "/code/web")
  ws.remove("web")
  eq(#ws.parse(f), 1)
  eq(vim.uv.fs_lstat(ws.state.hub .. "/web"), nil)
  ws.close()
end)

test("R6 save keeps unknown fields", function()
  ws.open(ws_file)
  ws.add(tmp .. "/other")
  local decoded = vim.json.decode(table.concat(vim.fn.readfile(ws_file), "\n"))
  eq(decoded.settings["editor.tabSize"], 2)
  ws.close()
end)

vim.fn.delete(tmp, "rf")
if #failures > 0 then
  io.stderr:write(("FAIL %d, pass %d\n  %s\n"):format(#failures, passed, table.concat(failures, "\n  ")))
  vim.cmd("cquit 1")
end
io.stderr:write(("PASS %d\n"):format(passed))
vim.cmd("qall!")
