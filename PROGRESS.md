# Progress

## Active: PowerShell Windows 版 Dotfile

> Spec: `docs/specs/powershell-windows-port/SPEC.md`

### Phase 1: 基礎骨架 -- Profile 與 Alias

核心 profile 載入機制和日常使用的 alias/function。

- [x] 建立 `powershell/` 目錄結構
- [x] `profile.ps1` -- 主入口，版本檢查，模組化載入 `profile.d/*.ps1`
- [x] `profile.d/00_path_helpers.ps1` -- `Add-PathEntry` 等 PATH 工具函式
- [x] `profile.d/01_aliases.ps1` -- 對應 `alias.sh` 的別名與 function
- [x] `profile.d/02_readline.ps1` -- PSReadLine 配置（歷史搜尋、自動補全、語法高亮）
- [x] `profile.d/03_prompt.ps1` -- oh-my-posh 提示字元（p10k 風格主題）

### Phase 2: 安裝腳本

互動式安裝入口和模組化安裝腳本，使用 scoop/winget。

- [x] `setup.ps1` -- 互動式安裝選單（對應 `setup.sh`）
- [x] `setup.d/install_scoop.ps1` -- 安裝 scoop 套件管理器
- [x] `setup.d/install_neovim.ps1` -- 安裝 Neovim + 依賴（ripgrep, fd, gcc）
- [x] `setup.d/install_node.ps1` -- 安裝 fnm + Node.js
- [x] `setup.d/install_python.ps1` -- 安裝 Python (uv + pyenv-win)
- [x] `setup.d/install_go.ps1` -- 安裝 Go
- [x] `setup.d/install_rust.ps1` -- 安裝 Rust (rustup)
- [x] `setup.d/install_bun.ps1` -- 安裝 Bun
- [x] `setup.d/install_fonts.ps1` -- 安裝 Nerd Fonts
- [x] `setup.d/install_ohmyposh.ps1` -- 安裝 oh-my-posh
- [x] `setup.d/setup_dotfiles.ps1` -- Symlink/複製 profile 到 `$PROFILE` 路徑
- [x] `setup.d/setup_neovim.ps1` -- Symlink nvim/ 到 `~/AppData/Local/nvim/`

### Phase 3: 語言環境模組

各語言 runtime 的 PATH 和環境初始化。

- [x] `profile.d/10_node.ps1` -- fnm 初始化
- [x] `profile.d/11_python.ps1` -- pyenv-win 或 Python PATH
- [x] `profile.d/12_go.ps1` -- Go 環境變數
- [x] `profile.d/13_rust.ps1` -- Rust/Cargo PATH
- [x] `profile.d/14_bun.ps1` -- Bun PATH
- [x] `profile.d/15_pnpm.ps1` -- pnpm PATH

### Phase 4: 文件與驗證

- [x] `powershell/README.md` -- Windows 版使用說明與安裝指南
- [x] 在主 `README.md` 加入 PowerShell/Windows 段落
- [ ] 驗證：在 Windows 環境測試 profile 載入、alias、安裝流程

---

## Completed

### Zsh PATH 規格統一

> Spec: `docs/specs/path-config-normalization/SPEC.md` | Status: completed

- [x] Phase 1: 建立 PATH helper 並統一 `.zshrc.d` PATH 寫法
- [x] Phase 2: 移除 `.zshrc` 內與 snippet 重複的載入
- [x] Phase 3: 驗證 zsh 語法與實際 PATH/command 載入結果
