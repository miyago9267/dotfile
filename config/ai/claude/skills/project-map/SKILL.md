---
name: project-map
description: "當 current repo 結構不明、切換 cwd 或 compact 後需要重新定位時，找一份最相關的 project map。"
when_to_use: "無法從 cwd、git root 或已知路徑判斷工作位置時。"
tags: [project-map, repo, structure, bootstrap]
effort: low
shell: optional
runtime-scope: claude-native
alwaysApply: false
---

# Project Map

只在結構不明時依序找第一個存在的 map：`.ai/PROJECT.md`、`.claude/PROJECT.md`、`docs/ai/PROJECT.md`。
若 task 已給出 repo、canonical path 或明確檔案，不讀 map；找不到也直接使用已有 local facts，不提問。
