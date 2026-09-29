---
spec: nvim-workspace
batch: 1
created: 2026-09-29
---

# Tests: Neovim multi-root workspace

> Spec: `docs/specs/nvim-workspace/SPEC.md`
> 執行方式：`nvim --headless -l config/nvim/tests/workspace_test.lua`（純 assert，不引入測試框架；fixture 放在 temp 目錄）

| ID | Req | EARS acceptance | 驗證方式 |
| --- | --- | --- | --- |
| T1 | R5 | When 讀取含相對路徑、絕對路徑、`~` 與整行註解／尾逗號的 `.code-workspace`，the system shall 解析出正確的真實路徑清單 | headless unit |
| T2 | R1 | When 開啟兩個 folder 的 workspace，the system shall 在 hub 產生兩個指向正確目標的 symlink，並把 cwd 設為 hub | headless unit |
| T3 | R8 | If 兩個 folder 同名，then hub 節點為 `name` 與 `name-2` | headless unit |
| T4 | R7 | If 某個 folder 不存在，then 跳過該 folder、發出警告，其餘照常建立 | headless unit |
| T5 | R6 | When 移除 folder 後重建 hub，the system shall 只刪除 hub 內的 symlink，目標目錄內容完好 | headless unit |
| T6 | R2 | When 透過 hub 路徑開檔，buffer 名稱是真實路徑，且 real→hub 對照回傳正確的 hub 路徑 | headless unit |
| T7 | R3 | When 執行 `:CopyPath`／`:CopyRelativePath`（含 range），暫存器內容分別是真實絕對路徑／`<folder>/<relpath>`，range 時附加 `:start-end` | headless unit |
| T8 | R4 | While workspace 開啟中，fzf-lua 的 files／grep 指令包含 `-L`／`--follow`，且 cwd 為 hub | headless unit（檢查組出來的 opts） |
| T9 | R2 | When 在 workspace 中開檔，nvim-tree root 維持 hub，並 highlight 對應節點 | tmux 實機 |
| T10 | R9 | When 沒有開 workspace，nvim-tree 的 `update_root` 與 fzf-lua 的行為和現在相同 | headless unit + tmux 實機 |
| T11 | R5 | When 執行 `nvim foo.code-workspace`，啟動後直接是 workspace 狀態，而不是打開 JSON 檔 | tmux 實機 |
| T12 | R10 | While workspace 開啟中，agent terminal 的 cwd 是 hub，並且貼上 relative path 後能讀到檔案 | headless unit（檢查 cwd）+ tmux 實機 |
