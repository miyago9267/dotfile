---
id: spec-nvim-editing-parity
title: Neovim 編輯體驗補齊（第二批 VSCode 對齊）
status: draft
created: 2026-09-29
updated: 2026-09-29
author: Miyago
tags: [nvim, dx, vscode-parity]
priority: medium
---

# Neovim 編輯體驗補齊（第二批 VSCode 對齊）

## Background

第一批（treesitter、diagnostics、format on save、palette、sticky scroll 等）已上線。
剩下每天會碰到、而 nvim 目前沒有或很弱的四項：

1. 跨檔搜尋取代：只有單檔 `:%s`，沒有 VSCode `Ctrl-Shift-H` 那種「預覽整個專案的變更再套用」。
2. 參數提示：打 `foo(` 時沒有函式簽名；`config/nvim/lua/config/completion.lua`、`lsp.lua` 都沒有 signature help。
3. Git：gitsigns 只綁了 blame／preview／跳 hunk（`plugins.lua` 的 `<leader>gb/gB/gp/gt`、`]h/[h`），不能 stage／reset hunk，也沒有整個分支的 diff 檢視與衝突解決介面。
4. 折疊：沒有設定 `foldmethod`，只能手動折。

peek 定義與參照（fzf-lua 版 `gd`/`gr`）Miyago 判斷不常用，不在本 spec。

## Requirements (EARS)

- **R1**: When Miyago 按 `Space sr`，the system shall 開啟專案範圍的搜尋取代面板，顯示所有符合的檔案與行，並能在預覽後一次套用。
- **R2**: When 在 visual 模式按 `Space sr`，the system shall 以選取文字作為搜尋字串開啟面板；`Space sw` 以游標下的字開啟。
- **R3**: When 在 insert 模式輸入 LSP server 宣告的 signature trigger 字元（通常是 `(`、`,`），the system shall 自動浮出函式簽名並標出目前參數；離開括號或 insert 模式時關閉。
- **R4**: When 在 insert 模式按 `Ctrl-K`，the system shall 手動開關 signature help。
- **R5**: When 游標在 git 改動的 hunk 內，the system shall 提供 `Space gs` stage hunk、`Space gr` reset hunk（visual 模式作用於選取行）、`Space gS` stage 整個檔案、`Space gR` reset 整個檔案、`Space gu` undo 上一次 stage。
- **R6**: When Miyago 按 `Space gd`，the system shall 開啟 diffview 顯示工作目錄相對 HEAD 的所有改動；`Space gh` 顯示目前檔案的 git 歷史；遇到 merge conflict 時 diffview 提供三方對照。
- **R7**: When 開啟有 treesitter parser 的檔案，the system shall 用 treesitter 的結構折疊，預設全部展開（`foldlevel=99`），`za`／`zc`／`zo`／`zM`／`zR` 照 Vim 原生行為運作。
- **R8**: While 折疊中，the system shall 保留折疊行的語法高亮（`foldtext=""`），不顯示預設的 `+-- 12 lines` 文字。
- **R9**: If 某語言沒有 treesitter parser，then the system shall 退回 `foldmethod=indent`，行為一致。

## Non-goals

- 不做 peek 定義／參照（Miyago 判斷不常用）。
- 不做 folding 的 gutter 箭頭（需要 statuscol 類外掛，視覺效益低）。
- 不換掉 gitsigns；diffview 只補 gitsigns 沒有的全局檢視。
- 不做 lazygit 整合（另一套操作模型，之後有需要再評估）。

## Alternatives Considered

### 搜尋取代：grug-far.nvim vs nvim-spectre vs quickfix + `:cdo`

- 採用 grug-far：活躍維護、底層用 rg（已安裝）、面板本身是可編輯 buffer，預覽與套用最接近 VSCode。
- spectre 維護較少、依賴 sed 行為差異；`:cdo` 沒有預覽，不符合「先看再套用」。

### 參數提示：內建 `vim.lsp.buf.signature_help` vs lsp_signature.nvim vs cmp-nvim-lsp-signature-help

- 採用內建：不加外掛，LspAttach 時依 server 的 `signatureHelpProvider.triggerCharacters` 在 `InsertCharPre` 觸發。
- 若實測閃爍或擋到補全選單，再退回 `lsp_signature.nvim`（記錄在 Risks）。

### 折疊：treesitter foldexpr vs LSP foldingRange vs nvim-ufo

- 採用 `vim.treesitter.foldexpr()`：已有 parser、無外掛、離線可用。
- LSP foldingRange 依 server 品質不一；nvim-ufo 功能多但本需求用不到。

## Rabbit Holes

1. signature help 不要與 nvim-cmp 的選單搶焦點：浮窗用 `focusable = false`，並確認 `<Tab>`／`<CR>` 行為不變。
2. `InsertCharPre` 觸發要 debounce 或只在 trigger 字元觸發，避免每打一個字就發 LSP request。
3. 折疊設定要用 window-local（`vim.wo`），並在 `FileType` 決定 treesitter 或 indent；避免 `foldexpr` 在大型檔案拖慢（必要時對超過 N 行的檔案退回 indent）。
4. grug-far 面板是 buffer，要從 session／nvim-tree 行為中排除（filetype `grug-far`）。
5. `Space gr` 在 which-key 目前 `<leader>g` 群組下未被佔用，但 `gr`（無 leader）是 LSP references，不要混淆。

## Architecture

- `config/nvim/lua/plugins.lua`：新增 `MagicDuck/grug-far.nvim`、`sindrets/diffview.nvim`；gitsigns 的 `keys` 補 stage／reset。
- `config/nvim/lua/config/lsp.lua`：`on_attach` 內依 capability 掛 signature help 自動觸發與 `Ctrl-K`。
- `config/nvim/lua/config/options.lua`：折疊預設值（`foldlevel`、`foldlevelstart`、`foldtext`、`fillchars`）與 `FileType` autocmd 選擇 treesitter／indent。
- `config/nvim/KEYBINDINGS.md`：新增「搜尋取代」「Git 操作」「折疊」段落，補 `Ctrl-K`。

## Phase 計畫

### Phase 1：搜尋取代與參數提示（R1–R4）

- grug-far 安裝與三個入口鍵。
- signature help 自動觸發與 `Ctrl-K`。

### Phase 2：Git 與折疊（R5–R9）

- gitsigns stage／reset 鍵、diffview 與兩個入口鍵。
- treesitter 折疊與 indent fallback。
- 更新 `KEYBINDINGS.md`。

## Open Questions（實作前確認）

1. 搜尋取代的入口鍵用 `Space sr`（新開 `Space s` = Search 群組）可以嗎？**推薦**：可以，之後 `Space s` 也能放其他搜尋類功能。
2. signature help 手動鍵用 insert 模式的 `Ctrl-K`（會蓋掉 Vim 內建的 digraph 輸入）可以嗎？**推薦**：可以，digraph 幾乎用不到。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| 內建 signature help 浮窗與 cmp 選單重疊或閃爍 | 打字干擾 | 實測；不行就改用 `lsp_signature.nvim` |
| treesitter foldexpr 在大檔變慢 | 開檔、捲動延遲 | 超過 5000 行的檔案退回 indent |
| grug-far 一次改太多檔 | 誤改 | 面板預覽後才套用；dotfile 與專案都在 git，可還原 |
| diffview 與 nvim-tree／archipelago hub 互動 | 在 workspace 中路徑錯亂 | 在 workspace 中實測；diffview 以目前檔案所在 repo 為準 |
