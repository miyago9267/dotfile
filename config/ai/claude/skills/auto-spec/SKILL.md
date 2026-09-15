---
name: auto-spec
description: "在 cross-module、architecture-changing、product-behavior-changing 或明確要求 spec 的工作中，建立最小規格與進度追蹤。"
when_to_use: "需要設計決策、跨檔案 acceptance 或 spec/progress gate 時。"
tags: [spec, sdd, progress, architecture]
effort: low
shell: optional
runtime-scope: shared-core
alwaysApply: false
user-invocable: true
---

# Auto Spec

## 觸發邊界

- 觸發：cross-module、architecture-changing、product-behavior-changing，或
  Miyago 明確要求 SDD/spec。
- 跳過：單一、局部、可逆的 code/config/docs/prompt edit；不要因 file count 或「中型」標籤單獨觸發。

觸發後只讀與目前 task 相關的 active spec sections。沒有 spec 時建立最小 `docs/specs/<slug>/SPEC.md`，
再依現有 host 的 material approval gate 執行；明確的 user request 已經授權的 local repository scope
不需再次確認。

## Tracking

- spec 放需求、決策與 acceptance；`PROGRESS.md` 只記 phase 狀態。只有 repo 已採用 `TASKS.md`／`TESTS.md`
  時才同步它們。
- 只在 design change、phase milestone 或 user 要求時更新 progress；不要每個 operation 寫 `.ai/`。
- commit 前檢查對應 spec 是否已反映 final state、`.ai/` 是否未被加入，以及 commit message 是否符合
  `git-workflow` 的格式。
