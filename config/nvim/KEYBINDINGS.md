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
| `Ctrl-w` | Vim window prefix |
| `Space wv` / `Space ws` | Vertical／horizontal split |
| `Ctrl-h/j/k/l` | 切換 Neovim 或 tmux pane |

## Terminal / Agent

| 快捷鍵 | 功能 |
| --- | --- |
| `Space tt` | 開關 terminal |
| `Ctrl-,` | 開關 terminal（舊習慣相容入口） |
| `Space ts` | 開啟 shell terminal |
| `:Shell <command>` | 在 terminal split 執行 shell command |
| `Space aa` | 開關 Claude Code |
| `Space as` | 將 visual selection 傳給 Claude Code |

## Git 視覺提示

Git gutter signs 由 `gitsigns.nvim` 提供；實際 Git 操作使用 shell 與既有 script。
