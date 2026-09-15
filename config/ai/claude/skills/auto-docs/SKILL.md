---
name: auto-docs
description: "在使用者要求保存 session、handoff、lesson、changelog 或 durable summary 時，整理最小必要的文件。"
when_to_use: "需要明確寫入工作記錄、跨 session handoff 或發布摘要時。"
tags: [docs, handoff, changelog, summary]
effort: low
shell: preferred
runtime-scope: shared-core
alwaysApply: false
---

# Auto Documentation

預設不寫 `.ai/`，也不為每個 command、read 或小修改建立記錄。

啟用後只做目前要求的記錄：

- session／scope 切換：更新 `CURRENT.md` 或 `HANDOFF.md`。
- 明確要求 lesson／changelog：先查最後幾行去重，再寫一行。
- durable summary 或發布文件：只使用 current source、accepted state 與 direct evidence。

不要為了產生記錄而讀完整 `.ai/`、所有 specs 或所有 session。`.ai/` 不加入 commit；需要提交的 spec 或
docs 依 repo 的 SDD workflow 處理。
