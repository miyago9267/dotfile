---
spec: windows-wsl-runtime-governance
batch: 1
created: 2026-08-09
---

# Tests: Windows 與 WSL Runtime 治理

> Spec: `docs/specs/windows-wsl-runtime-governance/SPEC.md`

## 驗收條件 (EARS)

### R1-R2：Shell 與 runtime 邊界

- **When**: 從 PowerShell、cmd、Git CLI 與 WSL 啟動工具。
- **Shall**: Windows 與 Ubuntu 24.04 各自使用自己的 shell 與 PATH。
- **驗證方式**: 記錄 `$PSVersionTable`、`wsl -l -v`、`$env:PATH` 與 WSL `$PATH`。
- **狀態**: [ ] 待重開機後驗證

### R3-R6：Command precedence

- **When**: 執行 `python`、`node`、`npm`、`go`。
- **Shall**: 每個 command 只解析到一個已選定的版本管理來源。
- **驗證方式**: Windows `Get-Command`/`where.exe`；WSL `command -v`/`type -a`。
- **狀態**: [ ] Windows 已驗證；WSL 待 health gate

### R7：VS Code

- **When**: Windows host 與 VS Code Remote - WSL 分別開啟專案。
- **Shall**: interpreter、Node、Go 與 Docker context 分別指向對應 runtime。
- **驗證方式**: 在兩個 VS Code context 執行版本與 project smoke checks。
- **狀態**: [ ] 未驗證

### R8：WSL health gate

- **When**: 執行 `wsl.exe -d Ubuntu-24.04 --exec /bin/uname -a`。
- **Shall**: 5 秒內成功返回；否則停止 WSL cleanup。
- **驗證方式**: PowerShell stopwatch，連續兩次僅在 probe 內容改變時重試。
- **狀態**: [ ] 未驗證

### R9-R11：安全與可重現性

- **When**: 執行 setup 或清理步驟。
- **Shall**: 未提交變更保留，移除前有 inventory 與可恢復證據。
- **驗證方式**: `git diff`、backup manifest、移除後 command resolution audit。
- **狀態**: [ ] 未驗證

## 測試案例

### 正常路徑

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | Windows `python --version` | 解析官方 Python 3.14.6；不解析 Store alias | [x] |
| 2 | Windows `node --version` | 解析 nvm-windows Node 26.x | [x] |
| 3 | WSL `python3/node/go` | 解析 WSL 內部 runtime | [ ] |
| 4 | Windows VS Code project smoke | 使用 Windows runtime | [ ] |
| 5 | WSL Remote project smoke | 使用 Ubuntu runtime | [ ] |

### 邊界案例

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | PowerShell non-interactive profile | 不輸出 PSReadLine VT 錯誤 | [ ] |
| 2 | WSL direct exec | 5 秒內返回，或明確停止後續清理 | [ ] |
| 3 | Windows PATH 含 `/mnt` 或 WSL tool | 不污染 Windows command resolution | [ ] |
| 4 | dotfile 有未提交變更 | 不被 setup 覆寫 | [ ] |

### 錯誤處理

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | Duplicate Node source | 報告來源並停止移除，直到明確驗證 | [ ] |
| 2 | Docker daemon 未啟動 | 區分 client 可用與 daemon 未驗證 | [ ] |
| 3 | 缺少 WSL runtime | 不假裝完成 WSL setup | [ ] |

### Reboot recovery

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | 重開後 `wsl.exe -l -v` | 只列出 Ubuntu-24.04 | [ ] |
| 2 | Ubuntu-24.04 direct exec | `/bin/uname -a` 在 5 秒內成功 | [ ] |
| 3 | WSL shell baseline | `/bin/sh`、`/etc/wsl.conf`、Linux PATH 可讀 | [ ] |
