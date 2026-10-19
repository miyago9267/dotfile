# Neovim 快捷鍵

核心原則：Vim 負責編輯；plugin 只提供視覺效果、file tree、tmux 導航與 Agent。

Vim 與 Neovim 共用同一份 VSCode 風格（Windows／Linux、Ctrl 為主）快捷鍵表：`config/vim/keymaps.vim`，
由 `base.vim` 載入。每個 key 都帶說明（`MiyagoMap()`）；Vim 直接套用，Neovim 在 `lua/config/keymaps.lua` 套用，所以 which-key 與 palette 看得到說明。
`Space p` 或 `Space ?` 搜尋所有快捷鍵（Nvim 走 `fzf-lua keymaps`，Vim 走 fzf 列出同一份表）。
下列表格中，Buffer／Tab／Window／編輯類的 key 兩邊相同；標示「Nvim」的才是 Neovim 專屬。

## 編輯

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl-s` | 儲存 |
| `Ctrl-z` / `Ctrl-y` | 復原／重做 |
| `Ctrl-c` / `Ctrl-x`（visual） | 複製／剪下到系統剪貼簿 |
| `Ctrl-v` | 從系統剪貼簿貼上（normal／insert／cmdline；visual 會取代選取內容） |
| `Ctrl-q` | Visual block（原本 Vim 的 `Ctrl-v`） |
| `Shift+方向鍵` | 開始 Visual 選取（`keymodel=startsel,stopsel`） |
| Visual `Tab` / `Shift-Tab` | 縮排／取消縮排並保留選取 |
| Visual `BS` / `Del` | 刪除選取（不進 register） |
| `Ctrl-f` | 目前檔案搜尋 |
| 搜尋輸入中 `↑` / `↓` | 上一個／下一個符合處（還在輸入，Enter 確認；`←` `→` 保留給編輯搜尋文字） |
| `Ctrl-g` | 跳到行號（進 `:` 命令列） |
| `Space rr` | 取代游標下的字（`:%s/\<word\>//g`） |
| `j` / `k` | 依 Miyago 習慣交換上下移動 |
| `Ctrl-/` | 切換註解（normal／visual／insert；同內建 `gc`） |
| `Alt-↑` / `Alt-↓` | 整行或選取範圍上下移動 |
| `j`／`↑` 在第一行、`k`／`↓` 在最後一行 | 像 VSCode 一樣跳到行首／行尾（insert mode 也適用） |
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
| `Space .` / `Space F` | Code action／format（同 VSCode Ctrl-. ／ Shift-Alt-F） |
| `[d` / `]d` | 上一個／下一個 diagnostic（Vim 的 ALE 錯誤也是同一組） |

## Problems（Trouble）

| 快捷鍵 | 功能 |
| --- | --- |
| `Space dd` / `Space db` | 整個 project／目前 buffer 的 Problems 面板 |
| `Space ds` | Symbols outline |
| `Space dr` | LSP references 面板 |
| `Space dl` | 顯示游標所在行的 diagnostic |

Format 用 `Space F` 手動觸發（conform.nvim）：有對應 formatter（stylua、ruff、prettier、gofmt、rustfmt 等）就用，沒有就退回 LSP format。存檔自動 format 預設關閉，`Space uF` 可暫時打開。

目前涵蓋 C/C++、Lua、Go、Rust、Python、TypeScript、Vue、HTML、CSS、YAML、JSON、TOML、XML、Markdown、Bash、Terraform 與 Dockerfile。
每個 server 都會先檢查 executable；沒有安裝時只失去該語言的智慧功能，不影響 Neovim 啟動。

## 顯示開關

| 快捷鍵 | 功能 |
| --- | --- |
| `Space un` | 開關行數與 relative number |
| `Ctrl-e` / `Space uf` | 開關 file tree |
| `Space ub` | 開關透明背景 |
| `Space uc` | 開關 cursorline |
| `Space uh` | 開關 inlay hints |
| `Space ut` | 開關 sticky scroll（捲動時把所在 function／class 標頭釘在頂端） |
| `Space uF` | 開關存檔自動 format（預設關） |

F1 / F3 / F4 也分別對應透明背景、行數、file tree；F12 對應原生 tag jump。
它們只是有實體 F-key 或 SSH/WSL 環境時的相容入口，MacBook 以 `Space` 入口為準。

## Buffer / Window

| 快捷鍵 | 功能 |
| --- | --- |
| `Space bb` | 列出 buffer |
| `Ctrl-w` | 關閉目前 buffer（window 操作改用 `Space w*`，見下） |
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
| `Space ←/→/↑/↓`（也可用 h/j/k/l） | 切換 window 或 tmux pane |
| `Space Shift+方向鍵`（也可用 H/J/K/L） | 調整 window 大小 |
| `Space =` | 平均所有 window |
| `Space z` | 最大化／還原目前 window |
| `Ctrl-\` | 回到上一個 window |
| `Space wv` / `Space ws` | 舊的 split aliases |
| `Space w` + 方向鍵（也可用 `wh/wj/wk/wl`） | 往左／下／上／右開新 split（VSCode Split Editor） |
| `Space w` + `Shift+方向鍵`（也可用 `wH/wJ/wK/wL`） | 把目前 window 搬到該方向最邊邊 |
| `Space wx` | 和下一個 window 互換位置 |
| `Ctrl-h/j/k/l` | 切換 window，到邊界就跨進 tmux pane（Vim 與 Neovim 都走 `MiyagoNavigate`，沒有 tmux-navigator 時退回 `wincmd`）；這組沒有方向鍵版本，因為 `Ctrl-←/→` 已用於切換 buffer |

三層方向鍵對照（方向鍵是主要入口，hjkl 保留為別名）：

| 動作 | Ghostty | tmux | Vim / Nvim |
| --- | --- | --- | --- |
| 切換 pane | Cmd+Alt+方向鍵 | prefix 方向鍵 | Space 方向鍵 |
| 調整大小 | Cmd+Ctrl+方向鍵，或 Cmd-r 後方向鍵 | prefix Alt+方向鍵（一次 5）／prefix Ctrl+方向鍵 | Space Shift+方向鍵 |
| 往該方向分割 | Cmd-- / Cmd-\| | prefix - / \| | Space w 方向鍵 |
| 把視窗搬到最邊 | — | — | Space w Shift+方向鍵 |
| 捲動模式 | Cmd-[ 後 ↑↓ PgUp PgDn | prefix [ 後方向鍵 | — |

## Tab

| 快捷鍵 | 功能 |
| --- | --- |
| `Space c` | 開新 tab |
| `Space [` / `Space ]` | 上一個／下一個 tab |
| `Space Tab` | 回到上一個 tab |
| `Space x` | 關閉目前 tab |
| `Space 1..9` | 跳到第 N 個 tab |

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

## 版面（固定區塊）

由 edgy.nvim 管理，開關任一區塊都不影響其他區塊的大小：左側 file tree（32 欄）、編輯器、右側 agent dock（畫面 30%）、編輯器下方的底部面板（高 12 行，不橫跨 tree 與 agent）。

- 右側 dock 同時只顯示一個 agent；開另一個會取代它，舊 agent 的程序保留，可再切回。
- 底部面板同時只顯示 terminal 或 Problems（Trouble）其中一個；terminal 重複叫回同一個 shell，`:Shell <command>` 另開新的。
- `Space z` 只在編輯器區內最大化目前分割，dock 大小不變；再按一次還原。
- 關掉最後一個編輯視窗時會留一個空的編輯視窗，dock 才不會佔滿畫面；在這個空視窗再 `:q` 會離開 Neovim。
- dock 視窗內按 `q` 關閉該視窗；Leaf 預覽（`Space mp`）仍是浮動視窗。

## Workspace（multi-root）

| 快捷鍵 | 功能 |
| --- | --- |
| `Space Wa` | 加入 folder：在 file tree 上是游標所在資料夾，否則是目前檔案的 git root；沒開 workspace 時會自動開一個未存檔的 untitled workspace（包含目前專案） |
| `Space WA` | 用 fzf 挑資料夾加入：預設是 zoxide 常用目錄，`Ctrl-f` 切成 `fd` 搜整個家目錄，`Tab` 可多選 |
| `Space Wr` / `Space Wl` | 移除 folder／列出 folder |
| `Space Ws` | 存檔：untitled 會問名稱；已存檔的 workspace 加減 folder 會自動寫回 |
| `Space Wo` / `Space Wn` / `Space Wc` | 開啟／新建（同名就直接開啟）／關閉（untitled 直接丟掉） |
| `Space yp` / `Space yr` | 複製絕對／相對路徑；visual 模式會帶 `:start-end` |

| 指令 | 功能 |
| --- | --- |
| `nvim foo.code-workspace` | 直接以 workspace 開啟（VSCode 同格式） |
| `:Workspace open [name]` | 開啟 workspace；不給名稱時用 fzf 選（`vim.ui.select` 已改走 fzf-lua） |
| `:Workspace new <name>` | 以目前檔案的 git root（或 cwd）建立新 workspace |
| `:Workspace add [dir]` / `:Workspace remove [name]` | 加入／移除 folder |
| `:Workspace save [name]` | 存檔到 `~/.local/share/nvim/archipelago/` |
| `:Workspace list` / `:Workspace close` | 列出 folder／關閉並回到原本的 cwd |
| `:CopyPath` / `:CopyRelativePath` | 複製真實絕對路徑／相對路徑；visual 或 `:2,5CopyPath` 會附加 `:2-5` |
| file tree 的 `gy` / `Y`、右鍵選單 | 同上兩種複製路徑 |

由 [archipelago.nvim](https://github.com/miyago9267/archipelago.nvim) 提供。workspace 檔存放在 `~/.local/share/nvim/archipelago/`。開啟後 cwd 會切到 hub（`~/.local/state/nvim/archipelago/<name>`，裡面只有 symlink），
file tree、搜尋和 agent 都能看到所有 folder；buffer 和複製出來的路徑一律是真實路徑。

## Markdown

| 快捷鍵 | 功能 |
| --- | --- |
| `Space mp` / `:Leaf` | 用 Leaf 在浮動視窗預覽目前的 Markdown（存檔後自動重新載入，`q` 關閉） |

## 全域搜尋

Nvim 用 `fzf-lua`，Vim 用 `fzf.vim`，兩者共用 `fzf` 與 `rg`。Vim 在沒有 `rg` 的舊系統會退回內建 `:grep` + quickfix。

| 快捷鍵 | 功能 |
| --- | --- |
| `Ctrl-p` / `Space ff` | 搜尋檔名 |
| `Space fg` | 全專案搜尋內容 |
| `Space fw` | 搜尋游標下的字（Nvim visual 模式搜選取內容） |
| `Space fb` | 已開啟的 buffer |
| `Space fr` | 最近開過的檔案 |
| `Space p` / `Space ?` | Command palette：搜尋所有有說明的快捷鍵，Enter 直接執行（Vim 只執行 normal mode 項目） |
| `Space :` | 列出所有指令（Nvim） |
| `Space fs` / `Space fS` | 目前檔案的 symbols／整個專案的 symbols（Nvim） |

## Git 視覺提示

Git gutter signs 與 inline blame 由 `gitsigns.nvim` 提供（Vim 用 vim-gitgutter + blamer.nvim + fugitive，快捷鍵相同）；branch 顯示在 statusline。實際 Git 操作使用 shell 與既有 script。

| 快捷鍵 | 功能 |
| --- | --- |
| `Space gb` | 顯示目前這行的完整 blame（只限 Nvim） |
| `Space gB` | 整份檔案的 blame panel |
| `Space gp` | 預覽目前 hunk |
| `Space gt` | 開關行尾的 inline blame |
| `]h` / `[h` | 下一個 / 上一個 hunk |

## 刻意不用的 key

- `Ctrl-a`、`Ctrl-b`：tmux 的 prefix2／prefix，不能映射；`Ctrl-a` 保留 Vim 原生的數字遞增。
- ``Ctrl-` ``、`Ctrl-Shift-*`、所有 `Cmd-*`：Ghostty 先吃掉，到不了編輯器，所以沒有 Cmd-f／Cmd-b 這類映射。
- 無 prefix 的 `Ctrl-h/j/k/l` 是 tmux 與編輯器共用的導航，不改作他用。
