---
spec: secrets-management
title: Dotfile Secret 管理 -- Phase 追蹤
updated: 2026-03-24
---

# Progress

## Phase 1: 基礎建設 -- completed

完成日期: 2026-03-19

- 跨平台安裝腳本 `install_sops.sh`（macOS brew / Arch pacman / Ubuntu binary download）
- `secrets/` 目錄建立，含 `.sops.yaml`、`tokens.enc.yaml`、`README.md`
- `.gitignore` 已排除 `secrets/*.dec.*` 明文檔案

產出檔案:
- `script/common/install_sops.sh`
- `secrets/.sops.yaml`
- `secrets/tokens.enc.yaml`
- `secrets/README.md`

## Phase 2: Shell 整合 -- completed

完成日期: 2026-03-19

- `secrets.zsh` 載入模組，shell 啟動時自動解密並 export 環境變數
- 解密快取機制：首次解密寫入 `~/.env.secrets`（權限 600），後續啟動直接 source
- 時間戳比對：加密檔比快取新時自動重新解密
- YAML 巢狀解析：`category.KEY` 轉為 `CATEGORY_KEY` 環境變數格式
- helper function: `secrets-edit`、`secrets-reload`、`secrets-init`

產出檔案:
- `config/zsh/.zshrc.d/secrets.zsh`

## Phase 3: Setup 整合 -- in-progress

開始日期: 2026-03-19

### 已完成

- `setup.sh` 已加入 `install_sops.sh` 安裝項目
- `sec` CLI 工具已建立，支援 init/edit/show/list/status/push/export/import/reload 九個子命令

產出檔案:
- `script/utils/sec`

### 待辦

- 首次 setup 時的 onboarding 自動引導（偵測 age key 不存在時引導使用者建立或匯入）
- `setup.ps1` PowerShell 版整合（加入 age + sops 安裝流程）
