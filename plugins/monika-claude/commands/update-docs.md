---
description: 同步更新文件 -- 從 package.json 和 .env.example 自動生成開發和運維文件。
---

# /update-docs

從程式碼的唯一真相來源（package.json、.env.example）同步更新文件。

## 流程

1. 讀取 `package.json` 的 `scripts` 區塊
   - 生成指令參考表（含說明）
2. 讀取 `.env.example`
   - 提取所有環境變數
   - 說明用途和格式
3. 生成 `docs/CONTRIB.md`（開發貢獻指南）：
   - 開發工作流
   - 可用指令列表
   - 環境設定
   - 測試流程
4. 生成 `docs/RUNBOOK.md`（維運手冊）：
   - 部署流程
   - 監控和告警
   - 常見問題和解法
   - 回滾流程
5. 找出過期文件（90 天以上未修改）
6. 回報差異摘要

唯一真相來源：`package.json` 和 `.env.example`，不依賴手動維護的文件。
