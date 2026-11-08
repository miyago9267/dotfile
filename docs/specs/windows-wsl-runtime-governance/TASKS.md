---
spec: windows-wsl-runtime-governance
batch: 1
created: 2026-08-09
---

# Tasks: Windows 與 WSL Runtime 治理

> Spec: `docs/specs/windows-wsl-runtime-governance/SPEC.md`
> Batch: 1

## 前置條件

- [x] 確認 Windows 與 WSL 分開維護
- [x] 確認 Windows Node 目標為 nvm-windows + Node 26.x
- [x] 記錄 dotfile 現有未提交變更
- [x] 完成 Windows host runtime inventory；WSL inventory 保留 health blocker
- [ ] WSL health gate 通過

## Phase 0：Snapshot 與 WSL health

- [x] 保存 Windows PATH、command resolution、套件來源與 VS Code 狀態
- [ ] 保存 WSL distro、direct exec、`/etc/wsl.conf`、PATH 與 runtime 狀態
- [ ] 驗證 `/bin/uname`、`/bin/sh`、檔案系統與網路
- [ ] 若需要重開機或 WSL shutdown，先取得使用者確認

## Phase 1：Windows runtime normalization

- [x] 修正 Python Store alias 與 pyenv-win precedence
- [x] 建立 nvm-windows，安裝並切換 Node 26.x 64-bit
- [x] 移除 fnm multishell 與非目標 Node 22/25；保留 nvm Node 26.x
- [x] 選定單一 Go command source
- [x] 保留並驗證 PowerShell 7.6、cmd、Git CLI、uv、Docker CLI
- [ ] 驗證 Docker daemon / Docker Desktop context

## Phase 2：WSL runtime normalization

- [ ] 在 Ubuntu 24.04 建立獨立 pyenv、nvm、Node 26 與 Go workflow
- [ ] 移除或隔離 WSL 對 Windows language runtime 的 PATH 依賴
- [ ] 驗證 VS Code Remote - WSL interpreter、Node、Go 與 Docker context

## Phase 3：Dotfile reproducibility

- [x] 更新 Windows/WSL setup 與 profile 模組
- [x] 加入 PATH、version manager、VS Code context 檢查
- [x] 加入 dry-run 與 rollback/backup 說明
- [ ] 與目前未提交 dotfile 修改安全整合

## 驗證

- [ ] `docs/specs/windows-wsl-runtime-governance/TESTS.md` 全部必要案例通過
- [ ] Windows 與 WSL 的 `python`、`node`、`go` command source 可追溯
- [ ] VS Code Windows 與 WSL Remote 使用正確 runtime
- [ ] 未保留未說明的 duplicate runtime precedence
