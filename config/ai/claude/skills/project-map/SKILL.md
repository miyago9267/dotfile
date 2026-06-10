---
name: project-map
description: Auto-read the project map at session start to learn the directory layout. Always on.
alwaysApply: true
when_to_use: "Entering a new repo, switching cwd, or re-orienting after compact."
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
