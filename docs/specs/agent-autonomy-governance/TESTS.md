---
spec: agent-autonomy-governance
batch: 1
created: 2026-05-12
---

# Tests: Agent Autonomy Governance for Self-Directed Decisions

> Spec: `docs/specs/agent-autonomy-governance/SPEC.md`

## 驗收條件 (EARS)

### R1: When a task is complex, multi-step, or design-sensitive, the agent shall decide by itself to enter a planning or spec-first workflow before asking Miyago to remind it

- **When**: 檢查 `SPEC.md` 的 requirements 與 capability ownership
- **Shall**: planning / spec-first 被列為 agent-decided
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R4: Before asking Miyago a question, the agent shall verify local files, existing specs, repo state, configured rules, and available tools, then record the concrete blocker rather than asking a generic question

- **When**: 檢查 `SPEC.md` 的 `Pre-Ask Gate`
- **Shall**: 有具體 pre-ask checklist，不接受 generic question
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R6: The system shall treat permission modes, auto mode, scheduled tasks, headless/print mode, remote control, web sessions, desktop app handoff, Chrome integration, channels, worktrees, sandboxing, managed settings, and governance-level configuration as user-controlled decisions

- **When**: 檢查 `Capability Ownership`
- **Shall**: user-controlled feature registry 明確列出這些項目
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R8: Runtime specialization shall bias how autonomy is exercised, but shall not change the top-level autonomy boundary between self-directed decisions and user-controlled decisions

- **When**: 檢查 `Runtime Bias`
- **Shall**: Codex / Claude / Gemini 只有偏向差異，沒有改變 autonomy 邊界
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### R9: The shared contract shall encode a reusable pre-ask checklist and a user-controlled feature registry so future prompts do not need to restate the same boundary

- **When**: 檢查 `config/ai/AGENTS.md`
- **Shall**: 存在 `Autonomy Governance` 段落，且包含 pre-ask flow 與 user-controlled features
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過

### Tone: Claude adapter shall explicitly suppress patronizing, over-explanatory, beginner-assumption speech habits

- **When**: 檢查 `config/ai/claude/CLAUDE.md`
- **Shall**: 明確禁止把使用者當新手、過度教學、安撫式技術口吻
- **驗證方式**: 文字審查
- **狀態**: [ ] 未驗證 / [x] 通過
