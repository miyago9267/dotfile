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

<!-- markdownlint-disable-next-line MD025 -->
# Dotfile Secret 管理（age + sops）

## Background

環境變數中的 token/key 無法上版控，換機器時容易遺失。
Miyago 目前沒有專門的密碼管理器，token 散落各處，常常忘記。

需要一個方案讓 secret 安全地跟著 dotfile repo 走。

## Requirements

1. Token/API key 加密後可安全 commit 進 dotfile repo
2. 換機器時只需攜帶一把 age private key 即可解密所有 secret
3. 日常使用低摩擦 -- 可由使用者顯式載入解密後的環境變數
4. 支援 macOS 和 Linux（Windows 為 nice-to-have）
5. 新增/修改 secret 的操作簡單直覺

## Non-goals

- 不做團隊多人共享 secret（只有 Miyago 自用）
- 不整合雲端密碼管理服務
- 不取代既有 KeePassXC；高權限或正式環境 secret 不放進本機開發 bundle

## Architecture

### 工具選擇

| 工具 | 用途 |
| --- | --- |
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

`tokens.enc.yaml` 解密後的邏輯結構：

```yaml
github:
  token: <encrypted value>
  packages_token: <encrypted value>
openai:
  api_key: <encrypted value>
typesafe:
  api_key: <encrypted value>
```

`sops` 的 metadata 會由工具放在加密檔案中，不列入這個邏輯 schema。

Export contract：

- `github.token` 變成 `GITHUB_TOKEN`。
- `openai.api_key` 變成 `OPENAI_API_KEY`。
- `typesafe.api_key` 變成 `TYPESAFE_API_KEY`。
- 目前 parser 只支援兩層 YAML 和單行 scalar value。
- 第二層不要重複第一層前綴，例如不要寫 `github.github_token`。

### 工作流程

#### 初始化（一次性）

```text
1. brew install age sops
2. sec init
3. 用 `sec edit` 編輯 `secrets/tokens.enc.yaml`
4. 確認 `.gitignore` 排除 `~/.env.secrets`
```

#### 新增/編輯 secret

```bash
sec edit
```

#### Shell 載入

顯式載入：

```bash
sec reload
source ~/.env.secrets
```

不要在每個 shell 啟動時無條件 source 全部 secret；需要最小權限時，改用
KeePassXC 的 `agent-secret` process injection。

#### 換機器

```text
1. git clone dotfile repo
2. 從安全管道（AirDrop / USB / 1Password）複製 ~/.age/key.txt
3. 跑 setup script
4. 執行 `sec reload`，只在需要的 shell 內 source `~/.env.secrets`
```

## ADR

### ADR-1: 選擇 age 而非 GPG

- age 設計簡單，一個 key file 搞定
- GPG 需要管理 keyring、trust model、subkey，過度複雜
- age key 是純文字，備份容易

### ADR-2: 效能策略 -- 解密快取

shell 啟動時每次跑 `sops -d` 會有約 200-300ms 延遲。
採用快取策略：

- `sec reload` 時解密寫入 `~/.env.secrets`
- 由使用者在需要的 shell 內 source 快取檔
- 提供 `sec reload` 手動刷新
- 快取檔權限設為 `600`

### ADR-3: 加密檔案格式選 YAML

- YAML 支援巢狀分類（github/openai/cloud）
- sops 對 YAML 的支援最成熟
- 比 .env 格式更有組織性

### ADR-4: Bundle 與 KeePassXC 的分工

- 本機開發、低風險、需要多個 key 的工作使用 age + sops bundle。
- 高權限、正式環境或需要 process-level injection 的 key 使用 KeePassXC
  `agent-secret`。
- 同一把 key 不同時放在兩個來源，避免 rotation 後不同步。

## Phase 計畫

### Phase 1: 基礎建設

- 安裝腳本（age + sops）
- 初始化 age key pair
- 建立 `secrets/` 目錄和 `.sops.yaml`
- `.gitignore` 更新

### Phase 2: Shell 整合

- `secrets.zsh` 載入模組
- 解密快取機制
- `sec reload` / `sec edit` command workflow

### Phase 3: Setup 整合

- `setup.sh` / `setup.ps1` 整合安裝流程
- 首次 setup 引導建立或匯入 age key
- 換機器的 onboarding 體驗

## Risks

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| age key 遺失 | 所有 secret 無法解密 | key 備份到 macOS Keychain 或實體 USB |
| 不小心 commit 解密後的檔案 | secret 外洩 | `.gitignore` + git hook 檢查 |
| sops 版本升級改格式 | 無法解密舊檔案 | pin sops 版本，定期驗證 |
