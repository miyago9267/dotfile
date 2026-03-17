---
id: spec-powershell-windows-port
title: PowerShell Windows 版 Dotfile
status: in-progress
created: 2026-03-18
updated: 2026-03-18
author: Miyago
approved_by:
tags: [powershell, windows, cross-platform, dotfiles]
priority: medium
---

# PowerShell Windows 版 Dotfile

## Background

現有 dotfile 以 macOS/Linux 為主，使用 Zsh + Bash。希望新增 PowerShell 版本，讓 Windows
環境也能共用部分配置，達到約 60-70% 的功能覆蓋。

## Requirements

1. 建立 `powershell/` 目錄，提供 Windows 可用的 dotfile 子集
2. 模組化架構（對應 `.zshrc.d/`），每個工具一個 `.ps1` 載入腳本
3. 互動式安裝腳本，使用 winget/scoop 作為套件管理器
4. alias 和常用 function 對應現有 `alias.sh`
5. Neovim 配置直接共用（init.lua 跨平台）
6. 提示字元使用 oh-my-posh 替代 Powerlevel10k
7. PSReadLine 配置替代 zsh 的自動補全和歷史搜尋插件
8. setup 腳本支援 symlink 或複製到 Windows 標準路徑

## Non-Goals

- 不移植 Tmux（Windows 無原生對等方案，僅文件提示 Windows Terminal 替代配置）
- 不移植 Zplug（由 PSReadLine + oh-my-posh + 獨立模組替代）
- 不追求 100% 功能對等，優先保留日常開發體驗的核心部分
- 不處理 WSL（WSL 可直接用 Zsh 版）

## Architecture / Plan

### 目錄結構

```text
powershell/
  profile.ps1                # 主 profile（入口，對應 .zshrc）
  profile.d/                 # 模組化載入（對應 .zshrc.d/）
    00_path_helpers.ps1      # PATH 工具函式
    aliases.ps1              # 別名與常用 function
    prompt.ps1               # oh-my-posh 提示字元
    readline.ps1             # PSReadLine 配置
    node.ps1                 # Node.js (nvm-windows / fnm)
    python.ps1               # Python (pyenv-win)
    go.ps1                   # Go
    rust.ps1                 # Rust (rustup)
    bun.ps1                  # Bun
    pnpm.ps1                 # pnpm
  setup.ps1                  # 互動式安裝入口
  setup.d/                   # 模組化安裝腳本
    install_scoop.ps1        # Scoop 套件管理器
    install_neovim.ps1       # Neovim
    install_node.ps1         # Node.js (fnm)
    install_python.ps1       # Python
    install_go.ps1           # Go
    install_rust.ps1         # Rust
    install_bun.ps1          # Bun
    install_fonts.ps1        # Nerd Fonts
    install_ohmyposh.ps1     # oh-my-posh
    setup_dotfiles.ps1       # Symlink/複製配置到標準路徑
    setup_neovim.ps1         # Neovim 配置 symlink
  README.md                  # Windows 版使用說明
```

### Decisions

- **Decision:** 套件管理器以 scoop 為主，winget 為輔。
  - **Reason:** scoop 的 CLI 體驗更接近 Homebrew，安裝路徑可控，適合開發者工具管理。winget 用於需要 MSI 安裝的軟體。
  - **By:** Miyago (2026-03-18)

- **Decision:** Node.js 版本管理使用 fnm 而非 nvm-windows。
  - **Reason:** fnm 是 Rust 寫的，速度快，跨平台，且 PowerShell 整合更好。
  - **By:** Miyago (2026-03-18)

- **Decision:** Neovim 配置不複製，直接 symlink 到現有 `nvim/` 目錄。
  - **Reason:** 避免維護兩份配置，init.lua 本身跨平台。Windows Neovim 配置路徑為 `~/AppData/Local/nvim/`。
  - **By:** Miyago (2026-03-18)

- **Decision:** profile.ps1 採用條件載入，缺少的工具自動跳過不報錯。
  - **Reason:** Windows 環境差異大，使用者不一定安裝全部工具。對應 .zshrc.d/ 各檔案的 `command -v` 檢查模式。
  - **By:** Miyago (2026-03-18)

- **Decision:** 提示字元用 oh-my-posh，主題盡量貼近現有 p10k 風格。
  - **Reason:** oh-my-posh 是 p10k 作者推薦的跨平台替代方案，支援相同的 Nerd Font 圖示。
  - **By:** Miyago (2026-03-18)

### 元件對應表

| Zsh/Bash 版 | PowerShell 版 | 備註 |
|-------------|---------------|------|
| `.zshrc` | `profile.ps1` | 入口 |
| `.zshrc.d/*.zsh` | `profile.d/*.ps1` | 模組化載入 |
| `alias.sh` | `profile.d/aliases.ps1` | Set-Alias + function |
| `00_path_helpers.zsh` | `profile.d/00_path_helpers.ps1` | Add-PathEntry |
| Powerlevel10k | oh-my-posh | 提示字元 |
| zsh-autosuggestions | PSReadLine PredictionSource | 自動補全 |
| zsh-history-substring-search | PSReadLine HistorySearchBackward | 歷史搜尋 |
| fast-syntax-highlighting | PSReadLine syntax coloring | 語法高亮 |
| `setup.sh` | `setup.ps1` | 互動式安裝 |
| `script/installations/*` | `setup.d/*` | 模組化安裝 |
| Homebrew/apt | scoop/winget | 套件管理 |
| nvm | fnm | Node 版本管理 |
| pyenv | pyenv-win | Python 版本管理 |
| Tmux | (不移植) | 建議用 Windows Terminal |

## Risks

- **Windows 環境碎片化：** PowerShell 版本（5.1 vs 7+）、執行策略（ExecutionPolicy）、
  路徑格式（反斜線）等差異需要處理。
  - **Mitigation:** 要求 PowerShell 7+（pwsh），在 profile.ps1 開頭檢查版本。
- **Symlink 權限：** Windows 預設需要管理員權限才能建立 symlink。
  - **Mitigation:** setup 腳本提供 symlink 和 copy 兩種模式，自動偵測權限。
- **Neovim 插件相容性：** 部分插件可能在 Windows 有路徑或編譯問題。
  - **Mitigation:** Phase 3 再處理，已知問題記錄在 README.md。

## Notes

- Windows Terminal 設定（profiles、keybindings）可作為未來 Phase 延伸
- WSL 使用者直接用 Zsh 版，不在此 spec 範圍內
- Claude Code 配置路徑在 Windows 為 `%APPDATA%\claude\`，可在 Phase 2 處理
