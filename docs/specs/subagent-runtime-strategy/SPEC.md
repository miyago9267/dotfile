---
id: spec-subagent-runtime-strategy
title: Subagent Strategy Across Claude, Codex, and Gemini
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [agents, subagents, claude, codex, gemini]
priority: medium
---

# Subagent Strategy Across Claude, Codex, and Gemini

## Background

`Claude` 與 `Codex` 都支援 subagent，但它們的操作模型不完全相同。

依據 Claude How-To 的 subagents 說明，Claude subagent 比較偏：

- 角色型配置
- 獨立工具權限
- 可自動委派或顯式呼叫
- 可恢復、背景執行、worktree 隔離、甚至 agent teams

而目前這個 Codex 環境的 subagent 是工具層 delegation：

- `spawn_agent`
- `send_input`
- `wait_agent`
- `close_agent`

更偏向「把明確子任務平行外包」而不是維護一棵長期角色樹。

使用者目前要的方向是：

- `Claude` 保留規劃、審查、文件、小改動導向的 subagent 用法
- `Codex` 保留 coding / explorer / worker 導向的 subagent 用法
- `Gemini` 先不主打 heavy subagent，避免過早複製其他 runtime 的模式

## Requirements (EARS)

- **R1**: When `Claude` uses subagents, the system shall prefer role-based delegation such as planning, research, review, and documentation
- **R2**: When `Codex` uses subagents, the system shall prefer bounded parallel subtasks such as codebase exploration, scoped implementation, and targeted verification
- **R3**: When `Codex` delegates, the system shall avoid outsourcing the immediate critical-path task if the parent agent is blocked on the result
- **R4**: When `Claude` delegates, the system shall keep roles non-overlapping and use subagents only when the role separation materially improves focus
- **R5**: When `Gemini` is configured, the system shall not treat heavy subagent usage as a default capability pattern in this phase
- **R6**: When documenting subagent strategy, the configuration shall explain the difference between role-based delegation and task-bounded delegation

## Non-goals

- 不在這一批建立完整的 Gemini subagent 體系
- 不在這一批重寫 Claude `agents/` 目錄全部內容
- 不在這一批把 Codex 實際 subagent 使用自動化

## Architecture

### Claude

- 角色型 subagent
- 適合：`spec-writer`、`researcher`、`code-reviewer`、docs / handoff 類角色
- 可利用背景任務、可恢復、worktree 隔離

### Codex

- 任務型 subagent
- `explorer`：read-only codebase 問題
- `worker`：有明確檔案責任的實作或測試
- 只在平行處理有收益時委派

### Gemini

- 先保守
- 未來若補 subagent，優先走 research / question decomposition / Google specialist

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| 把 Claude 與 Codex 的 subagent 模型混為一談 | medium | 在 runtime adapter 中分別寫清楚 delegation 模型 |
| Codex 過度委派導致主線阻塞 | medium | 明訂 critical path 不外包 |
| Claude 角色太多導致重疊 | medium | 明訂單一角色單一責任 |
