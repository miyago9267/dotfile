-- Compatibility layer for Neovim < 0.11
local M = {}

-- 檢測 Neovim 版本
local function get_nvim_version()
    local version = vim.version()
    return version.major * 100 + version.minor
end

M.nvim_version = get_nvim_version()
M.is_nvim_011_or_later = M.nvim_version >= 11

-- LSP 設定相容層
M.setup_lsp = function()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    
    if M.is_nvim_011_or_later then
        -- Neovim 0.11+ 使用新 API
        vim.lsp.config('*', {
            capabilities = capabilities,
        })
        vim.lsp.enable({ 'lua_ls', 'ts_ls', 'pyright', 'gopls' })
    else
        -- Neovim 0.10- 使用舊 API
        local lspconfig = require('lspconfig')
        local servers = { 'lua_ls', 'ts_ls', 'pyright', 'gopls' }
        for _, lsp in ipairs(servers) do
            lspconfig[lsp].setup({
                capabilities = capabilities,
            })
        end
    end
end

return M
