---
name: efficiency
description: "在 session 出現重複讀取、無效 retry、冗長輸出或過度確認時，做一次有界的效率檢查。"
when_to_use: "Miyago 明確要求 efficiency audit，或同一類浪費已重複出現並影響目前 task 時。"
tags: [efficiency, audit, context, retries]
effort: low
shell: none
runtime-scope: shared-core
alwaysApply: false
user-invocable: true
---

# Efficiency Audit

只檢查目前 task 的直接浪費：重複讀取、沒有策略改變的 retry、可平行卻串行的獨立操作、無效確認和超出
需求的輸出。不要重新審查整個 session，也不要複製 `search-discipline` 或 `context-prompt-discipline`
的規則。

輸出最多五個 findings，每項包含 evidence 和一個可立即採用的修正。沒有 finding 就回報 clean，不要
為了湊清單添加建議。
