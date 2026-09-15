---
name: no-ai-attribution
description: "Legacy alias：在 commit task 中將 no-AI-attribution 規則導向 `git-workflow`。"
when_to_use: "舊 prompt 明確呼叫 no-ai-attribution，或需要確認 commit message attribution 時。"
tags: [git, commit, attribution, compatibility]
effort: low
shell: none
runtime-scope: shared-core
alwaysApply: false
---

# No-AI Attribution（相容 alias）

`git-workflow` 已經是 commit safety 與 attribution 的唯一 source。只有舊 prompt
明確呼叫本 skill 時才讀取；不要在這裡建立第二份檢查表。

載入 `git-workflow`，不要在這裡建立第二份 attribution 檢查表。
