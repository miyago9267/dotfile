---
spec: nvim-layout-docks
batch: 1
created: 2026-10-01
---

# Tests: Neovim 固定區塊版面

> Spec: `docs/specs/nvim-layout-docks/SPEC.md`
> 驗證方式：tmux 實機（固定 160x40），用 `nvim_win_get_position`／`nvim_win_get_width/height` 記錄每個視窗的位置與尺寸做比對；agent 用假的長駐指令（例如 `cat`）代替真實 CLI，避免耗用額度。

| ID | Req | EARS acceptance | 驗證方式 |
| --- | --- | --- | --- |
| T1 | R1 | When 依序開 tree、agent、terminal，再開關 terminal 三次、在編輯器 `:vsplit` 再 `:close`，tree 寬度恆為 32、agent 寬度恆為同一值 | tmux + 視窗幾何比對 |
| T2 | R2 | When 開 tree，其視窗 col=0、高度等於可用總高度 | tmux + 幾何 |
| T3 | R3 | When 開 Claude 與 Codex 任一，其視窗緊貼右緣、高度等於可用總高度、寬度約為總寬 30% | tmux + 幾何 |
| T4 | R4 | When 先開 Codex 再開 Gemini，畫面上 agent 視窗只有 1 個；切回 Codex 時其 terminal job 仍存活（`jobwait` timeout 回 -1） | tmux + 幾何 + job 檢查 |
| T5 | R5 | When 開 terminal，其視窗左緣 > tree 右緣、右緣 < agent 左緣、高度 12 | tmux + 幾何 |
| T6 | R6 | When 開 terminal 後再開 `Space dd`，底部只剩 Trouble 視窗；再開 terminal 時為同一個 terminal buffer、job 仍存活 | tmux + 幾何 + job 檢查 |
| T7 | R7 | When 開 tree、agent、terminal 後關掉唯一的編輯視窗，畫面仍保留一個編輯視窗 | tmux |
| T8 | R8 | When claudecode 開啟 diff（以 `:ClaudeCodeDiff` 或其 API 模擬），diff 視窗位於編輯器區、不在任何 dock | tmux + 幾何 |
| T9 | R9 | When 編輯器有兩個分割時按 `Space z`，目前分割填滿編輯器區，tree／agent／terminal 尺寸不變；再按一次還原 | tmux + 幾何 |
| T10 | R10 | When 完成後，列出的既有快捷鍵都仍綁定且作用正確；Leaf 預覽仍是浮窗、不被抓進 dock | headless keymap 檢查 + tmux |
| T11 | R11 | When `nvim .` 啟動，tree 為 col=0、w=32、全高且有焦點，並有一個空編輯視窗；此時 `Space tt` 的 terminal 只在編輯器下方（h=12、tree 仍 w=32 全高），`Space ac` 的 agent 在右側 w=48 全高；空編輯視窗 `:q` 離開 Neovim；cmdheight 不變 | tmux + 幾何 |
