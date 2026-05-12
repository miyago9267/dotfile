---
name: safe-ops
description: 危險操作前的安全確認機制。永遠生效。
alwaysApply: true
---

# 安全操作守則

## 必須確認才能執行的操作

以下操作在執行前**必須先告知使用者並取得確認**：

### 資料庫

- DROP TABLE / DROP DATABASE
- 大量 DELETE / UPDATE（超過 100 筆）
- Schema migration（特別是 destructive migration）

### 檔案系統

- `rm -rf` 任何非 `/tmp/` 的目錄
- 覆寫 config 檔（`.env`、`docker-compose.yaml` 等）
- 修改 `.gitignore` 導致追蹤中的檔案被排除

### Git

- `git push --force`（任何分支）
- `git reset --hard`
- `git clean -fd`
- 刪除遠端分支

### 雲端 / 基礎設施

- 刪除 GCP 資源（VM、Cloud SQL、GKE cluster）
- 修改 IAM 權限
- 修改 DNS 記錄
- kubectl delete namespace / deployment

## 安全模式

遇到不確定的操作時，優先選擇：

1. **先查後改**：先用唯讀指令確認狀態，再執行修改
2. **先備後改**：先備份，再修改
3. **小範圍測試**：先在單一資源上測試，確認無誤再擴大
