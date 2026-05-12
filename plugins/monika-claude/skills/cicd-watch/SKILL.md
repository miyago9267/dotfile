---
description: "CI/CD 監控 -- 追蹤最新 pipeline 狀態，失敗時自動修復再 push。"
user-invocable: true
---

# /cicd-watch [run-id]

監控 CI/CD pipeline 執行結果，失敗時自動修復。

## 行為

1. 若提供 run-id，直接監控該 run
2. 若未提供，取當前 branch 最新的 run
3. 等待 run 完成
4. 成功 → 回報一行摘要
5. 失敗 → 讀 log、分析原因、本地修復、push、再次監控
6. 最多自動修復 3 輪

## 使用時機

- `git push` 後自動觸發（由 `rules/cicd-watch.md` 規定）
- 手動執行 `/cicd-watch` 查看當前 CI 狀態
- 手動執行 `/cicd-watch <run-id>` 追蹤特定 run

請用 cicd-watcher agent 執行監控流程。
