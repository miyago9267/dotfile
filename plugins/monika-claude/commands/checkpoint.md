---
description: 工作節點管理 -- 建立或驗證工作進度節點，支援回溯比較。
---

# /checkpoint [動作] [名稱]

管理工作流程中的節點（checkpoint），方便比較前後差異或回溯。

## 用法

- `/checkpoint create <名稱>` — 建立節點
- `/checkpoint verify <名稱>` — 與指定節點比較當前狀態
- `/checkpoint list` — 列出所有節點
- `/checkpoint clear` — 清除舊節點（保留最近 5 個）

## 建立節點

1. 執行 `/verify quick` 確認狀態乾淨
2. 建立 git stash 或 commit（帶節點名稱）
3. 記錄到 `.claude/checkpoints.log`

## 驗證節點

比較當前狀態與指定節點的差異：

```text
CHECKPOINT COMPARISON: <名稱>
============================
Files changed: X
Tests: +Y passed / -Z failed
Coverage: +X% / -Y%
Build: [PASS/FAIL]
```

## 典型流程

```text
/checkpoint create "feature-start"
→ 實作核心功能
/checkpoint create "core-done"
→ 執行測試
/checkpoint verify "core-done"
→ 重構
/checkpoint create "refactor-done"
→ 送 PR 前
/checkpoint verify "feature-start"
```
