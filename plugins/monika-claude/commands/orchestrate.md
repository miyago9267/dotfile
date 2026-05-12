---
description: 多 Agent 串接工作流 -- 依任務類型串接多個 agent，依序完成複雜任務。
---

# /orchestrate [工作流類型] [任務描述]

串接多個專業 agent，處理複雜任務。

## 內建工作流

| 類型 | Agent 串接 | 適用情境 |
| --- | --- | --- |
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer | 完整功能開發 |
| `bugfix` | debugger → tdd-guide → code-reviewer | Bug 調查與修復 |
| `refactor` | architect → code-reviewer → tdd-guide | 安全重構 |
| `security` | security-reviewer → code-reviewer → architect | 安全審查 |

## 用法

```text
/orchestrate feature "新增使用者認證"
/orchestrate bugfix "修復登入後 redirect 錯誤"
/orchestrate refactor "重構快取層"
/orchestrate custom "architect,tdd-guide,code-reviewer" "重新設計快取架構"
```

## Agent 交接格式

每個 agent 完成後產出交接文件：

```markdown
## HANDOFF: <前一個 agent> -> <下一個 agent>

### Context（做了什麼）
### Findings（發現或決策）
### Files Modified（異動的檔案）
### Open Questions（待解問題）
### Recommendations（建議下一步）
```

## Context 精煉模式

當 subagent 缺乏足夠 context 時，使用 4 階段迭代檢索：

### 流程

```text
DISPATCH -> EVALUATE -> REFINE -> LOOP (最多 3 cycle)
```

1. **DISPATCH** -- 用寬泛的 keyword/pattern 初步搜尋候選檔案
2. **EVALUATE** -- 評估每個檔案的相關性（0-1 分）
   - 0.8-1.0：直接相關，必須包含
   - 0.5-0.7：間接相關，視需要包含
   - < 0.5：排除，不會變相關
3. **REFINE** -- 根據評估結果調整搜尋策略
   - 加入在高相關檔案中發現的新 keyword
   - 排除確認無關的路徑
   - 鎖定尚未覆蓋的 gap
4. **LOOP** -- 重複直到滿足以下任一條件：
   - 有 3+ 個 relevance >= 0.7 的檔案且無 critical gap
   - 已達 3 cycle 上限

### 什麼時候用

- Subagent 被 spawn 時 context 不足
- 搜尋結果不符預期（codebase 用不同術語）
- 跨模組任務需要多方 context

### 什麼時候不用

- Context 明確（只改一個檔案）
- 已有完整的 handoff 文件
- 單一模組內的簡單修改

### 注意事項

- 第一輪搜尋常用來學習 codebase 的命名慣例
- 寧可少但精準，不要多但雜
- 3 個高相關檔案勝過 10 個平庸檔案

## 最終報告

```text
ORCHESTRATION REPORT
工作流：feature / bugfix / refactor
任務：...
結論：SHIP / NEEDS WORK / BLOCKED
```
