# Neovim 快捷鍵

核心原則：Vim 負責編輯；plugin 只提供視覺效果、file tree、tmux 導航與 Agent。

## 編輯

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl-s` | 儲存 |
| `Ctrl-z` | 復原 |
| `Ctrl-f` | 目前檔案搜尋 |
| `j` / `k` | 依 Miyago 習慣交換上下移動 |
| `:find` | 找檔案 |
| `:vimgrep` | 搜尋專案 |
| `:%s` | 取代文字 |

## Completion

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl-Space` | 開啟傳統 completion |
| `Ctrl-n` / `Ctrl-p` | 下一個／上一個候選 |
| `↓` / `→` | 下一個候選 |
| `↑` / `←` | 上一個候選 |
| `Enter` | 確認候選 |
| `Tab` | Copilot 建議 → completion 候選 → 原本的 Tab |
| `Shift-Tab` | 上一個 completion 候選 |
| `Space ap` | 開關 Copilot 建議（預設自動開啟） |

傳統 completion 只使用目前 buffer 與 path；不依賴 LSP。
Copilot 未登入、沒有 Node 或 credentials 時會靜默跳過，不影響其他 completion。

## LSP

| 快捷鍵 | 功能 |
| --- | --- |
| `gd` | 跳到 definition |
| `gD` | 跳到 declaration |
| `gr` | 找 references |
| `K` | 顯示 hover documentation |
| `F2` | Rename symbol |
| `Space ca` / `Space cf` | Code action／format |

目前涵蓋 C/C++、Lua、Go、Rust、Python、TypeScript、Vue、HTML、CSS、YAML、JSON、TOML、XML、Markdown、Bash、Terraform 與 Dockerfile。
每個 server 都會先檢查 executable；沒有安裝時只失去該語言的智慧功能，不影響 Neovim 啟動。

## 顯示開關

| 快捷鍵 | 功能 |
| --- | --- |
| `Space un` | 開關行數與 relative number |
| `Ctrl-e` / `Space uf` | 開關 file tree |
| `Space ub` | 開關透明背景 |
| `Space uc` | 開關 cursorline |

F1 / F3 / F4 也分別對應透明背景、行數、file tree；F12 對應原生 tag jump。
它們只是有實體 F-key 或 SSH/WSL 環境時的相容入口，MacBook 以 `Space` 入口為準。

## Buffer / Window

| 快捷鍵 | 功能 |
| --- | --- |
| `Space bb` | 列出 buffer |
| `Space bn` / `Space bp` | 下一個／上一個 buffer |
| `Ctrl-Left` / `Ctrl-Right` | 左／右切換 buffer（當作檔案 tab 使用） |
| `Space bc` / `Space bx` | 建立／關閉 buffer |
| `Space b?` / `Space bq` | 快速挑選／挑選後關閉 buffer |
| `Space b<` / `Space b>` | 移動目前 buffer 順序 |
| `Space bo` / `Space bl` / `Space br` | 關閉其他／左側／右側 buffer |
| `Space bP` | 固定／取消固定目前 buffer |
| `Space bd` / `Space be` | 按 directory／extension 排序 |

上方 buffer tab bar 由 `bufferline.nvim` 提供；可直接點選切換，中鍵關閉。它顯示的是 buffer，不是 Vim tabpage。

Space prefix 也遵循 tmux 的 pane 操作邏輯：

| 快捷鍵 | 功能 |
| --- | --- |
| `Space -` / `Space \|` | Horizontal／vertical split |
| `Space h/j/k/l` | 切換 window 或 tmux pane |
| `Space H/J/K/L` | 調整 window 大小 |
| `Space =` | 平均所有 window |
| `Space z` | 最大化／還原目前 window |
| `Ctrl-w` | Vim 原生 window prefix |
| `Space wv` / `Space ws` | 舊的 split aliases |
| `Space wh/wl/wk/wj` | 往左／右／上／下開新 split（VSCode Split Editor） |
| `Space wH/wL/wK/wJ` | 把目前 window 搬到最左／右／上／下 |
| `Space wx` | 和下一個 window 互換位置 |
| `Space ←/→/↑/↓` | 切換 window（等同 `Space h/l/k/j`） |
| `Space Shift+方向鍵` | 調整 window 大小 |
| `Space w` + 方向鍵 | 往該方向開新 split |
| `Space w` + `Shift+方向鍵` | 把 window 搬到該方向最邊邊 |
| `Ctrl-h/j/k/l` | 快速切換 Neovim 或 tmux pane |

## Tab

| 快捷鍵 | 功能 |
| --- | --- |
| `Space c` | 開新 tab |
| `Space [` / `Space ]` | 上一個／下一個 tab |
| `Space Tab` | 回到上一個 tab |
| `Space x` | 關閉目前 tab |
| `Space 1..9` | 跳到指定 tab |

## Terminal / Agent

| 快捷鍵 | 功能 |
| --- | --- |
| `Space tt` | 開關 terminal |
| `Ctrl-,` | 開關 terminal（舊習慣相容入口） |
| `Space ts` | 開啟 shell terminal |
| `:Shell <command>` | 在 terminal split 執行 shell command |
| `Space aa` | 開關 Claude Code panel |
| `Space ac` | 開關 Codex panel |
| `Space ao` | 開關 OpenCode panel |
| `Space ag` | 開關 Gemini panel |
| Visual `Space as/ac/ao/ag` | 將選取內容傳給 Claude/Codex/OpenCode/Gemini |

四個 Agent 都使用相同的右側互動 terminal panel。Claude 額外保留 IDE protocol、diff 與檔案同步；其他 Agent 使用原生 Neovim terminal。也可以用 `:Agent claude|codex|opencode|gemini` 開關指定 panel。

Agent panel 開啟後會進入 terminal input mode，這是為了可以直接輸入 prompt。要使用 `Space a*` 或其他 Neovim 快捷鍵，先按 `Esc`；也可以按 `<C-\\><C-n>` 回到 Normal mode。

## 全域搜尋

Nvim 用 `fzf-lua`，Vim 用 `fzf.vim`，兩者共用 `fzf` 與 `rg`。Vim 在沒有 `rg` 的舊系統會退回內建 `:grep` + quickfix。

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl-P` / `Space ff` | 搜尋檔名 |
| `Space fg` | 全專案搜尋內容 |
| `Space fw` | 搜尋游標下的字（Nvim visual 模式搜選取內容） |
| `Space fb` | 已開啟的 buffer |
| `Space fr` | 最近開過的檔案 |

## Git 視覺提示

Git gutter signs 與 inline blame 由 `gitsigns.nvim` 提供（Vim 用 vim-gitgutter + blamer.nvim + fugitive，快捷鍵相同）；branch 顯示在 statusline。實際 Git 操作使用 shell 與既有 script。

| 快捷鍵 | 功能 |
| --- | --- |
| `Space gb` | 顯示目前這行的完整 blame（只限 Nvim） |
| `Space gB` | 整份檔案的 blame panel |
| `Space gp` | 預覽目前 hunk |
| `Space gt` | 開關行尾的 inline blame |
| `]h` / `[h` | 下一個 / 上一個 hunk |
