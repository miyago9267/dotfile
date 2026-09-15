---
name: sdd
description: "Codex SDD adapter：只在明確指定時進入 SDD mode；routine coding 不進入完整 SDD。"
user-invocable: true
when_to_use: "只有 Miyago 明確要求 SDD/spec-driven work，或 large task 需要 design approval 時使用。"
tags: [codex, sdd, spec]
effort: medium
shell: optional
runtime-scope: codex-native
---

# Codex SDD Adapter（規格驅動開發）

SDD 是明確指定的 large-task workflow，不是 default coding path。

## 流程（Flow）

1. 搜尋一次直接相關的 `docs/specs/<slug>/SPEC.md`。
2. 找到後只讀相關的 `SPEC.md`／`TASKS.md` sections。
3. Task 很大且找不到時，草擬 compact spec，停下等待 Miyago confirmation。
4. 除非 Miyago 明確要求，不要從 Codex 建立 `.ai/` working-memory files。

## 不在目標內（Non-goals）

- 不要為 small/medium implementation tasks 建立 specs。
- 不要執行 Claude bootstrap、handoff、snapshot 或 log scripts。
