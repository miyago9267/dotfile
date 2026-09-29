---
spec: nvim-workspace
batch: 1
created: 2026-09-29
---

# Tasks: Neovim multi-root workspace

> Spec: `docs/specs/nvim-workspace/SPEC.md`
> Batch: 1

## 前置條件

- [x] Decisions 1、2 已確認（2026-09-29）
- [x] 確認 spec 已獲 Miyago 核准

## Phase 1：核心可用

- [x] Step 1: 先寫 `tests/workspace_test.lua` 的 T1–T8（Red）
- [x] Step 2: `workspace.lua`：解析 `.code-workspace`、建立／清理 hub、real↔hub 對照表
- [x] Step 3: `:Workspace open/close`：切 cwd、設 tree root、切換 `update_root`，BufEnter 時 reveal
- [x] Step 4: fzf-lua 在 workspace 中加上 `fd -L`／`rg --follow`
- [x] Step 5: `:CopyPath`／`:CopyRelativePath`（含 range），nvim-tree 的 `gy`／`Y` 共用同一套邏輯
- [x] Step 5b: 在 workspace 中讓 agent terminal 的 cwd 為 hub（T12）
- [x] Step 6: T1–T8 轉綠；用 tmux 實機驗 T9、T10

## Phase 2：管理與順手

- [x] Step 7: `:Workspace new/add/remove` 與 fzf picker
- [x] Step 8: `nvim foo.code-workspace` 啟動時自動開啟（T11）
- [x] Step 9: 右鍵 PopUp 選單加入 Copy Path（editor 與 nvim-tree）
- [x] Step 10: 更新 `KEYBINDINGS.md`

## 驗證

- [x] T1–T12 全部通過
- [x] 沒有開 workspace 時，現有行為沒有退化（T10）
