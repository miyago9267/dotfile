---
name: project-map
description: Session 開始時自動讀取專案地圖，瞭解目錄結構。永遠生效。
alwaysApply: true
when_to_use: "進入新 repo、切換工作目錄或 compact 後需要快速重新掌握專案結構時。"
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
