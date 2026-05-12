---
spec: agent-runtime-specialization
batch: 1
created: 2026-05-12
---

# Tests: Runtime Specialization and Isolation for Codex, Claude, and Gemini

> Spec: `docs/specs/agent-runtime-specialization/SPEC.md`

## 驗收條件 (EARS)

### R2: When `Codex` is configured, the adapter shall bias toward software implementation, code changes, local verification, and engineering execution

- **When**: 檢查 `config/ai/codex/AGENTS.md`
- **Shall**: 有明確 coding-first 偏向
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R3: When `Claude` is configured, the adapter shall bias toward planning, specification work, orchestration, documentation, and small targeted edits

- **When**: 檢查 `config/ai/claude/CLAUDE.md`
- **Shall**: 有明確 planner / spec / small-change 偏向
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R4: When `Gemini` is configured, the adapter shall bias toward clarifying questions, research assistance, and Google ecosystem workflows

- **When**: 檢查 `config/ai/gemini/GEMINI.md`
- **Shall**: 有明確 question / research / Google 偏向
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R8: When `setup_codex.sh` and `setup_gemini.sh` provision skills, they shall install only approved shared-core skills plus each runtime's native skills

- **When**: 檢查 setup scripts
- **Shall**: 不再整包 symlink `config/ai/claude/skills/`
- **驗證方式**: 腳本文字審查
- **狀態**: [ ] 未驗證 / [x] 通過
