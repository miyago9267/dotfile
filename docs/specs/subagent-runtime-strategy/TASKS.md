---
spec: subagent-runtime-strategy
batch: 1
created: 2026-05-12
---

# Tasks: Subagent Strategy Across Claude, Codex, and Gemini

> Spec: `docs/specs/subagent-runtime-strategy/SPEC.md`
> Batch: 1

## 前置條件

- [x] 讀取 Claude subagents 參考文章
- [x] 讀取目前 Codex runtime 的 subagent 工具模型

## 實作步驟

- [x] 建立三個 runtime 的 subagent strategy spec
- [x] 將 Codex subagent 使用原則寫入 adapter
- [x] 將 Claude subagent 使用原則寫入 adapter
- [x] 將 Gemini 的保守方針寫入 adapter

## 驗證

- [x] `Codex` adapter 已區分 `explorer` / `worker`
- [x] `Claude` adapter 已表達 role-based delegation
- [x] `Gemini` adapter 已表達暫不主打 heavy subagent

