---
spec: windows-wsl-runtime-governance
created: 2026-08-09
---

# Progress: Windows 與 WSL Runtime 治理

> Spec: `docs/specs/windows-wsl-runtime-governance/SPEC.md`

## Phase 0：Snapshot 與 WSL health

> Status: in-progress

- 目標：建立可恢復的環境基線，先證明 Ubuntu 24.04 direct exec 健康。
- 已完成：Windows host、PowerShell 7.6.3、Codex、uv、pyenv-win、Node/fnm、Go、
  Docker、WSL 目標與 dotfile 未提交狀態的初步盤點。
- 尚未完成：WSL direct exec probe；目前 `/bin/uname` 與 `/bin/sh` 探測逾時。
- 新證據：`wsl.exe --terminate Ubuntu-24.04` 也逾時，故問題位於 WSL host/service
  control path；未進入 distro 內做 PATH 或 package 修改。
- 可先完成：active Codex hooks 已備份並收斂為 Pilotfish Windows-compatible hooks；
  PowerShell redirected PSReadLine guard 已同步到 source 與目前 copied profile。
- 可先完成：VS Code Windows terminal profile 已移除 Git Bash、Ubuntu 22/舊 Ubuntu
  profile，預設改為 PowerShell；保留 Ubuntu-24.04 profile。

## Phase 1：Windows runtime normalization

> Status: in-progress

- 目標：消除 Windows Python、Node、Go command precedence 衝突。
- 已完成：nvm-windows 1.2.2 安裝，Node 26.7.0 64-bit 安裝與切換；User PATH
  已將 NVM_HOME/NVM_SYMLINK literal placeholder 修正為實際路徑。
- 已完成：Go profile 優先明確的 `C:\Program Files\Go\bin`，避免 Scoop shim
  與 machine install 競爭；目前兩者版本同為 Go 1.26.2。
- 已完成：安裝官方 Python 3.14.6，`python`/`python3` 在 fresh PowerShell
  都指向同一個官方 interpreter；pyenv-win 與 uv 保留作為版本/專案工具鏈。
- 已完成：移除 Scoop fnm 與其 shim，清除 nvm 內非目標 Node 版本/殘留 junction，
  目前只保留 nvm-windows Node 26.7.0。
- 已完成：移除 Scoop Go duplicate，`go` 唯一解析到 `C:\Program Files\Go\bin\go.exe`。
- 尚未完成：Docker CLI 可用，但 Docker daemon named pipe 尚未存在，需啟動 Docker
  Desktop 後再驗證 context。
- 已新增：`script/windows/setup.d/runtime-audit.ps1`，支援 Windows audit 與可選的
  bounded WSL probe。
- 已完成：Windows Codex active hooks 已收斂為 Pilotfish 原生 Windows-compatible
  hooks；Pilotfish installer 另加上 foreign hook 缺少 `commandWindows` 的非阻塞警告，
  不自動刪除或改寫既有 hook。
- 尚未完成：WSL health gate；Windows runtime duplicate source 已收斂。

## Phase 2：WSL runtime normalization

> Status: not-started

- 目標：建立 Ubuntu 24.04 自己的 Python、Node、Go 與 VS Code Remote runtime。

## Phase 3：Dotfile reproducibility

> Status: in-progress

- 目標：將已驗證環境收斂為可重複 setup 與檢查。
- 已完成：Windows profile、Node/Python/Go setup 模組與 VS Code 設定同步；新增
  `runtime-audit.ps1` 作為 read-only 檢查入口。
- 已完成（2026-09-29）：Windows 原生 Neovim 工作流，不需切 WSL。
  - scoop mingw 的 bin 從 User PATH 遺失（殘留不存在的 `C:\MinGW\bin`），
    `scoop reset mingw` 補回；補裝 fzf、tree-sitter、zoxide、win32yank、leaf（npm）。
  - nvim config 在 Windows 使用 pwsh 作為 `shell`、無 MSVC 時設 `CC=gcc`
    編 treesitter parser、npm 全域套件路徑與 Copilot config 路徑改為 Windows 可解析。
  - Windows Terminal 預設改為 PowerShell 7，解除 `ctrl+comma`、`alt+up/down`
    以免攔截 nvim 的 terminal toggle 與搬行。
  - `install_neovim.ps1` 同步上述依賴與 mingw PATH 修復。

## Phase 4：Hook isolation

> Status: in-progress

- 目標：讓 Windows Codex 不再執行沒有 Windows contract 的 Unix-only hooks。
- 已完成：目前 Windows active Codex hooks 已備份並只保留 Pilotfish；foreign hook
  的永久治理由 Pilotfish installer 警告提示處理。

---

## Completed Phases

尚無。
