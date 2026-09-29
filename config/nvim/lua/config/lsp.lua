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

local function on_attach(client, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  map("n", "gd", vim.lsp.buf.definition, "LSP: definition")
  map("n", "gD", vim.lsp.buf.declaration, "LSP: declaration")
  map("n", "gr", vim.lsp.buf.references, "LSP: references")
  map("n", "K", vim.lsp.buf.hover, "LSP: hover")
  map("n", "<F2>", vim.lsp.buf.rename, "LSP: rename")
  map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
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
      vim.lsp.config(name, {
        cmd = cmd,
        on_attach = on_attach,
        capabilities = capabilities,
      })
      vim.lsp.enable(name)
    end
  end
end

return M
