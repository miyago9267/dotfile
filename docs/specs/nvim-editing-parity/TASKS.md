---
spec: nvim-editing-parity
batch: 1
created: 2026-09-29
---

# Tasks: Neovim 編輯體驗補齊

> Spec: `docs/specs/nvim-editing-parity/SPEC.md`
> Batch: 1

## 前置條件

- [ ] Miyago 核准 spec，並確認 Open Questions 1（`Space sr`）、2（insert `Ctrl-K`）

## Phase 1：搜尋取代與參數提示

- [ ] Step 1: 加 grug-far.nvim，綁 `Space sr`（n／v）、`Space sw`；which-key 新增 `Space s` = Search 群組
- [ ] Step 2: `lsp.lua` on_attach 依 `signatureHelpProvider.triggerCharacters` 自動觸發 signature help（`focusable = false`、border rounded）
- [ ] Step 3: insert `Ctrl-K` 手動開關
- [ ] Step 4: tmux 實機驗 T1–T4

## Phase 2：Git 與折疊

- [ ] Step 5: gitsigns 補 `Space gs/gr/gS/gR/gu`（gs／gr 支援 visual）
- [ ] Step 6: 加 diffview.nvim，綁 `Space gd`、`Space gh`
- [ ] Step 7: `options.lua` 折疊預設值；`FileType` 依 parser 選 treesitter 或 indent；大檔退回 indent
- [ ] Step 8: 更新 `KEYBINDINGS.md`
- [ ] Step 9: 驗 T5–T10

## 驗證

- [ ] T1–T10 全部通過
- [ ] 現有鍵行為沒有退化（T10）
