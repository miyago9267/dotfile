---
spec: agent-autonomy-governance
created: 2026-05-12
---

# Progress: Agent Autonomy Governance for Self-Directed Decisions

> Spec: `docs/specs/agent-autonomy-governance/SPEC.md`

## Phase 1: 邊界定義

> Status: completed

- 目標：把 agent 自主決策與使用者保留決策權的邊界寫成單獨 spec
- Batch 1：advanced features 對照、capability ownership、pre-ask gate、runtime bias

## Phase 2: Shared Contract 對齊

> Status: completed

- 目標：把 autonomy governance 寫回 shared `AGENTS.md`

## Phase 3: Runtime 與 Skill 對齊

> Status: completed

- 目標：讓 Claude / Codex / Gemini adapter 與高頻 skills 一致採用同一條 pre-ask gate
- Batch 2：shared contract、三個 runtime adapter 與高頻 skills 已收斂；低風險 local task 不再因常駐 skill 觸發重複檢查或確認
