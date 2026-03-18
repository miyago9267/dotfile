# Miyago Dotfile - PowerShell (Windows)

macOS/Linux 版 dotfile 的 Windows 移植版，使用 PowerShell 7+ 。

## 需求

- **PowerShell 7+** (pwsh) -- [安裝方式](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
- **Windows Terminal** -- 建議使用，支援 Nerd Font 和 256 色

## 快速開始

```powershell
# 1. Clone dotfile
git clone https://github.com/user/dotfile.git ~/dotfile

# 2. 建立 symlinks（以管理員身分執行）
cd ~/dotfile
pwsh install.ps1

# 3. 安裝軟體（互動式選單）
pwsh script/windows/setup.ps1

# 4. 重啟終端
```

全部安裝（跳過選單）：

```powershell
pwsh script/windows/setup.ps1 --all
```

## 目錄結構

```text
install.ps1                        # Windows symlink installer（根目錄）
script/windows/
  profile.ps1                      # 主 profile（對應 .zshrc）
  profile.d/                       # 模組化載入（對應 .zshrc.d/）
    00_path_helpers.ps1            #   PATH 工具函式
    01_aliases.ps1                 #   別名與常用 function
    02_readline.ps1                #   PSReadLine 配置
    03_prompt.ps1                  #   oh-my-posh 提示字元
    04_modules.ps1                 #   額外模組（posh-git, DirColors, Terminal-Icons）
    10_node.ps1                    #   Node.js (fnm)
    11_python.ps1                  #   Python (pyenv-win)
    12_go.ps1                      #   Go
    13_rust.ps1                    #   Rust
    14_bun.ps1                     #   Bun
    15_pnpm.ps1                    #   pnpm
  setup.ps1                        # 互動式軟體安裝入口
  setup.d/                         # 模組化安裝腳本
vscode/                            # VS Code 設定
windows-terminal/                  # Windows Terminal 設定
wsl/                               # WSL 配置
ssh/                               # SSH config
git/                               # Git config
```

## 元件對應

| macOS/Linux | Windows (PowerShell) | 備註 |
|-------------|---------------------|------|
| Zsh + Zplug | PowerShell 7 + PSReadLine | shell |
| Powerlevel10k | oh-my-posh | 提示字元 |
| zsh-autosuggestions | PSReadLine PredictionSource | 自動補全 |
| zsh-history-substring-search | PSReadLine HistorySearchBackward | 歷史搜尋 |
| fast-syntax-highlighting | PSReadLine syntax coloring | 語法高亮 |
| Homebrew / apt | scoop / winget | 套件管理 |
| nvm | fnm | Node 版本管理 |
| pyenv | pyenv-win | Python 版本管理 |
| Tmux | (不移植) | 用 Windows Terminal 替代 |

## Neovim

Neovim 配置 (`nvim/init.lua`) 跨平台共用，安裝腳本會自動 symlink 到
`%LOCALAPPDATA%\nvim\`。所有插件（Lazy.nvim、LSP、Telescope、Treesitter）都支援 Windows。

## Windows Terminal

`install.ps1` 會自動將 `windows-terminal/settings.json` symlink 到 Windows Terminal
的 LocalState 目錄。手動調整可以直接編輯 `windows-terminal/settings.json`。

## Symlink 與開發者模式

`install.ps1` 優先使用 symlink 連結配置。Windows 建立 symlink 需要以下條件之一：

- 以管理員身分執行
- 開啟 Windows「開發人員模式」（Settings > Update & Security > For developers）

`setup.ps1`（軟體安裝）在無法 symlink 時會自動改用複製模式。

## 不移植的部分

- **Tmux** -- Windows 沒有對等方案，建議使用 Windows Terminal 的分割窗格
- **Zplug** -- 由 PSReadLine + oh-my-posh 替代
- **WSL** -- WSL 環境直接使用 Zsh 版
