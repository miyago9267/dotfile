---
id: spec-secrets-management
title: Dotfile Secret 管理（age + sops）
status: in-progress
created: 2026-03-19
updated: 2026-03-24
author: Miyago
approved_by:
tags: [secrets, age, sops, security, cross-platform]
priority: high
---

# Dotfile Secret 管理（age + sops）

## Background

環境變數中的 token/key 無法上版控，換機器時容易遺失。
Miyago 目前沒有專門的密碼管理器，token 散落各處，常常忘記。

需要一個方案讓 secret 安全地跟著 dotfile repo 走。

## Requirements

1. Token/API key 加密後可安全 commit 進 dotfile repo
2. 換機器時只需攜帶一把 age private key 即可解密所有 secret
3. 日常使用無感 -- shell 啟動自動載入解密後的環境變數
4. 支援 macOS 和 Linux（Windows 為 nice-to-have）
5. 新增/修改 secret 的操作簡單直覺

## Non-goals

- 不做團隊多人共享 secret（只有 Miyago 自用）
- 不整合雲端密碼管理服務
- 不取代 macOS Keychain（那邊放密碼，這邊放 dev token）

## Architecture

### 工具選擇

| 工具 | 用途 |
|------|------|
| `age` | 加密/解密引擎，取代 GPG |
| `sops` | 結構化 secret 編輯器，支援 yaml/json/env |

### 目錄結構

```text
secrets/
  .sops.yaml              # sops 設定：指定 age public key 作為 recipient
  tokens.enc.yaml         # 加密的 secret 檔（安全上版控）
  README.md               # 使用說明

~/.age/
  key.txt                 # age private key（絕對不上版控）

~/.env.secrets            # 解密後的 env 輸出（gitignored，runtime 用）
```

### 檔案格式

`tokens.enc.yaml`（sops 加密後的樣子）：

```yaml
# 分類管理 token
github:
  GITHUB_TOKEN: ENC[AES256_GCM,data:...,type:str]
  GH_PACKAGES_TOKEN: ENC[AES256_GCM,data:...,type:str]
openai:
  OPENAI_API_KEY: ENC[AES256_GCM,data:...,type:str]
cloud:
  GCLOUD_SERVICE_KEY: ENC[AES256_GCM,data:...,type:str]
  AWS_ACCESS_KEY_ID: ENC[AES256_GCM,data:...,type:str]
  AWS_SECRET_ACCESS_KEY: ENC[AES256_GCM,data:...,type:str]
sops:
  # ... sops metadata
```

### 工作流程

#### 初始化（一次性）

```text
1. brew install age sops
2. age-keygen -o ~/.age/key.txt       # 產生 key pair
3. 把 public key 寫進 secrets/.sops.yaml
4. 建立 secrets/tokens.enc.yaml（空模板）
5. .gitignore 加入 ~/.env.secrets 相關 pattern
```

#### 新增/編輯 secret

```bash
sops secrets/tokens.enc.yaml
# -> 自動解密開啟 $EDITOR，存檔時自動加密
```

#### Shell 載入

```text
.zshrc.d/secrets.zsh:
  1. 檢查 ~/.age/key.txt 存在
  2. sops -d secrets/tokens.enc.yaml -> 解析 yaml -> export 環境變數
  3. 或：解密輸出到 ~/.env.secrets，再 source 它（效能較好）
```

#### 換機器

```text
1. git clone dotfile repo
2. 從安全管道（AirDrop / USB / 1Password）複製 ~/.age/key.txt
3. 跑 setup script -> 自動解密 -> 環境變數就位
```

## ADR

### ADR-1: 選擇 age 而非 GPG

- age 設計簡單，一個 key file 搞定
- GPG 需要管理 keyring、trust model、subkey，過度複雜
- age key 是純文字，備份容易

### ADR-2: 效能策略 -- 解密快取

shell 啟動時每次跑 `sops -d` 會有約 200-300ms 延遲。
採用快取策略：

- 首次 source 時解密寫入 `~/.env.secrets`
- 後續啟動直接 source 快取檔
- 提供 `secrets-reload` 指令手動刷新
- 快取檔權限設為 `600`

### ADR-3: 加密檔案格式選 YAML

- YAML 支援巢狀分類（github/openai/cloud）
- sops 對 YAML 的支援最成熟
- 比 .env 格式更有組織性

## Phase 計畫

### Phase 1: 基礎建設

- 安裝腳本（age + sops）
- 初始化 age key pair
- 建立 `secrets/` 目錄和 `.sops.yaml`
- `.gitignore` 更新

### Phase 2: Shell 整合

- `secrets.zsh` 載入模組
- 解密快取機制
- `secrets-reload` / `secrets-edit` helper function

### Phase 3: Setup 整合

- `setup.sh` / `setup.ps1` 整合安裝流程
- 首次 setup 引導建立或匯入 age key
- 換機器的 onboarding 體驗

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| age key 遺失 | 所有 secret 無法解密 | key 備份到 macOS Keychain 或實體 USB |
| 不小心 commit 解密後的檔案 | secret 外洩 | `.gitignore` + git hook 檢查 |
| sops 版本升級改格式 | 無法解密舊檔案 | pin sops 版本，定期驗證 |
