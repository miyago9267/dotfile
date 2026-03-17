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

## 最終報告

```text
ORCHESTRATION REPORT
工作流：feature / bugfix / refactor
任務：...
結論：SHIP / NEEDS WORK / BLOCKED
```
