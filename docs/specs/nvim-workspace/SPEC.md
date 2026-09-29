---
id: spec-nvim-workspace
title: Neovim multi-root workspace
status: implemented
created: 2026-09-29
updated: 2026-09-29
author: Miyago
tags: [nvim, workspace, dx]
priority: medium
---

# Neovim multi-root workspace

## Background

VSCode 可以把多個目錄放進同一個 workspace（`.code-workspace`），file tree、搜尋、
LSP 都當成同一個專案。Neovim 只有單一 cwd，nvim-tree 也只能有一個 root。

直接手動做「symlink 目錄」可以把多個 repo 接在同一棵樹上，但實測有三個路徑問題：

1. nvim-tree 的 copy path（`gy` / `Y`）拿到的是 symlink 路徑，貼給 agent 會指到錯的地方。
2. `update_focused_file.update_root = true` 會在開檔時把 tree root 跳到真實 repo，
   workspace 視圖散掉；關掉後，真實路徑又不在 tree root 底下，定位不到檔案。
3. `fd` / `rg` 預設不跟 symlink，搜尋結果是空的。

已實測確認的事實（Neovim 0.12.4, macOS）：

- 透過 symlink 路徑 `:e` 的檔案，`nvim_buf_get_name()` 回傳的是**真實路徑**。
  所以 LSP、gitsigns、claudecode.nvim（用 `nvim_buf_get_name`）拿到的路徑已經是對的。
- `fd -L` / `rg --follow` 可以正確走進 symlink。

所以要自己做的是：workspace 的定義與生命週期，還有「tree、搜尋、複製路徑」這三個會碰到
symlink 路徑的地方。

## Requirements (EARS)

- **R1**: When Miyago 開啟一個 workspace，the system shall 在 hub 目錄為每個 folder
  建立一個 symlink，並把 cwd 與 nvim-tree root 設為 hub。
- **R2**: When 開啟的檔案位於某個 workspace folder 內，the system shall 讓 buffer 名稱
  保持真實路徑，並在 nvim-tree 中定位到對應的 hub 節點，tree root 不跳走。
- **R3**: When Miyago 複製路徑（editor、nvim-tree 或右鍵選單），the system shall 提供兩種格式：
  absolute（真實絕對路徑）與 relative（相對於 cwd；workspace 中即 `<folder>/<relpath>`）；
  帶行號範圍時附加 `:start-end`（單行為 `:line`）。
- **R4**: While workspace 開啟中，the system shall 讓 fzf-lua 的 files 與 live_grep
  搜尋涵蓋所有 folder，結果顯示為 `<folder>/<relpath>`，開啟後的 buffer 為真實路徑。
- **R5**: When Miyago 以 `nvim foo.code-workspace` 啟動或執行 `:Workspace open`，
  the system shall 讀取 VSCode `.code-workspace` 格式的 `folders[].path`
  （相對於檔案本身、絕對路徑或 `~`）。
- **R6**: When Miyago 執行 `:Workspace add` / `remove`，the system shall 更新
  workspace 檔並即時重建 hub 與 tree。
- **R7**: If folder 路徑不存在，then the system shall 跳過該 folder 並顯示警告，
  其餘 folder 照常開啟。
- **R8**: If 兩個 folder 的名稱相同，then the system shall 以 `name-2` 等後綴區分 hub 節點。
- **R9**: When 沒有開啟 workspace，the system shall 保持現有行為不變
  （包含 nvim-tree 的 `update_root`）。
- **R10**: While workspace 開啟中，the system shall 讓 agent terminal 以 hub 為 cwd，
  使 agent 看得到所有 folder；relative path 以 hub 為基準，因此在 agent 中可直接使用。

## Non-goals

- 不做自訂 tree renderer，繼續沿用 nvim-tree。
- 不做 session 還原（開過哪些檔、視窗配置）。
- 不支援 `.code-workspace` 裡的 `settings`、`tasks`、`launch`、`extensions`。
- 不處理 JSONC 的區塊註解；只去掉整行的 `//` 註解和尾逗號。
- 不改 LSP 設定：真實路徑讓每個 server 自己找 root，本來就是對的。

## Alternatives Considered

### 方案 A：自己寫 multi-root tree

- 可以完全控制，但等於重寫 nvim-tree 的 git 狀態、檔案操作、icon。成本高，不符合做減法的原則。

### 方案 B：每個 tab `:tcd` 一個 project

- 不用改設定，但沒有統一的 tree 和搜尋，不符合「接在一起」的需求。

### 方案 C：使用者手動建 symlink 目錄

- 就是 Background 列出的三個路徑問題；本 spec 等於是把它補完。

### 採用：hub-of-symlinks + 真實路徑對外（見 ADR）

## Rabbit Holes

1. 不要讓任何「對外」的路徑（複製、agent、搜尋開啟的檔案）使用 hub 路徑；hub 只給 tree 和搜尋的 cwd 用。
2. nvim-tree 的 reveal 要用「真實路徑 → hub 路徑」的對照，不要改 buffer 名稱去配合 tree。
3. 清理 hub 時只刪 hub 目錄裡的 symlink，絕不遞迴刪除 symlink 指向的內容。
4. Agent terminal 以 hub 為 cwd，在 hub 根目錄跑 `git` 會失敗（hub 不是 repo）；已確認可接受，不要為此加 wrapper。

## Architecture

```
workspace 檔 (.code-workspace)
  └─ folders[] ──▶ workspace.lua ──▶ hub: stdpath("state")/workspace-hub/<name>/
                     │                    ├─ api  -> ~/code/api
                     │                    └─ web  -> ~/code/web
                     ├─ cwd / nvim-tree root = hub
                     ├─ roots 對照表 {hub_path <-> real_path}
                     │    ├─ BufEnter：real -> hub，nvim-tree reveal
                     │    └─ copy path：永遠輸出 real
                     └─ fzf-lua：cwd = hub，fd -L / rg --follow
```

- 新檔：`config/nvim/lua/config/workspace.lua`（單一模組：解析、hub、commands、對照表）。
- 修改：`plugins.lua`（nvim-tree 的 `update_root` 改由 workspace 狀態決定；fzf-lua 在 workspace 中加 follow）。
- 修改：`keymaps.lua`（copy path 與右鍵 PopUp 選單）。
- workspace 檔預設放在 `stdpath("data")/workspaces/<name>.code-workspace`，不 commit
  （路徑依機器而異）；也可以開任意位置的 `.code-workspace`。

### Commands

| 指令 | 行為 |
| --- | --- |
| `:Workspace open [name\|path]` | 無參數時用 fzf 選 |
| `:Workspace new <name>` | 以 cwd（或目前檔案的 git root）建立新 workspace |
| `:Workspace add [dir]` | 預設加入目前檔案的 git root |
| `:Workspace remove` | 用 fzf 選要移除的 folder |
| `:Workspace close` | 回到開啟前的 cwd，並恢復 `update_root` |
| `:CopyPath` / `:CopyRelativePath` | absolute／relative；帶 range（visual 或 `:.CopyPath`）時附加 `:start-end` |

## ADR

### ADR-1：tree 沿用 nvim-tree，靠 symlink hub 接起來

- 決策：不寫新 tree。hub 是可以隨時重建的 symlink 目錄。
- 原因：git 狀態、檔案操作、icon 都能直接沿用；可靠性高，維護成本最低。

### ADR-2：workspace 檔用 VSCode `.code-workspace` 格式

- 決策：只讀寫 `folders[]`，其他欄位原樣保留、不解讀。
- 原因：同一份檔案 VSCode 也能開；不發明新格式。

### ADR-3：對外路徑一律是真實路徑

- 決策：buffer 名稱、copy path、搜尋開檔都是真實路徑；hub 路徑只在內部使用。
- 原因：這是 Miyago 的核心顧慮（貼給 agent 的路徑要對）。Neovim 已會自動解析
  symlink，只需補上 nvim-tree 和 copy path。

## Phase 計畫

### Phase 1：核心可用

- 解析 `.code-workspace`、建立 hub、`:Workspace open/close`、切換 cwd 和 tree root。
- 在 workspace 中停用 `update_root`，並用對照表做 reveal。
- fzf-lua 加上 follow。
- `:CopyPath` / `:CopyRelativePath`，nvim-tree 的 `gy`（absolute）／`Y`（relative）改成用同一套邏輯。
- Agent terminal 在 workspace 中以 hub 為 cwd。

### Phase 2：管理與順手

- `:Workspace new/add/remove` 與 fzf picker。
- `nvim foo.code-workspace` 啟動時自動開啟 workspace。
- 右鍵 PopUp 選單加入 Copy Path / Copy Relative Path（editor 和 nvim-tree）。
- 更新 `KEYBINDINGS.md`。

## Decisions（2026-09-29 Miyago 確認）

1. Agent terminal 的 cwd 是 hub。editor 不需要強制綁定目錄，但 agent 要看得到 workspace 的全部內容；
   git 由 agent 自己 cd 進 repo 處理，不是問題。
2. 複製路徑要兩種：absolute 和 relative，兩種都要有，不設單一預設。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| nvim-tree 對 symlink 目錄的 git 狀態顯示不完整 | tree 上看不到修改標記 | 已實測：symlink 內的修改標記正常顯示 |
| 清理 hub 誤刪真實檔案 | 資料遺失 | 只 `vim.uv.fs_unlink` hub 內的 symlink，並有測試覆蓋 |
| 大型 repo 加 `fd -L` 時遇到 symlink 迴圈 | 搜尋變慢或重複 | `fd` 本身會偵測迴圈；另外排除 `node_modules`、`.git` |
| `.code-workspace` 含註解或尾逗號 | 解析失敗 | 最小化處理整行註解和尾逗號；失敗時顯示清楚的錯誤 |
