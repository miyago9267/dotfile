---
name: efficiency
description: 效率紀律 -- 檢查目前 session 是否違反效率規則。重點在於減少 Turns 與 Context 浪費。永遠生效。
---

# efficiency -- 效率紀律

檢查目前對話 (Session) 是否有違反效率紀律的行為，並提出具體改進方案。

## 核心檢查指標

### 1. 回合數浪費 (Turns Waste)
- **缺乏並行**：獨立的工具調用是否被串行執行？(Gemini CLI 預設並行，應優先利用)
- **欠缺脈絡**：`grep_search` 是否忘記帶 `context` 導致下一輪必須 `read_file`？
- **過度 Read**：是否重複讀取同一檔案而不利用之前的輸出？

### 2. Context 膨脹 (Context Bloat)
- **過大讀取**：是否沒用 `start_line` / `end_line` 讀取了整份 500+ 行的大檔案？
- **冗長回覆**：對話是否包含無謂的 Filler (開場白、結語、對工具調用的機械描述)？
- **未即時壓縮**：是否在邏輯斷點忘記建議使用者 `/compact`？

### 3. 工具誤用 (Tool Misuse)
- **大工具殺雞**：是否對簡單搜尋動用了 `codebase_investigator`？
- **批次任務未委派**：是否在主歷史中處理超過 3 個檔案的重複修改，而非委派給 `generalist`？

## 改善建議格式

發現違規時，應條列項目並附帶具體修正策略：

```text
- [Lack of Parallelism] 讀取 A、B、C 檔案分成了 3 個 Turns，應在同一 Turn 併發執行。
- [Turn Minimization] grep_search "SymbolName" 沒帶 context 參數，應加上 context=5 減少後續 read_file 呼叫。
- [History Bloat] 主對話歷史已超過 15k tokens，建議執行 /compact 進行摘要。
- [Missing Delegation] 正在手動修改 5 個測試檔案，應委派給 generalist 處理以保持主歷史精簡。
```

## 紀律規則

1. **並行優先**：除非下一個工具依賴前一個的副作用，否則一律在同一輪調用。
2. **單輪完結**：盡量在 single turn 完成 "Search -> Read Context -> Propose Plan"。
3. **主歷史整潔**：頻繁、瑣碎、高輸出的操作 (如 batch lint fix) 必須委派。
