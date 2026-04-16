# Neovim 快捷鍵速查表

> 基於 `init.lua`，以 VSCode 習慣為主軸。
> Mac 使用 Cmd，Linux/Windows 使用 Ctrl。下表以 Ctrl 為主，Cmd 同理。

## 基本編輯

| 快捷鍵 | 功能 | 模式 |
|---|---|---|
| `Ctrl+C` | 複製 | visual |
| `Ctrl+X` | 剪下 | visual |
| `Ctrl+V` | 貼上 | normal / insert |
| `Ctrl+Z` | 復原 | normal / insert |
| `Ctrl+Shift+Z` / `Ctrl+Y` | 重做 | normal / insert |
| `Ctrl+A` | 全選 | normal |
| `Ctrl+S` | 存檔 | all |
| `Ctrl+/` | 切換註解 | normal / visual / insert |

## 行操作

| 快捷鍵 | 功能 | 模式 |
|---|---|---|
| `Alt+Up/Down` | 移動整行 | normal / insert / visual |
| `Alt+Shift+Up/Down` | 複製整行 | normal / insert / visual |
| `Ctrl+Shift+K` | 刪除整行 | normal / insert |
| `Tab` / `Shift+Tab` | 縮排 / 反縮排 | visual |

## 搜尋與取代

| 快捷鍵 | 功能 | 備註 |
|---|---|---|
| `Ctrl+F` | 檔案內搜尋 | vsearch panel |
| `Ctrl+P` | 找檔案 | Telescope find_files |
| `Ctrl+Shift+F` | 全專案搜尋 | Telescope live_grep |
| `Ctrl+Shift+H` | 全專案取代 | Grug-far |
| `Ctrl+G` | 跳到行號 | 輸入行號後 Enter |

## 側邊欄與面板

| 快捷鍵 | 功能 | 備註 |
|---|---|---|
| `Ctrl+E` / `Cmd+B` | 檔案樹開關 | NvimTree (Ctrl+B 被 tmux 佔) |
| `Ctrl+Shift+P` | 指令面板 | Telescope commands |
| `Ctrl+Shift+I` | AI agent 開關 | Claude Code |
| `Cmd+J` | 終端機開關 | ToggleTerm |

## Buffer / 分頁 (tmux 風格: Space b = prefix)

> 滑鼠：左鍵點擊切換分頁，右鍵/中鍵關閉分頁。

| 快捷鍵 | 功能 | tmux 對應 |
|---|---|---|
| `Space bn` | 下一個分頁 | `prefix + n` |
| `Space bp` | 上一個分頁 | `prefix + p` |
| `Space bc` | 新分頁 | `prefix + c` |
| `Space bx` | 關閉分頁 | `prefix + x` |
| `Space b` + 方向鍵 | 切換分頁 | Right/Down=下一個, Left/Up=上一個 |
| `Space b.` | 分頁右移 | 不按 Shift 的 `>` |
| `Space b,` | 分頁左移 | 不按 Shift 的 `<` |
| `Space b\|` | 垂直分割 | `prefix + %` |
| `Space b-` | 水平分割 | `prefix + "` |
| 滑鼠左鍵點擊分頁 | 跳到該分頁 | -- |
| `Ctrl+W` | 關閉分頁 | VSCode 習慣 |

## 折疊

| 快捷鍵 | 功能 |
|---|---|
| `Ctrl+Shift+[` | 折疊 |
| `Ctrl+Shift+]` | 展開 |

## 視窗

| 快捷鍵 | 功能 | 備註 |
|---|---|---|
| `Ctrl+H/J/K/L` | 切換視窗 | 含 tmux pane |
| `Ctrl+Left/Right` | 調整寬度 | 每次 +-3 |
| `Ctrl+Up/Down` | 調整高度 | 每次 +-3 |

## LSP (程式碼智慧)

| 快捷鍵 | 功能 |
|---|---|
| `gd` / `F12` | 跳到定義 |
| `gr` | 查看引用 |
| `gi` | 跳到實作 |
| `K` | 顯示文件 (hover) |
| `F2` | 重新命名符號 |
| `Space ca` | Code Action |

## 跳轉 (Flash)

| 快捷鍵 | 功能 | 模式 |
|---|---|---|
| `s` | Flash jump | normal / visual / operator |
| `S` | Flash treesitter 選取 | normal / visual / operator |
| `/` / `?` | 搜尋 + label 跳轉 | 增強原生搜尋 |

## Git

| 快捷鍵 | 功能 |
|---|---|
| `Space ng` | 開啟 Neogit |
| `Space gd` | Diff view |
| `Space gh` | 目前檔案 git 歷史 |
| `Space gH` | 整個 repo git 歷史 |
| `Space gc` | 關閉 Diff view |

## AI (Claude Code)

| 快捷鍵 | 功能 | 模式 |
|---|---|---|
| `Space cc` | Claude Code 開關 | normal |
| `Space cs` | 送出選取給 Claude | visual |
| `Ctrl+Shift+I` | Claude Code 開關 | normal |

## Telescope 搜尋 (Space 前綴)

| 快捷鍵 | 功能 |
|---|---|
| `Space sb` | 搜尋 buffer |
| `Space sh` | 搜尋 help tags |
| `Space sw` | 搜尋游標下的字 |

## 自動補全 (Insert mode)

| 快捷鍵 | 功能 |
|---|---|
| `Tab` | 接受 Copilot 建議 / 選下一項 |
| `Shift+Tab` | 選上一項 |
| `Ctrl+Space` | 手動觸發補全 |
| `Enter` | 確認選取 |
| `Ctrl+E` | 取消補全 |
| `Alt+]` / `Alt+[` | 下/上一個 Copilot 建議 |

## 移動 (Miyago 自訂)

| 快捷鍵 | 功能 | 備註 |
|---|---|---|
| `j` / `k` | 上 / 下 | 與 vim 預設相反 |
| `Alt+I/K` | 上 / 下 | 平板友善 |
| `Alt+J/L` | 左 / 右 | 平板友善 |

## 其他

| 快捷鍵 | 功能 |
|---|---|
| `:W` | sudo 存檔 (忘記 sudo 時) |
| `Esc` (terminal mode) | 跳回 normal mode |
