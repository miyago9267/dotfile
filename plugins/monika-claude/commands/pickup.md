---
name: pickup
description: 讀取上一個 session 的 handoff，繼承 context 後繼續工作
command: /pickup
---

# Pickup — 繼承前一個 Session 的 Context

## 執行步驟

### 1. 讀取 handoff

依序嘗試讀取 handoff：

1. `.ai/HANDOFF.md`（SDD v2 標準位置）

若不存在，告知使用者「沒有可繼承的 handoff」並停止。

### 2. 讀取當前目錄的 PROJECT.md

依 project-map skill 的規則，嘗試讀取：

- `.ai/PROJECT.md`
- `.claude/PROJECT.md`

### 3. 輸出繼承摘要

用以下格式回報：

```text
已繼承 handoff from: {來源路徑}
建立時間: {時間}

繼承的任務：{任務描述}
進度：{進度}
未完成：{未完成項目}

當前目錄：{pwd}
當前目錄技術棧：{從 PROJECT.md 讀到的資訊}

準備好繼續工作。下一步：{handoff 中的下一步}
```

### 4. 清除 handoff（選擇性）

詢問使用者是否要清除已讀取的 handoff（避免下次重複載入）。
