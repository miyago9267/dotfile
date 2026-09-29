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

## Phase 3：抽成獨立插件

> Status: completed (2026-09-29)

- 抽成開源插件 [archipelago.nvim](https://github.com/miyago9267/archipelago.nvim)（MIT）；dotfile 改用 lazy 載入（本機有 `~/Project/Active/Packages/archipelago.nvim` 時用 local 版）
- `config/nvim/lua/config/workspace.lua` 與 `tests/workspace_test.lua` 移除，測試改在插件 repo（unit + 真 nvim-tree 整合測試）
- 行為調整：沒開 workspace 時加 folder 會自動建立 untitled workspace，`:Workspace save` 才存檔；workspace 開啟期間暫停 nvim-tree 的 `update_root`
