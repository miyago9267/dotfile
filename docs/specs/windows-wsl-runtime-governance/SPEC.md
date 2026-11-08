---
id: spec-windows-wsl-runtime-governance
title: Windows 與 WSL Runtime 治理
status: in-progress
created: 2026-08-09
updated: 2026-08-09
author: Miyago
tags: [windows, wsl, powershell, python, node, vscode, path, dotfiles]
priority: high
---

# Windows 與 WSL Runtime 治理

## Background

目前 Windows 開發環境同時存在 PowerShell、WSL、Node 多重來源、Python
Store alias、Go 多重 PATH 來源，以及 Codex/Claude hooks 的跨 shell 混用。
這會造成命令解析不穩定、Windows 與 WSL 互相污染，以及 VS Code 選到錯誤
runtime。WSL Ubuntu 24.04 目前連直接執行 `/bin/uname` 都曾超過 30 秒未返回，
必須先排除 runtime 層問題，再進行清理。

本 spec 只治理 Miyago 的本機環境與 dotfile 可重現設定；Pilotfish 的產品相容性
提示另由 Pilotfish repo 的獨立變更處理。

## Requirements (EARS)

- **R1**: When Windows 開啟互動式 terminal，日常 shell shall 只有 PowerShell 7.6、
  原生 cmd 與 Git CLI；Windows PowerShell 5.1 shall 僅保留作為 OS 相容層，
  不列入日常 PATH 或 profile 選擇。
- **R2**: When WSL 啟動，WSL runtime shall 只保留 Ubuntu 24.04，且 Linux PATH
  shall 不直接依賴 Windows 的 Python、Node、Go 或套件管理器 binary。
- **R3**: When Windows 執行 `python` 或 `python3`，command resolution shall
  指向明確記錄的非 Store Python runtime；目前 primary runtime 為官方 Python
  3.14.6，pyenv-win 保留作為多版本管理，uv 保留作為隔離的 project/tool workflow。
  不得解析到 Microsoft Store alias。
- **R4**: When Windows 執行 `node` 或 `npm`，command resolution shall 指向
  nvm-windows 管理的 Node 26.x；fnm multishell 與固定的 Program Files Node
  shall 不再同時競爭 PATH。
- **R5**: When WSL 執行 `node`、`npm`、`python` 或 `go`，command resolution
  shall 使用 WSL 自己的版本管理與 binary，不得依賴 `/mnt/c` 的 Windows runtime。
- **R6**: When Windows 執行 `go`，shall 只有一個有效的 command source；Program
  Files 與 Scoop shim 不得同時以不同版本競爭。
- **R7**: When VS Code 以 Windows host 開啟專案，shall 使用 Windows runtime；
  when VS Code 以 WSL Remote 開啟專案，shall 使用 Ubuntu 24.04 runtime，兩者的
  interpreter、Node、Go 與 Docker context shall 可獨立驗證。
- **R8**: When `wsl.exe -d Ubuntu-24.04 --exec /bin/uname -a` 執行，shall 在
  5 秒內返回成功；若失敗，系統 shall 先記錄原因並停止後續 WSL 清理。
- **R9**: When dotfile setup 或 profile 載入，shall 保留使用者未提交變更，且不得
  靠覆寫或刪除現有設定來繞過衝突。
- **R10**: When Codex 在 Windows 執行 hooks，shall 只執行有明確
  `commandWindows` 或 Windows-native runner 的 hook；Unix-only hook shall
  被標示、隔離或明確停用。
- **R11**: Before removing any shell, runtime manager, or duplicate binary，the
  system shall create a recoverable inventory and verify that no retained tool
  resolves through the removal target。

## Non-goals

- 不移除 Windows 內建 PowerShell 5.1 系統元件。
- 不把 Windows 與 WSL 強行合併成同一套 Python 或 Node binary。
- 不為了保留 Git CLI 而把 Git Bash 設為日常 shell；Git CLI 與 Git Bash 的
  bundled files 分開評估。
- 不在未確認 VS Code、Docker、專案依賴前直接解除安裝工具。
- 不自動覆寫 dotfile 目前的未提交修改。
- 不在這份 spec 內修改 Pilotfish 的產品程式碼。

## Alternatives Considered

### 共用 Windows 與 WSL PATH

拒絕。Windows 與 Linux binary、shell startup、VS Code Remote context 不同，
共用 PATH 會重新引入目前要消除的衝突。

### Windows 保留 fnm

拒絕。現有 Windows 已同時出現 fnm multishell 與固定 Node 22；本目標明確採用
nvm-windows + Node 26，舊 fnm 需在驗證完成後移除或隔離。

### 只用 uv，不保留 pyenv-win

暫不採用。uv 作為快速、可重現的 Python workflow 保留；pyenv-win 仍保留作為
需要多 Python 版本的 Windows 專案管理器，兩者責任需在 profile 與文件中分清楚。

## Architecture

```text
Windows host
  pwsh 7.6 / cmd / Git CLI
  official Python 3.14.6 -> Windows primary interpreter
  pyenv-win -> optional Python versions
  nvm-windows -> Node 26.x
  uv -> isolated Python tools and projects
  Go single source
  Docker Desktop
  VS Code Windows host

WSL Ubuntu 24.04
  Linux shell and PATH
  Linux pyenv / nvm / project tools
  VS Code Remote - WSL
  Docker integration verified independently
```

Dotfile responsibilities:

- Windows profile: no Store alias, no duplicate Node/Go precedence, no profile-time
  shell probing that blocks startup.
- WSL profile: Linux-only PATH and version managers; no Windows PATH import for
  language runtimes.
- Setup scripts: inventory first, preserve changes, support dry-run, verify each
  runtime after modification.
- Codex hook configuration: Windows hooks use explicit native commands; Claude
  Unix hooks do not silently run inside Windows Codex.

## ADR

### ADR-1: Windows 與 WSL 分開維護

- 決策：兩邊各自擁有 Python、Node、Go、VS Code integration 與 PATH。
- 原因：VS Code、Docker、binary 格式與專案依賴會依 host 改變；隔離比跨環境
  自動同步更可靠。

### ADR-2: Windows Node 改用 nvm-windows + Node 26

- 決策：Windows 只保留 nvm-windows 管理的 Node 26.x；WSL 另用 Linux nvm。
- 原因：目前 fnm multishell 與固定 Node 22 造成可觀察的 command precedence
  衝突；使用者已明確選擇 nvm 與 Node 26。

### ADR-3: 先修 WSL 啟動健康度

- 決策：WSL direct exec timeout 是 Phase 0 blocker；未通過前不清理 WSL 內部。
- 原因：若 `/bin/uname` 都無法及時返回，任何 PATH 或 package 結果都不可信。

### ADR-4: Windows Python 的 primary 與 optional toolchain 分離

- 決策：Windows 的 `python` primary 使用官方 Python 3.14.6；pyenv-win 不負責
  隱式接管目前 shell，uv 負責 project/tool isolation。
- 原因：pyenv-win 目前版本索引更新受到 Windows `htmlfile`/VBScript 相容性
  問題阻塞；讓 Store alias 消失與讓多版本管理可用是兩個不同問題，不將後者
  風險帶入 primary command resolution。

### ADR-5: 保留一個主要套件管理來源

- 決策：先保留 Scoop、winget、Chocolatey/UniGetUI 的現況並盤點用途；完成
  dependency map 後再選主要來源，不在本 phase 猜測移除。
- 原因：直接移除套件管理器可能連帶破壞已安裝工具；先治理 PATH 與來源優先序。

## Phase 計畫

### Phase 0: Snapshot 與 WSL health

- 保存 Windows PATH、命令解析、已安裝套件、WSL distro 狀態、VS Code 狀態。
- 驗證 WSL direct exec、Ubuntu init、檔案系統與網路。
- 若 WSL 需重開機或 shutdown，先停下來取得使用者確認。

### Reboot recovery gate

重開機後依序執行以下 read-only checks；只有第一步成功才允許進入 Phase 2：

1. `wsl.exe -l -v` 必須只列出 `Ubuntu-24.04`。
2. `wsl.exe -d Ubuntu-24.04 --exec /bin/uname -a` 必須在 5 秒內成功。
3. 以 `/bin/sh` 執行 `printf`、讀取 `/etc/wsl.conf`、取得 `$PATH`。
4. 若任一步逾時或失敗，保存輸出並停止 WSL package/PATH 修改；只處理 host
   service 或要求下一個明確的重開機/WSL 修復決策。

### Phase 1: Windows runtime normalization

- 修正 Python Store alias 與 pyenv-win precedence。
- 建立 nvm-windows + Node 26，驗證後移除或隔離 fnm 與固定 Node 22。
- 選定唯一 Go command source。
- 保留 PowerShell 7.6、cmd、Git CLI、uv、Docker。

### Phase 2: WSL runtime normalization

- 在 Ubuntu 24.04 內建立獨立 Python、Node、Go 與 project toolchain。
- 驗證 WSL PATH 不依賴 Windows language runtimes。
- 修復 VS Code Remote - WSL 與 Docker integration。

### Phase 3: Dotfile reproducibility

- 將已驗證狀態整理進 Windows/WSL setup 與 profile 模組。
- 為 PATH、version manager、VS Code context 增加檢查與 dry-run。
- 與現有未提交 dotfile 變更分離整合。

### Phase 4: Hook isolation

- Windows Codex 只啟用 Windows-compatible hooks。
- Claude Unix hooks 保留在 Claude/WSL runtime，不讓 Windows Codex 直接呼叫裸 `bash`。
- 由 Pilotfish repo 另行加入 portability warning。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| WSL direct exec timeout | 無法可信地修復 WSL | 先做 health gate；必要時停下請使用者重開機 |
| 移除 fnm/Node 22 遺漏專案依賴 | Windows 專案無法執行 | 先掃 package manifests 與 command resolution，保留 backup |
| PATH 改動影響 VS Code/CI | IDE 與 terminal 結果不一致 | 分別測 Windows host 與 WSL Remote |
| dotfile 未提交修改衝突 | 使用者設定遺失 | 不 stash/pop 覆蓋；先建立明確備份與 diff |
| Docker daemon 未啟動 | 只能驗證 client，不能驗證 integration | 分離 client check 與 daemon check，不自行重啟 |
