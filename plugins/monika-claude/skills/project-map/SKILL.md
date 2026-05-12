---
name: project-map
description: Session 開始時自動讀取專案地圖，瞭解目錄結構。永遠生效。
alwaysApply: true
---

# 專案地圖 -- Session 開始自動執行

依序嘗試讀取，找到第一個就讀它：

1. `.ai/PROJECT.md`
2. `.claude/PROJECT.md`
3. `docs/ai/PROJECT.md`

讀完才開始工作。找不到就繼續，不詢問。
