---
spec: nvim-editing-parity
batch: 1
created: 2026-09-29
---

# Tests: Neovim 編輯體驗補齊

> Spec: `docs/specs/nvim-editing-parity/SPEC.md`
> 驗證方式：headless 檢查設定與 keymap；互動行為用 tmux 實機操作（同第一批做法）。fixture 放在 scratchpad，不碰真實專案。

| ID | Req | EARS acceptance | 驗證方式 |
| --- | --- | --- | --- |
| T1 | R1 | When 在含 3 個檔案都有 `foo` 的目錄按 `Space sr` 並輸入 `foo`→`bar`，the system shall 列出 3 個檔案，套用後 3 個檔案都變成 `bar` | tmux 實機 |
| T2 | R2 | When visual 選取 `foo` 後按 `Space sr`，面板的搜尋欄預填 `foo`；`Space sw` 預填游標下的字 | tmux 實機 |
| T3 | R3 | When 在 `.ts` 檔輸入 `f(`（`f` 有兩個參數），浮窗顯示簽名；輸入 `,` 後標示第二個參數；`Esc` 後浮窗關閉 | tmux 實機 |
| T4 | R4 | When insert 模式按 `Ctrl-K`，浮窗開關；cmp 選單出現時 `<Tab>`／`<CR>` 行為不變 | tmux 實機 |
| T5 | R5 | When 在 git repo 改兩處後於第一處按 `Space gs`，`git diff --cached` 只含第一處；`Space gu` 後恢復未 stage；`Space gr` 還原該 hunk | tmux 實機 + git 指令檢查 |
| T6 | R6 | When 按 `Space gd`，diffview 開啟並列出所有改動檔；`Space gh` 顯示目前檔案歷史；製造 merge conflict 時可見三方對照 | tmux 實機 |
| T7 | R7 | When 開啟 `.lua`／`.ts` 檔，`foldmethod=expr` 且 `foldexpr` 為 treesitter，初始沒有任何折疊；在 function 上 `za` 折起、再 `za` 展開 | headless（檢查選項）+ tmux 實機 |
| T8 | R8 | When 折疊一個 function，折疊行顯示原本那一行的高亮內容，而不是 `+-- N lines` | tmux 實機 |
| T9 | R9 | When 開啟沒有 parser 的檔案類型，`foldmethod=indent` | headless |
| T10 | 全部 | When 完成後，現有鍵（`gr` references、`Ctrl-K` normal 切視窗、`<Tab>` 補全、Copilot）行為不變 | headless keymap 檢查 + tmux |
