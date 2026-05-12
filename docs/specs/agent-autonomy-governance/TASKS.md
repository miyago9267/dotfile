---
spec: agent-autonomy-governance
batch: 1
created: 2026-05-12
---

# Tasks: Agent Autonomy Governance for Self-Directed Decisions

> Spec: `docs/specs/agent-autonomy-governance/SPEC.md`
> Batch: 1

## 前置條件

- [x] 讀取 shared `config/ai/AGENTS.md`
- [x] 讀取 `docs/specs/automation-routing-hardening/SPEC.md`
- [x] 讀取 `docs/specs/agent-runtime-specialization/SPEC.md`
- [x] 讀取 `docs/specs/subagent-runtime-strategy/SPEC.md`
- [x] 對照 advanced features 來源文章

## Phase 1: Spec

- [x] 定義 agent-decided 與 user-controlled 的能力邊界
- [x] 定義 pre-ask gate
- [x] 定義 runtime bias 與 shared autonomy boundary 的關係
- [x] 記錄後續要同步到 shared contract 的項目

## Phase 2: 待確認後實作

- [x] 更新 `config/ai/AGENTS.md`
- [x] 對齊 `config/ai/codex/AGENTS.md`
- [x] 對齊 `config/ai/claude/CLAUDE.md`
- [x] 對齊 `config/ai/gemini/GEMINI.md`
- [x] 對齊 Claude feedback memory 的 autonomy / tone 偏好
- [ ] 檢查高頻 skills 是否需要補 autonomy wording

## 驗證

- [x] spec 能清楚區分 self-directed 與 user-controlled features
- [x] pre-ask gate 條件可被文字審查
- [x] 與現有 automation routing / runtime specialization 沒有衝突
