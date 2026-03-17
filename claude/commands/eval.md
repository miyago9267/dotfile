---
description: 評估驅動開發 -- 定義、執行、回報功能的通過標準（pass@N）。
---

# /eval [動作] [功能名稱]

管理評估驅動開發（Eval-Driven Development）流程。

## 用法

- `/eval define <名稱>` — 建立評估定義（`.claude/evals/<名稱>.md`）
- `/eval check <名稱>` — 執行並回報評估結果
- `/eval report <名稱>` — 產出完整評估報告
- `/eval list` — 列出所有評估定義
- `/eval clean` — 清除舊記錄（保留最近 10 筆）

## 評估定義格式

```markdown
## EVAL: feature-name

### 能力評估（新功能）
- [ ] 描述能力 1
- [ ] 描述能力 2

### 回歸評估（舊功能不能壞）
- [ ] 既有行為 1 仍正常
- [ ] 既有行為 2 仍正常

### 通過標準
- 能力評估：pass@3 > 90%
- 回歸評估：pass^3 = 100%
```

## 回報格式

```text
EVAL REPORT: feature-name
========================
能力評估: X/Y 通過
回歸評估: X/Y 通過
狀態: IN PROGRESS / READY

結論: SHIP / NEEDS WORK / BLOCKED
```
