---
name: auto-spec
description: "Codex spec gate：只在 large、cross-module 或 architecture-changing task 使用 spec tracking。"
user-invocable: true
when_to_use: "Task 明確需要在 implementation 前提交 docs/specs plan 時使用。"
tags: [codex, spec, sdd, budget]
effort: low
shell: optional
runtime-scope: codex-native
---

# Codex Spec Gate（規格閘門）

Routine implementation work 不應由 Codex 建立或掃描 specs。

## 只有這些情況使用 spec

- Task 是 large、cross-module、architecture-changing 或 product-behavior-changing。
- Miyago 明確要求 SDD/spec/planning。
- 已經指定或明確相關的 existing active spec。

## 這些情況跳過 spec

- Task 是 small/medium patch、review、refactor、config edit、text edit 或
  single-file change。
- Invocation 是 `codex exec` second opinion 或 snippet review。
- Runtime budget 是 Fast 或 Medium。

## 預算（Budget）

- 決定前最多搜尋一次 `docs/specs`。
- 找不到明顯的 active spec 時，不使用 spec 繼續，並說明本次沒有使用 spec。
