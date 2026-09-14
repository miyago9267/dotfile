local M = {}

function M.setup_cmp()
  local cmp = require("cmp")

  local function tab(fallback)
    local ok, suggestion = pcall(require, "copilot.suggestion")
    if ok and suggestion.is_visible() then
      suggestion.accept()
    elseif cmp.visible() then
      cmp.select_next_item()
    else
      fallback()
    end
  end

  local function shift_tab(fallback)
    if cmp.visible() then
      cmp.select_prev_item()
    else
      fallback()
    end
  end

  local function select_next(fallback)
    if cmp.visible() then
      cmp.select_next_item()
    else
      fallback()
    end
  end

  local function select_prev(fallback)
    if cmp.visible() then
      cmp.select_prev_item()
    else
      fallback()
    end
  end

  local function feed_key(key, mode)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), mode, false)
  end

  cmp.setup({
    completion = { autocomplete = { cmp.TriggerEvent.TextChanged } },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<C-n>"] = cmp.mapping.select_next_item(),
      ["<C-p>"] = cmp.mapping.select_prev_item(),
      ["<CR>"] = cmp.mapping.confirm({ select = false }),
      ["<Tab>"] = cmp.mapping(tab, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(shift_tab, { "i", "s" }),
      ["<C-e>"] = cmp.mapping.abort(),
      ["<C-u>"] = cmp.mapping.scroll_docs(-4),
      ["<C-d>"] = cmp.mapping.scroll_docs(4),
    }),
    sources = cmp.config.sources({
      { name = "nvim_lsp" },
      { name = "buffer" },
      { name = "path" },
    }),
  })

  vim.keymap.set("i", "<Tab>", function() tab(function() feed_key("<Tab>", "i") end) end)
  vim.keymap.set("s", "<Tab>", function() tab(function() feed_key("<Tab>", "s") end) end)
  vim.keymap.set("i", "<S-Tab>", function() shift_tab(function() feed_key("<S-Tab>", "i") end) end)
  vim.keymap.set("s", "<S-Tab>", function() shift_tab(function() feed_key("<S-Tab>", "s") end) end)
  vim.keymap.set("i", "<Down>", function() select_next(function() feed_key("<Down>", "i") end) end)
  vim.keymap.set("s", "<Down>", function() select_next(function() feed_key("<Down>", "s") end) end)
  vim.keymap.set("i", "<Right>", function() select_next(function() feed_key("<Right>", "i") end) end)
  vim.keymap.set("s", "<Right>", function() select_next(function() feed_key("<Right>", "s") end) end)
  vim.keymap.set("i", "<Up>", function() select_prev(function() feed_key("<Up>", "i") end) end)
  vim.keymap.set("s", "<Up>", function() select_prev(function() feed_key("<Up>", "s") end) end)
  vim.keymap.set("i", "<Left>", function() select_prev(function() feed_key("<Left>", "i") end) end)
  vim.keymap.set("s", "<Left>", function() select_prev(function() feed_key("<Left>", "s") end) end)
end

function M.setup_copilot()
  require("copilot").setup({
    suggestion = {
      enabled = true,
      auto_trigger = true,
      keymap = {
        accept = false,
        accept_word = false,
        accept_line = false,
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-]>",
      },
    },
    panel = { enabled = false },
    logger = {
      file_log_level = vim.log.levels.OFF,
      print_log_level = vim.log.levels.OFF,
    },
  })

  vim.g.miyago_copilot_enabled = true
  vim.api.nvim_create_user_command("CopilotToggle", function()
    vim.g.miyago_copilot_enabled = not vim.g.miyago_copilot_enabled
    vim.cmd("Copilot " .. (vim.g.miyago_copilot_enabled and "enable" or "disable"))
  end, { desc = "Toggle Copilot suggestions" })
end

return M
