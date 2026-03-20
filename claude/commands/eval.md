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

## 評估類型

### 能力評估（Capability Eval）

測試「Claude 能不能做到以前做不到的事」：

- 定義明確的 success criteria
- 用 pass@k 衡量可靠度（至少一次成功 / k 次嘗試）
- 目標：pass@3 > 90%

### 回歸評估（Regression Eval）

確保「改動不會弄壞現有功能」：

- 以既有 baseline 為基準
- 用 pass^k 衡量穩定度（k 次全部成功）
- 目標：pass^3 = 100%

## Grader 類型

| Grader | 用途 | 規則 |
| --- | --- | --- |
| Code-based | 確定性檢查 | WHEN 有明確的 pass/fail 條件 THEN 用 script 驗證（grep / test / build） |
| Model-based | 開放式評估 | WHEN 輸出品質無法用 code 判定 THEN 讓 Claude 評分 1-5 並附理由 |
| Human | 安全/設計審查 | WHEN 涉及安全、UX、或架構決策 THEN 標記 HUMAN REVIEW REQUIRED + 風險等級 |

優先順序：code-based > model-based > human。能用 code 判定的不要用 model。

## 指標定義

- **pass@k** -- k 次嘗試中至少 1 次成功。用於能力評估。
- **pass^k** -- k 次嘗試全部成功。用於回歸評估和關鍵路徑。

## 回報格式

```text
EVAL REPORT: feature-name
========================
能力評估: X/Y 通過 (pass@3: XX%)
回歸評估: X/Y 通過 (pass^3: XX%)
狀態: IN PROGRESS / READY

結論: SHIP / NEEDS WORK / BLOCKED
```
