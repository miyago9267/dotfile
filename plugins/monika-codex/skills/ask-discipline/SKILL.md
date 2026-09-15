---
name: ask-discipline
description: "當我準備向 Miyago 提問但答案可能已在 repo、spec 或 runtime context 時，先縮小問題並只保留真正改變執行的 blocker。"
when_to_use: "完成最小 local check 後仍有會改變產品意圖、權限、風險或 user-owned input 的問題時。"
tags: [ask, decision, blocker, autonomy]
effort: low
shell: none
runtime-scope: shared-core
alwaysApply: false
user-invocable: true
---

# Ask Discipline

這個 skill 只處理「是否真的需要問」。shared contract 與 `safe-ops` 仍是安全、完成宣告與權限邊界的
唯一來源。

## 提問前

1. 查最小必要的 local source、spec、git state 或 tool capability。
2. 能由合理預設、可逆 local action 或既有規則決定，就直接做。
3. 只有答案會改變 product intent、permission、destructive/external action、persistent workflow，
   或需要 Miyago 提供的 input 時才保留問題。

若只是兩種都合理的技術實作，選較小且可回復的路徑，說明 assumption，不要把選擇退回給 Miyago。

## 提問格式

- 先說目前 interpretation 與已查到的 evidence。
- 只問一個具體 blocker；需要選擇時提供 2-3 個互斥選項和推薦項。
- 不問「你希望我怎麼做？」這類可由 Agent 自己完成的開放題。

不要因為打出 `？`、`要不要` 或 `可以嗎` 就觸發本 skill；只有問題真的會阻塞工作時才載入它。

## Feedback

不要在每次提問後自動修改本 skill、`.ai/lessons.md` 或其他記錄。只有 Miyago 明確要求記錄，或形成可重用
的 workflow lesson 時，才交給對應的 docs/memory workflow。
