---
name: efficiency
description: 效率紀律 -- 檢查目前 session 是否違反效率規則。重點在於減少 Turns 與 Context 浪費。永遠生效。
alwaysApply: true
---

# efficiency -- 效率紀律

檢查目前對話 (Session) 是否有違反效率紀律的行為，並提出具體改進方案。確保充分利用 Gemini CLI 的平行調用能力與 Context 管理策略。

## 核心檢查指標

### 1. 回合數浪費 (Turns Waste)
- **缺乏平行處理**：不相依的工具調用（例如讀取多個檔案、多個不相關的 grep）是否被錯誤地設定了 `wait_for_previous: true` 或分拆在多個 Turns 執行？
- **欠缺脈絡**：`grep_search` 是否忘記帶 `context` 導致必須額外花一個 Turn 去 `read_file`？
- **過度交談**：是否在不必要時（例如單純搜出結果後）向使用者報告，而非直接進行下一步動作？

### 2. Context 膨脹 (Context Bloat)
- **過大讀取**：是否沒用 `start_line` / `end_line` 讀取了大檔案，導致無用的 Context 佔用？
- **冗長回覆**：對話是否包含無謂的 Filler (開場白、結語、對工具調用的機械描述)？
- **未即時壓縮**：是否在邏輯斷點忘記建議使用者 `/compact` (目標壓縮率 70%，觸發點 ~20K tokens)？

### 3. 工具誤用 / 子代理調度 (Tool Misuse)
- **大工具殺雞**：是否對簡單搜尋動用了 `codebase_investigator`？
- **批次任務未委派**：是否在主歷史中處理超過 3 個檔案的重複修改，而非委派給 `generalist` 處理以保持主歷史精簡？

## 改善建議格式

發現違規時，應條列項目並附帶具體修正策略：

```text
- [Lack of Parallelism] 讀取 A、B、C 檔案分成了 3 個 Turns，應在同一 Turn 併行執行。
- [Turn Minimization] grep_search "SymbolName" 沒帶 context 參數，應加上 context=5。
- [History Bloat] 主對話歷史逼近 20k tokens，建議執行 /compact。
- [Missing Delegation] 正在手動修改 5 個測試檔案，應委派給 generalist。
```
