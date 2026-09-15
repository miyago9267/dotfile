---
name: search-discipline
description: "在需要搜尋未知 code path 或可能產生大量 context 時，選最小的 rg/find/read 方法並限制輸出。"
when_to_use: "未知路徑、跨目錄探索、large logs/transcripts 或可能超過 context budget 的搜尋。"
tags: [search, rg, find, context, budget]
effort: low
shell: none
runtime-scope: shared-core
alwaysApply: false
---

# Search Discipline

- 已知檔名或 pattern：直接 `rg --files`；已知 keyword：`rg -n`；已知檔案：讀相關區間。
- 先做一輪 bounded anchor search，再讀會改變決策的片段；不要反覆掃同一棵樹。
- 大輸出先做 count、top-N 或 summary；排除 cache、generated、node_modules、logs 和不相關 project。
- 只有單純工具無法收斂 3+ 輪搜尋時才用 Explore/scout，brief 必須寫 scope、stop、output cap。

這是搜尋方法，不負責 completion、efficiency audit 或提問決策；那些規則各由 shared contract 與對應 skill
處理。
