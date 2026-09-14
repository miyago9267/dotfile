---
name: prototype
description: "Codex throwaway prototype workflow：建立小型 disposable experiments，回答具體的 design、state 或 UI question。Miyago 要 prototype、sanity-check model、嘗試 UI options、探索 state machine，或在 production code 前快速試作時使用。"
user-invocable: true
when_to_use: "從 runnable experiment 學習，比一開始就設計 final implementation 更省成本時使用。"
tags: [codex, prototype, experiment, ui, state]
effort: medium
shell: preferred
runtime-scope: codex-native
---

# Codex Prototype（原型）

Prototype 只回答一個 question。從第一個 file 開始就把它視為 disposable。

## 選擇 Prototype Type

- **Logic/state question**：建立 tiny CLI 或 script 操作 model，並在每個 action
  後印出完整 state。
- **UI question**：建立 temporary route、page 或 component，用 simple switch
  切換 2-4 個明確 variants。

在 prototype file 頂端或旁邊的 note 寫明 question。

## 規則（Rules）

- Prototype code 放在相關 module 或 route 附近，名稱使用 `prototype`、`scratch`
  或等效的 local convention。
- 使用 repo 既有的 runtime 與 routing conventions。
- 提供一個 command 或 URL 來執行。
- 除非 question 本身是 persistence，否則將 persistence 留在 memory。
- 跳過 production polish、broad tests 與 abstractions。
- Render 或 print 足夠的 state，讓 Miyago 能判斷結果。
- 完成後刪除 prototype，或把已驗證的 decision 合併進 production code。

## 驗證（Verification）

執行能證明 prototype 啟動並走過 key path 的最低成本 command。UI prototype 只有
在 Miyago 要求 browser verification，或 UI behavior 無法從 code 判斷時，才用
Browser/Playwright。

## 記錄結果（Capture The Result）

Prototype 回答 question 後，把 decision 記錄在符合 task 的 durable location：

- commit message
- issue/spec note
- 難以回復的 architectural choice 使用 ADR
- Prototype 必須短暫保留時，在旁邊放簡短 `NOTES.md`
