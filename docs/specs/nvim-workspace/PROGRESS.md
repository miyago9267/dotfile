---
spec: nvim-workspace
created: 2026-09-29
---

# Progress: Neovim multi-root workspace

> Spec: `docs/specs/nvim-workspace/SPEC.md`

## Phase 1：核心可用

> Status: completed

- `config/nvim/lua/config/workspace.lua`：解析、hub、real↔hub 對照、copy path、search opts、nvim-tree exclude／on_attach
- `plugins.lua`：nvim-tree 接上 `exclude` 與 `on_attach`；fzf-lua 改走 `config.workspace.fzf`
- 驗證：`nvim --headless -u NONE -l config/nvim/tests/workspace_test.lua` 13 pass（T1–T8、T10、T12、R6）；
  tmux 實機驗過 T9（root 停在 hub、reveal、git 標記）、T10（沒開 workspace 時 update_root 照舊）、搜尋跨 folder

## Phase 2：管理與順手

> Status: completed

- `:Workspace new/add/remove/list/close`，用 fzf picker 選擇
- VimEnter 自動開啟 `.code-workspace`（tmux 實機驗過 T11）
- 右鍵 PopUp：Copy Path / Copy Relative Path
- `KEYBINDINGS.md` 已更新
