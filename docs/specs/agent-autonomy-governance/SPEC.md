---
id: spec-agent-autonomy-governance
title: Agent Autonomy Governance for Self-Directed Decisions
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [agents, autonomy, governance, claude, codex, gemini]
priority: high
---

# Agent Autonomy Governance for Self-Directed Decisions

## Background

Miyago 的核心目標不是讓 agent 擁有更多功能，而是讓 agent 在回頭詢問之前，先把自己能做的判斷做完。

目前規則已經有：

- shared `AGENTS.md`
- runtime specialization
- automation routing
- Claude hooks
- spec / progress / task tracking

但還缺少一份明確的 autonomy contract，去定義：

1. 哪些高級能力應由 agent 自己判斷是否使用
2. 哪些能力涉及權限、排程、外部入口或長期副作用，必須由使用者保留決策權
3. agent 在「回頭問 Miyago」之前，必須先完成哪些內部檢查

這份 spec 以 `claude-howto` 的 advanced features 分類為外部參考，並與目前自建 shared contract 對齊。

## Goals

- 降低使用者手動提醒「先規劃」「先深想」「先自己查」的頻率
- 把 agent 的自主管理能力收斂成可驗證規則
- 把「何時可以問使用者」從模糊習慣變成明確 gate
- 讓 Claude / Codex / Gemini 在不同 runtime 中，都能遵守相同的 autonomy 邊界

## Non-goals

- 不在這一批直接改權限模式或自動切換 permission mode
- 不在這一批自動啟用 loop / schedule / remote control / web session
- 不在這一批重寫所有 runtime 的完整 prompt
- 不在這一批引入新的外部服務

## Requirements (EARS)

- **R1**: When a task is complex, multi-step, or design-sensitive, the agent shall decide by itself to enter a planning or spec-first workflow before asking Miyago to remind it
- **R2**: When a task involves uncertainty that can be reduced by deeper reasoning, the agent shall decide by itself to spend more internal effort before asking Miyago for clarification
- **R3**: When a task can progress via background execution, task tracking, context reconstruction, or prompt suggestions, the agent shall manage those mechanisms without requiring Miyago to manually prompt them
- **R4**: Before asking Miyago a question, the agent shall verify local files, existing specs, repo state, configured rules, and available tools, then record the concrete blocker rather than asking a generic question
- **R5**: When multiple implementation paths remain valid after local verification, the agent shall ask only if the tradeoff changes product intent, permissions, destructive impact, persistent scheduling, or long-term workflow governance
- **R6**: The system shall treat permission modes, auto mode, scheduled tasks, headless/print mode, remote control, web sessions, desktop app handoff, Chrome integration, channels, worktrees, sandboxing, managed settings, and governance-level configuration as user-controlled decisions
- **R7**: When the agent recommends a user-controlled feature, it shall explain the reason and request explicit confirmation before activation
- **R8**: Runtime specialization shall bias how autonomy is exercised, but shall not change the top-level autonomy boundary between self-directed decisions and user-controlled decisions
- **R9**: The shared contract shall encode a reusable pre-ask checklist and a user-controlled feature registry so future prompts do not need to restate the same boundary

## Capability Ownership

### Agent-decided by default

- planning mode / spec-first decomposition
- deeper internal reasoning / higher effort
- background tasks without risky side effects
- session management and context reconstruction
- task list maintenance and progress tracking
- prompt suggestions / next-step inference
- hook / skill / MCP routing
- subagent usage inside runtime-specific delegation policy

### User-controlled by default

- permission mode changes
- auto mode enablement
- scheduled or recurring tasks
- print / headless mode used as workflow architecture
- remote control and browser/web/desktop session entry
- channels or push-style external messaging
- git worktrees that alter workspace layout
- sandbox, managed settings, and governance-level configuration

### Shared decision boundary

- destructive operations with lasting side effects
- actions requiring new credentials, root, or policy changes
- ambiguous branches with materially different cost or product meaning
- cross-runtime architecture shifts

## Decision Ladder

The agent shall follow this order before asking Miyago:

1. read local facts
2. check active spec / progress / previous decisions
3. apply shared contract and runtime adapter rules
4. use deterministic hooks if available
5. use the most relevant skill
6. use MCP or external tooling if live state is required
7. use subagent or background execution if the work is parallelizable
8. increase internal reasoning effort if the blocker is conceptual
9. ask Miyago only if the blocker survives all previous steps

## Pre-Ask Gate

Every user-facing question from the agent should be justifiable by all of the following:

- the question cannot be answered from local repo or configured context
- the answer changes execution materially
- the answer is not already captured in spec or shared rules
- the decision is not safely automatable
- the question names the exact blocker or tradeoff

Questions that fail this gate should be replaced with self-directed action.

## Runtime Bias

### Codex

- default to implementation, debugging, tests, verification, and bounded delegation
- ask fewer workflow questions; prefer proving the path with code or local checks

### Claude

- default to planning, specification, documentation, orchestration, and small targeted edits
- ask only when the task needs intent confirmation, not because the workflow itself is unclear

### Gemini

- default to clarifying research, external information gathering, and Google ecosystem workflows
- ask to refine intent when search space is wide, but still complete local verification first

## Planned Changes

### Phase 1

- create this autonomy governance spec
- define the pre-ask gate
- define the user-controlled feature registry

### Phase 2

- update shared `config/ai/AGENTS.md` with an `Autonomy Governance` section
- align Claude / Codex / Gemini adapters with the same boundary
- add lightweight validation language to skill authoring guidance

### Phase 3

- audit high-frequency skills and hooks against the new pre-ask gate
- trim any rules that still encourage generic clarification questions

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| agent 過度自信，不該自決的也自己決定 | high | user-controlled feature registry 明確列管，且要求顯式確認 |
| 規則過重，導致 agent 為了遵守流程變慢 | medium | pre-ask gate 保持短小，只做高價值檢查 |
| 三個 runtime 對 autonomy 的語氣不同，造成漂移 | medium | shared contract 寫死邊界，runtime 只調整偏向 |
| 「深想」被寫成空話，沒有可執行約束 | medium | 把 deeper reasoning 綁定到 blocker reduction，而不是口號 |

## References

- `config/ai/AGENTS.md`
- `docs/specs/automation-routing-hardening/SPEC.md`
- `docs/specs/agent-runtime-specialization/SPEC.md`
- `docs/specs/subagent-runtime-strategy/SPEC.md`
- `https://github.com/luongnv89/claude-howto/blob/main/zh/09-advanced-features/README.md`
