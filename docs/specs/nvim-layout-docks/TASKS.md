---
spec: nvim-layout-docks
batch: 1
created: 2026-10-02
---

# Tasks: Neovim 固定區塊版面

> Spec: `docs/specs/nvim-layout-docks/SPEC.md`
> Batch: 1

## 前置條件

- [x] 確認 spec 已獲 Miyago 核准
- [x] 確認相關依賴已就位（edgy.nvim 由 lazy.nvim 安裝）

## 實作步驟

- [x] Phase 1：`plugins.lua` 加 edgy（left／right／bottom 與尺寸、關閉動畫）、`options.lua` 加 `splitkeep = "screen"`
- [x] Phase 1：新增 `config/layout.lua`（claude／agent／terminal／Trouble 的視窗判斷、R7 空編輯視窗與離開邏輯）
- [x] Phase 1：`agent.lua` 的 Agent buffer 顯示前標記並設 filetype，改由 edgy 決定位置與寬度
- [x] Phase 1：`keymaps.lua` 的 terminal 改成固定 buffer，開在底部面板
- [x] Phase 2：單一插槽（agent 入口、terminal、Trouble 入口）只關視窗、不刪 buffer
- [x] Phase 2：claudecode diff 留在編輯器區（不需額外設定，已驗證）
- [x] Phase 2：zoom 只作用於編輯器區（既有 `wincmd _`／`|` 搭配 dock 的 winfix 即可，已驗證）
- [x] 更新 `KEYBINDINGS.md` 版面段落
- [x] R11：`layout.ensure_main` 在開 dock 內容前補空編輯視窗（`hide_agents`／`hide_panels`／`trouble`），啟動時 schedule 一次

## 驗證

- [x] 所有步驟完成
- [x] 測試通過（見 TESTS.md，T1–T10 於 tmux 160x40 實機量測）
- [x] 文件更新

## 備註

- R7 條文於實作時改寫（逐一 `:q` 離開的情境），見 SPEC R7。
- `Space as` 等 visual 送選取用 `'<`／`'>`，在 visual mode 內第一次按會讀到舊 marks；這是既有行為，未在本 spec 處理。
