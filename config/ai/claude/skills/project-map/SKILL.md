---
name: project-map
description: Session start 時自動讀取 project map，了解 directory layout。永遠生效。
alwaysApply: true
when_to_use: "進入新 repo、切換 cwd，或 compact 後重新定位時。"
tags: [project-map, repo, structure, bootstrap, context]
effort: low
shell: optional
runtime-scope: claude-native
---

# 專案地圖 -- Session 開始自動執行

依序嘗試讀取，找到第一個就讀它：

1. `.ai/PROJECT.md`
2. `.claude/PROJECT.md`
3. `docs/ai/PROJECT.md`

讀完才開始工作。找不到就繼續，不詢問。
