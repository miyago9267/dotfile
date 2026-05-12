---
spec: subagent-runtime-strategy
batch: 1
created: 2026-05-12
---

# Tests: Subagent Strategy Across Claude, Codex, and Gemini

> Spec: `docs/specs/subagent-runtime-strategy/SPEC.md`

## 驗收條件 (EARS)

### R1: When `Claude` uses subagents, the system shall prefer role-based delegation such as planning, research, review, and documentation

- **When**: 檢查 `config/ai/claude/CLAUDE.md`
- **Shall**: 有 role-based delegation 規則
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R2: When `Codex` uses subagents, the system shall prefer bounded parallel subtasks such as codebase exploration, scoped implementation, and targeted verification

- **When**: 檢查 `config/ai/codex/AGENTS.md`
- **Shall**: 有 `explorer` / `worker` 與 bounded delegation 規則
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R5: When `Gemini` is configured, the system shall not treat heavy subagent usage as a default capability pattern in this phase

- **When**: 檢查 `config/ai/gemini/GEMINI.md`
- **Shall**: 有保守方針
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過
