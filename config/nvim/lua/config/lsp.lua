local M = {}

local servers = {
  lua_ls = { "lua-language-server" },
  clangd = { "clangd" },
  gopls = { "gopls" },
  rust_analyzer = { "rust-analyzer" },
  basedpyright = { "basedpyright-langserver", "--stdio" },
  ts_ls = { "typescript-language-server", "--stdio" },
  vue_ls = { "vue-language-server", "--stdio" },
  html = { "vscode-html-language-server", "--stdio" },
  cssls = { "vscode-css-language-server", "--stdio" },
  yamlls = { "yaml-language-server", "--stdio" },
  jsonls = { "vscode-json-language-server", "--stdio" },
  taplo = { "taplo", "lsp", "stdio" },
  lemminx = { "lemminx" },
  marksman = { "marksman", "server" },
  bashls = { "bash-language-server", "start" },
  terraformls = { "terraform-ls", "serve" },
  dockerls = { "docker-langserver", "--stdio" },
}

local function executable(cmd)
  return vim.fn.executable(cmd) == 1
end

-- 全域 npm 套件目錄（從執行檔的 symlink 反推，例如 /opt/homebrew/lib/node_modules）
local function global_node_modules(cmd)
  local real = vim.fn.resolve(vim.fn.exepath(cmd))
  return real:match("^(.*/node_modules)/")
end

-- 個別 server 的額外設定：專案沒有自己的 typescript 時退回全域那份；
-- Vue 3 的 vue_ls 需要 ts_ls 掛上 @vue/typescript-plugin 才有 .vue 裡的型別檢查
local function extra_config(name)
  if name ~= "ts_ls" then
    return {}
  end
  local config = { init_options = { hostInfo = "neovim" } }
  local ts_root = global_node_modules("typescript-language-server")
  if ts_root then
    config.init_options.tsserver = { fallbackPath = ts_root .. "/typescript/lib" }
  end
  local vue_root = global_node_modules("vue-language-server")
  if vue_root then
    config.init_options.plugins = {
      { name = "@vue/typescript-plugin", location = vue_root .. "/@vue/language-server", languages = { "vue" } },
    }
    config.filetypes = {
      "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx", "vue",
    }
  end
  return config
end

local function on_attach(client, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  map("n", "gd", vim.lsp.buf.definition, "LSP: definition")
  map("n", "gD", vim.lsp.buf.declaration, "LSP: declaration")
  map("n", "gr", vim.lsp.buf.references, "LSP: references")
  map("n", "K", vim.lsp.buf.hover, "LSP: hover")
  map("n", "<F2>", vim.lsp.buf.rename, "LSP: rename")
  map({ "n", "v" }, "<leader>.", vim.lsp.buf.code_action, "LSP: code action")
  map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
  map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")

  -- VSCode 的同名反白：游標停住時標出同一個 symbol 的其他位置
  if client:supports_method("textDocument/documentHighlight") then
    local group = vim.api.nvim_create_augroup("miyago_lsp_highlight_" .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = group, buffer = bufnr, callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
      group = group, buffer = bufnr, callback = vim.lsp.buf.clear_references,
    })
  end

  if client:supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    map("n", "<leader>uh", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
    end, "Toggle inlay hints")
  end
end

-- VSCode 風格：行尾顯示訊息、波浪底線、嚴重度排序
local function setup_diagnostics()
  local S = vim.diagnostic.severity
  vim.diagnostic.config({
    severity_sort = true,
    update_in_insert = false,
    underline = true,
    virtual_text = { spacing = 2, prefix = "●", source = "if_many" },
    float = { border = "rounded", source = true },
    signs = {
      text = { [S.ERROR] = "\u{f057} ", [S.WARN] = "\u{f071} ", [S.INFO] = "\u{f05a} ", [S.HINT] = "\u{f0335} " },
    },
  })
end

function M.setup()
  setup_diagnostics()

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  for name, cmd in pairs(servers) do
    if executable(cmd[1]) then
      vim.lsp.config(name, vim.tbl_deep_extend("force", {
        cmd = cmd,
        on_attach = on_attach,
        capabilities = capabilities,
      }, extra_config(name)))
      vim.lsp.enable(name)
    end
  end
end

return M
