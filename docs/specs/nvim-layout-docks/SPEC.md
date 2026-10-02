---
id: spec-nvim-layout-docks
title: Neovim 固定區塊版面（tree／編輯器／agent dock／底部面板不互搶）
status: implemented
created: 2026-10-01
updated: 2026-10-02
author: Miyago
tags: [nvim, layout, dx, vscode-parity]
priority: high
---

# Neovim 固定區塊版面

## Background

agent、terminal、file tree 與編輯器分割會互相搶版面。已查證的原因：

1. `equalalways` 為預設值（開），任何分割開關都會重新平均所有視窗，tree 與 agent 寬度跟著跳動（`config/nvim/lua/config/options.lua` 沒有設定 `equalalways`、`winfixwidth`、`splitkeep`）。
2. terminal 用 `botright split | resize 12`（`config/nvim/lua/config/keymaps.lua`），橫跨整個畫面底部，連 tree 與 agent 的高度一起壓縮。
3. agent 沒有共用位置：Claude 走 claudecode.nvim（`provider = "auto"`，snacks 安裝後改用 snacks terminal，右側 30%）；Codex／OpenCode／Gemini 由 `config/nvim/lua/config/agent.lua` 各自 `botright vsplit`。開兩個 agent 就多兩欄。

目標是 VSCode 的固定區塊模型：側欄、編輯器、secondary sidebar、底部面板各自固定，開關任何一區不影響其他區。

## Decisions（2026-10-01 Miyago 確認）

1. 底部面板只在編輯器下方，不橫跨 tree 與 agent dock（同 VSCode 預設）。
2. agent 留在 nvim 右側 dock（保留 `Space as` 送選取、claudecode diff），不搬到 herdr pane。

## 目標版面

```
┌──────┬────────────────────────┬─────────┐
│ tree │  編輯器（只有這裡會分割）│ agent   │
│ 左側  │                        │ dock    │
│ 固定  ├────────────────────────┤ 右側固定 │
│ 寬度  │ 底部面板：terminal／     │ 單一插槽 │
│      │ Problems 共用單一插槽    │         │
└──────┴────────────────────────┴─────────┘
```

## Requirements (EARS)

- **R1**: When 開啟或關閉任一區塊（tree、agent dock、底部面板）或在編輯器內分割／關閉視窗，the system shall 維持其他區塊的寬度與高度不變。
- **R2**: When 開啟 file tree，the system shall 放在左側、佔滿整個高度、固定寬度 32 欄。
- **R3**: When 開啟任一 agent（Claude、Codex、OpenCode、Gemini），the system shall 放在右側 dock、佔滿整個高度、固定寬度為畫面的 30%。
- **R4**: While 右側 dock 已有一個 agent 顯示，when 開啟另一個 agent，the system shall 以新 agent 取代畫面上的那一個（舊 agent 的程序與 buffer 保留，可再切回），dock 內同時只顯示一個 agent。
- **R5**: When 開啟 terminal（`Space tt`、`Ctrl-,`、`:Shell`）或 Problems 面板（`Space dd`／`Space db` 等 Trouble 指令），the system shall 放在底部面板，寬度只涵蓋編輯器欄，固定高度 12 行。
- **R6**: While 底部面板已有內容，when 開啟另一種面板內容，the system shall 以新內容取代顯示（terminal 程序保留），面板內同時只顯示一個。
- **R7**: Miyago 以逐一 `:q` 視窗的方式離開。When 關掉最後一個編輯視窗（非 dock、非浮動）而 dock 視窗仍在，the system shall 保留一個空的編輯視窗，讓 dock 維持原尺寸；when 在這個空的、無檔名、未修改的編輯視窗下 `:q` 且沒有其他編輯視窗，the system shall 整個離開 Neovim（等同 `:qa`），不重複建立空視窗形成無限迴圈。
- **R8**: When 由 claudecode.nvim 開啟 diff，the system shall 在編輯器區顯示 diff，不放進任何 dock。
- **R9**: When 使用 `Space z`（zoom），the system shall 只在編輯器區內最大化目前分割，不改變 dock 大小。
- **R10**: 現有快捷鍵（`Space aa/ac/ao/ag`、`Space as` 等送選取、`Space tt`、`Ctrl-,`、`Space dd/db/ds/dr`、`Ctrl-e`／`Space uf`、`Ctrl-h/j/k/l` 視窗移動）行為與入口不變，只改變視窗落點。
- **R11**: When 開啟任一 dock 內容（agent、terminal、Trouble）時沒有任何編輯視窗，或以 `nvim .` 啟動只有 file tree，the system shall 先補一個空的編輯視窗再開啟，使 dock 維持固定尺寸（tree 32 欄、底部面板 12 行），不讓剩餘空間被 cmdline 吃掉；啟動時 tree 保持焦點。

## Non-goals

- 不把 agent 或 terminal 搬到 herdr／Ghostty pane（Decision 2）。
- 不做面板分頁列（VSCode panel 的 tab bar）；切換用既有快捷鍵。
- 不做版面記憶／session 還原（session 功能已撤回）。
- 不改 agent 的啟動指令與 cwd 邏輯（archipelago workspace 中仍以 hub 為 cwd）。

## Alternatives Considered

### 方案 A：edgy.nvim（採用）

- folke 維護（1.1k stars，持續更新），專門處理固定 dock：預先定義 left／right／bottom 區塊，依 filetype／buffer 條件自動把視窗搬進對應區塊並固定大小，編輯器分割不受影響。
- 已查原始碼：完整排版先 `wincmd J/K`（bottom、top）再 `wincmd H/L`（left、right），左右區塊佔滿高度，底部區塊自然只在編輯器下方，符合 Decision 1。

### 方案 B：手刻（`noequalalways` + `winfixwidth/height` + 自訂開窗位置）

- 不加外掛，但要自己處理所有開窗入口（claudecode、snacks、Trouble、nvim-tree 各自有開窗邏輯）與關窗後的復原，邊界情況多，維護成本高。

### 方案 C：agent／terminal 搬到 herdr pane

- 完全不搶 nvim 版面，但失去 claudecode 的選取傳送與 diff 整合。Miyago 選擇不採用。

## Rabbit Holes

1. 「單一插槽」是 edgy 沒有的語意（edgy 會把同區多個 view 疊在一起）。要在開窗入口（`agent.lua`、terminal toggle、Trouble）先關掉同區其他視窗，而不是改 edgy。
2. claudecode 走 snacks terminal：filter 要用 buffer 變數或指令名辨識 Claude，避免把一般 snacks terminal 或 leaf.nvim 的 Leaf 浮窗抓進 dock（Leaf 是 float，應排除）。
3. claudecode 的 diff 視窗不能被 dock 規則抓走（R8）。
4. edgy 的 dock 視窗不能用一般方式調整大小（官方限制），需要時用 edgy 提供的 keys。
5. archipelago 會在 workspace 開關時重設各視窗 cwd 與 tree root；確認 edgy 搬移 tree 視窗不會觸發 root 變動。
6. `laststatus=3` 已設定；需新增 `splitkeep = "screen"`（edgy 建議，避免開 dock 時編輯器內容跳動）。

## Architecture

- `config/nvim/lua/plugins.lua`：新增 `folke/edgy.nvim`，定義 left（NvimTree）、right（Claude terminal、`Agent://*` buffers）、bottom（`Space tt` terminal、Trouble）三區與尺寸。
- `config/nvim/lua/config/options.lua`：`splitkeep = "screen"`；必要時 `equalalways = false`。
- `config/nvim/lua/config/agent.lua`：開 agent 前關閉 dock 內其他 agent 視窗（只關視窗、保留 buffer 與程序）；不再自行決定 `botright vsplit` 的位置與寬度，交給 edgy。
- `config/nvim/lua/config/keymaps.lua`：terminal toggle 改成固定 buffer（可重複叫回）並在開啟前關閉底部的其他面板；不再 `botright split`。
- claudecode.nvim 設定：確認 provider 與 dock filter 相容；必要時固定 provider。
- `config/nvim/KEYBINDINGS.md`：補一段版面說明。

## Phase 計畫

### Phase 1：dock 骨架（R1–R3、R5、R7、R10）

- 加 edgy、`splitkeep`，三區定義與尺寸；tree、agent、terminal、Trouble 都落在正確區塊。

### Phase 2：單一插槽與邊界（R4、R6、R8、R9）

- agent 與底部面板的單一插槽切換；claudecode diff 留在編輯器；zoom 只作用於編輯器。
- 更新 `KEYBINDINGS.md`。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| claudecode／snacks terminal 的視窗辨識失準 | Claude 不進 dock 或誤抓其他 terminal | 以 buffer 變數或指令名精準比對，實測 Claude、Leaf、一般 terminal 三種 |
| edgy 與 archipelago 的 tree root 管理互相干擾 | workspace 中 tree 跳 root | 在 workspace 中實測；edgy 只搬視窗，不呼叫 tree API |
| 單一插槽關窗時誤殺 agent 程序 | 對話中斷 | 只 `nvim_win_close`，buffer 設 `bufhidden=hide`；測試確認切回後程序仍在 |
| edgy 動畫或重排造成閃爍 | 視覺干擾 | 關閉 `animate` |
