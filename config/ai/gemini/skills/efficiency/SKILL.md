---
name: efficiency
description: "明確要求 efficiency audit，或同一 session 出現重複搜尋／過大輸出時，找出可修正的浪費。"
when_to_use: "只在 audit 或可觀察到重複浪費時觸發，不在每個 turn 自動檢查。"
tags: [efficiency, turns, context, tokens]
effort: low
shell: none
runtime-scope: shared-core
alwaysApply: false
---

# efficiency -- 效率紀律

只檢查目前任務可觀察到的效率問題，提出最多五個可直接執行的修正。
不要重做完整 session review，也不要重複 `search-discipline`、`context-prompt-discipline`
或 shared completion gate。

## 可檢查的訊號

- 不相依的已知讀取被拆成多個回合
- 搜尋或 logs 沒有 bounded output
- 同一 anchor 被重複搜尋
- 可由 Agent 自行處理的低風險步驟被丟回使用者

## 改善建議格式

發現違規時，應條列項目並附帶具體修正策略：

```text
- [bounded-search] 同一 anchor 被重複搜尋：合併成一次有上限的搜尋。
- [context] 載入不必要的大檔案：先縮小到 decision-carrying lines。
- [delegation] 只有在 surface 獨立且 coordination 成本較低時才委派。
```
