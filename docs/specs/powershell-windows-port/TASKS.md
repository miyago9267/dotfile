---
spec: powershell-windows-port
batch: 1
created: 2026-03-24
---

# Tasks: PowerShell Windows 版 Dotfile

> Spec: `docs/specs/powershell-windows-port/SPEC.md`
> Batch: 1

## 前置條件

- [x] 確認目錄結構設計（`script/windows/` 為根）
- [x] 確認套件管理器策略（scoop 為主、winget 為輔）
- [x] 確認 Node.js 版本管理使用 fnm

## Phase 1: 基礎骨架

- [x] 建立 `script/windows/profile.ps1` 主入口（對應 .zshrc）
- [x] 要求 PowerShell 7+（`#requires -Version 7.0`）
- [x] 設定基本環境變數（EDITOR、LANG、LANGUAGE）
- [x] 實作 `.env` 檔案載入邏輯
- [x] 實作 `profile.d/*.ps1` 模組化載入機制（依檔名排序）
- [x] 建立 `profile.d/00_path_helpers.ps1` -- PATH 工具函式（Add-PathEntry 等）
- [x] 建立 `profile.d/01_aliases.ps1` -- 別名與常用 function（對應 alias.sh）
- [x] 建立 `profile.d/02_readline.ps1` -- PSReadLine 配置（自動補全、歷史搜尋、語法高亮）
- [x] 建立 `profile.d/03_prompt.ps1` -- oh-my-posh 提示字元配置
- [x] 建立 `profile.d/04_modules.ps1` -- 額外模組載入（posh-git、DirColors、Terminal-Icons）
- [x] 建立 `profile.d/10_node.ps1` -- Node.js (fnm) 環境初始化
- [x] 建立 `profile.d/11_python.ps1` -- Python (pyenv-win) 環境初始化
- [x] 建立 `profile.d/12_go.ps1` -- Go 環境初始化
- [x] 建立 `profile.d/13_rust.ps1` -- Rust (rustup) 環境初始化
- [x] 建立 `profile.d/14_bun.ps1` -- Bun 環境初始化
- [x] 建立 `profile.d/15_pnpm.ps1` -- pnpm 環境初始化
- [x] 所有 profile.d 模組實作條件載入（工具不存在時靜默跳過）
- [x] profile.ps1 結尾清理 helper functions

## Phase 2: 安裝腳本

- [x] 建立 `setup.d/install_scoop.ps1` -- Scoop 套件管理器安裝
- [x] 建立 `setup.d/install_neovim.ps1` -- Neovim 安裝
- [x] 建立 `setup.d/install_node.ps1` -- Node.js (fnm) 安裝
- [x] 建立 `setup.d/install_python.ps1` -- Python (pyenv-win) 安裝
- [x] 建立 `setup.d/install_go.ps1` -- Go 安裝
- [x] 建立 `setup.d/install_rust.ps1` -- Rust (rustup) 安裝
- [x] 建立 `setup.d/install_bun.ps1` -- Bun 安裝
- [x] 建立 `setup.d/install_fonts.ps1` -- Nerd Fonts 安裝
- [x] 建立 `setup.d/install_ohmyposh.ps1` -- oh-my-posh 安裝
- [x] 建立 `setup.d/install_gh.ps1` -- GitHub CLI 安裝
- [x] 建立 `setup.d/install_kubectl.ps1` -- kubectl 安裝
- [x] 建立 `setup.d/install_gcloud.ps1` -- Google Cloud SDK 安裝
- [x] 建立 `setup.d/install_argocd.ps1` -- ArgoCD CLI 安裝
- [x] 建立 `setup.d/setup_dotfiles.ps1` -- Symlink/複製配置到 Windows 標準路徑
- [x] 建立 `setup.d/setup_neovim.ps1` -- Neovim 配置 symlink 到 `%LOCALAPPDATA%\nvim\`
- [x] 建立 `setup.d/setup_claude.ps1` -- Claude Code 配置安裝
- [x] setup_dotfiles.ps1 支援 symlink 與 copy 雙模式（自動偵測權限）

## Phase 3: 入口與文件

- [x] 建立根目錄 `setup.ps1` 互動式安裝入口
- [x] 建立根目錄 `setup.bat` 薄 wrapper（雙擊用，自動偵測 pwsh）
- [x] 建立 `script/windows/README.md` 使用說明

## 驗證

- [x] 所有 Phase 1-3 步驟完成
- [x] 目錄結構與 SPEC.md 規劃一致
- [x] 文件已更新
