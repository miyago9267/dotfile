---
spec: powershell-windows-port
batch: 1
created: 2026-03-24
---

# Tests: PowerShell Windows 版 Dotfile

> Spec: `docs/specs/powershell-windows-port/SPEC.md`

## 驗收條件 (EARS)

### Profile 載入

- [x] When PowerShell 7+ 啟動 then profile.ps1 正常載入，無錯誤輸出
- [x] When PowerShell 5.1 啟動 then profile.ps1 因 `#requires -Version 7.0` 拒絕載入並提示版本需求
- [x] When `profile.d/` 目錄存在 then 所有 `.ps1` 檔案依檔名排序載入
- [x] When `profile.d/` 中參照的工具未安裝 then 該模組靜默跳過，不影響其他模組
- [x] When `~/.env` 或 dotfile 根目錄 `.env` 存在 then 環境變數正確載入到 Process scope

### 模組化配置

- [x] When `00_path_helpers.ps1` 載入 then `Add-PathEntry` 等 helper function 可用
- [x] When `01_aliases.ps1` 載入 then 常用別名（ll、la、gs、gd 等）可用
- [x] When PSReadLine 可用 then `02_readline.ps1` 配置自動補全、歷史搜尋、語法高亮
- [x] When oh-my-posh 已安裝 then `03_prompt.ps1` 初始化提示字元主題
- [x] When oh-my-posh 未安裝 then `03_prompt.ps1` 靜默跳過
- [x] When fnm 已安裝 then `10_node.ps1` 初始化 Node.js 版本管理環境
- [x] When pyenv-win 已安裝 then `11_python.ps1` 初始化 Python 版本管理環境
- [x] When Go 已安裝 then `12_go.ps1` 設定 GOPATH 等環境變數
- [x] When Rust 已安裝 then `13_rust.ps1` 載入 cargo 環境
- [x] When Bun 已安裝 then `14_bun.ps1` 設定 Bun PATH
- [x] When pnpm 已安裝 then `15_pnpm.ps1` 設定 pnpm PATH

### 安裝腳本

- [x] When `setup.ps1` 執行 then 顯示互動式安裝選單
- [x] When `setup.ps1 --all` 執行 then 跳過選單，執行全部安裝
- [x] When `setup.bat` 雙擊執行 then 自動偵測 pwsh 並啟動 setup.ps1
- [x] When scoop 未安裝 then `install_scoop.ps1` 正確安裝 scoop
- [x] When 各工具安裝腳本執行 then 透過 scoop/winget 正確安裝對應工具

### Symlink 與配置部署

- [x] When 使用者有 symlink 權限 then `setup_dotfiles.ps1` 使用 symlink 連結配置
- [x] When 使用者無 symlink 權限 then `setup_dotfiles.ps1` 自動降級為複製模式
- [x] When `setup_neovim.ps1` 執行 then Neovim 配置 symlink 到 `%LOCALAPPDATA%\nvim\`
- [x] When Neovim 配置為 symlink then 修改 dotfile 中的 `nvim/init.lua` 立即生效

### Non-Goals 確認

- [x] Tmux 相關功能不存在於 PowerShell 版
- [x] WSL 配置不在此 spec 處理範圍
- [x] Zplug 功能由 PSReadLine + oh-my-posh + 獨立模組替代

## 測試案例

### 正常路徑

| # | 案例 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | 全新 Windows 環境執行 `setup.ps1 --all` | scoop 安裝成功，所有工具安裝完成，profile symlink 建立 | [x] |
| 2 | 啟動 pwsh 載入 profile.ps1 | 所有已安裝工具的模組正常初始化，prompt 顯示正確 | [x] |
| 3 | 執行 `ll`、`la`、`gs` 等別名 | 對應指令正確執行 | [x] |
| 4 | PSReadLine 上下鍵歷史搜尋 | 依輸入前綴過濾歷史記錄 | [x] |
| 5 | fnm 切換 Node.js 版本 | `node --version` 顯示正確版本 | [x] |
| 6 | Neovim 啟動 | 載入共用的 init.lua 配置，插件正常運作 | [x] |

### 邊界案例

| # | 案例 | 預期結果 | 狀態 |
|---|------|----------|------|
| 7 | 僅安裝部分工具（如只有 Node.js） | 未安裝工具的 profile.d 模組靜默跳過 | [x] |
| 8 | `.env` 檔案不存在 | profile.ps1 正常載入，不報錯 | [x] |
| 9 | `.env` 檔案含註解行和空行 | 僅解析有效的 KEY=VALUE 行 | [x] |
| 10 | profile.d/ 目錄為空 | profile.ps1 正常載入，不報錯 | [x] |
| 11 | 重複執行 setup.ps1 | 已安裝的工具跳過，idempotent | [x] |

### 錯誤處理

| # | 案例 | 預期結果 | 狀態 |
|---|------|----------|------|
| 12 | PowerShell 5.1 執行 profile.ps1 | `#requires` 指令阻擋並顯示版本錯誤 | [x] |
| 13 | 無管理員權限且未開啟開發者模式建立 symlink | setup_dotfiles.ps1 降級為 copy 模式 | [x] |
| 14 | scoop 安裝失敗（網路問題） | install_scoop.ps1 顯示錯誤訊息，不影響後續腳本 | [x] |
| 15 | Neovim 配置目標路徑已存在非 symlink 檔案 | setup_neovim.ps1 提示使用者處理衝突 | [x] |
