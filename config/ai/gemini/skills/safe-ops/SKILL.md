---
name: safe-ops
description: 高自主權安全準則 -- 僅針對重大毀滅性操作 (tf apply, rm -rf 等) 請求確認。永遠生效。
alwaysApply: true
---

# safe-ops -- 高自主權安全準則

為了提高開發效率並減少對 Miyago 的干擾，本 Agent 擁有較高的操作自主權。除了以下明確列出的「重大決策」外，其餘操作（包含檔案覆寫、Git 操作、一般測試執行）皆可自主判斷並執行。

## 必須請求確認的重大操作 (Critical Operations)

以下操作執行前，必須先解釋原因並取得 Miyago 的明確同意：

### 1. 基礎設施與雲端資源 (IaC / Cloud)
- **Terraform Apply**：任何會導致資源「銷毀 (Destroy)」或「替換 (Replace)」的 `terraform apply`。
- **GCP 資源直接刪除**：透過 gcloud 指令直接刪除 VM、Cloud SQL、GKE 等核心資源。
- **IAM 權限移除**：大範圍移除現有的 IAM 權限或 Roles。

### 2. 檔案系統大規摸毀滅 (File System)
- **rm -rf**：針對非 `/tmp/` 或非當前開發專案路徑的目錄執行遞迴強制刪除。
- **資料庫毀滅**：`DROP DATABASE`、`DROP TABLE` 或不帶 WHERE 條件的 `DELETE`。

### 3. Git 極端操作
- **git push --force**：針對 `main`、`master` 或 `production` 等受保護分支。
- **git reset --hard**：會導致未提交代碼永久遺失的操作。

## 自主執行範圍 (Autonomous Zone)

以下操作**無需詢問**即可直接執行：
- 建立、修改或覆寫專案內的代碼檔案、設定檔（`.env` 除外，若涉及敏感資訊仍需謹慎）。
- 一般的 `git add`、`git commit`。
- 軟體包安裝、測試跑測、Linter 修復。
- 重啟開發環境服務（如 Docker Compose up/down）。

## 不變規則 (Hard Constraints)
- **Escalation Only**：AI Agents 依然嚴禁使用 `sudo` 或進行需要 root 權限的操作，遇到此類需求必須交給 Miyago。
- **備份優先**：在進行可能有風險的自主操作前（如覆寫重要的 legacy 腳本），應先執行 `cp file file.bak`。
