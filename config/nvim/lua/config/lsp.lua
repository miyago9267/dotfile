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

local function on_attach(_, bufnr)
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
  end

  map("n", "gd", vim.lsp.buf.definition, "LSP: definition")
  map("n", "gD", vim.lsp.buf.declaration, "LSP: declaration")
  map("n", "gr", vim.lsp.buf.references, "LSP: references")
  map("n", "K", vim.lsp.buf.hover, "LSP: hover")
  map("n", "<F2>", vim.lsp.buf.rename, "LSP: rename")
  map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
  map("n", "<leader>cf", function()
    vim.lsp.buf.format({ async = true })
  end, "LSP: format")
end

function M.setup()
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
