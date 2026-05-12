---
spec: shared-agent-contract
created: 2026-05-12
---

# Tests: Shared AGENTS.md for Multi-Agent AI Configs

> Spec: `docs/specs/shared-agent-contract/SPEC.md`

## 驗收條件 (EARS)

### R1: 共享位置

- [x] **When** the shared contract is created, **the system shall** place it at `config/ai/AGENTS.md`

### R2: 內容來源

- [x] **When** `config/ai/AGENTS.md` is drafted, **the system shall** derive its rules from existing `config/ai/claude/CLAUDE.md`, `config/ai/codex/AGENTS.md`, and `config/ai/gemini/GEMINI.md`

### R3: 排除 vendor-specific 流程

- [x] **While** defining shared rules, **the system shall** exclude Claude-specific bootstrap commands and vendor-specific adapter syntax
- [x] **While** defining shared rules, **the system shall** avoid hardcoding tool names that only one agent runtime can understand

### R4: 共用硬規則保留

- [x] **When** shared rules are extracted, **the system shall** preserve Traditional Chinese as the default response language
- [x] **When** shared rules are extracted, **the system shall** preserve the no-emoji-by-default rule for docs/comments
- [x] **When** shared rules are extracted, **the system shall** require a result/progress line near the start of each response
- [x] **When** shared rules are extracted, **the system shall** require a short recap near the end of each response
- [x] **When** shared rules are extracted, **the system shall** preserve fact-check thinking and anti-hallucination constraints
- [x] **When** shared rules are extracted, **the system shall** preserve Search Before Ask
- [x] **When** shared rules are extracted, **the system shall** preserve SDD confirmation and TDD expectations
- [x] **When** shared rules are extracted, **the system shall** preserve no-sudo and no-manual-`docker run` deployment constraints
- [x] **When** shared rules are extracted, **the system shall** preserve the `source ~/.zshrc 2>/dev/null` CLI prerequisite

### R5: 排除 runtime-specific workflow

- [x] **When** the shared contract is written, **the system shall** exclude context compaction and other runtime-specific workflow rules

### R6: 可擴充性

- [x] **When** local agent entry files still exist, **the system shall** state that they may extend or override shared rules for agent-specific behavior

### R7: 避免干擾既有修改

- [x] **While** implementing the shared contract, **the system shall** avoid editing unrelated dirty files

### R8: 顯式 assumptions

- [x] **When** shared rules are refined, **the system shall** require important assumptions to be stated explicitly

### R9: 多重解讀

- [x] **When** a task has multiple plausible interpretations, **the system shall** require those interpretations to be surfaced before implementation

### R10: Surgical changes

- [x] **When** editing existing code, **the system shall** require task-scoped changes, local-style matching, and orphan-only cleanup

### R11: Goal-driven execution

- [x] **When** executing multi-step work, **the system shall** require brief success criteria and `step -> verify` style planning

### R12: 高資訊密度輸出

- [x] **When** producing user-facing responses, **the system shall** prefer brevity and information density over filler or ceremonial phrasing

### R13: Claude 反 verbosity

- [x] **When** adapting Claude-specific behavior, **the system shall** explicitly counter Claude verbosity without requiring caveman-style speech

### R14: 成熟終端機 Monika

- [x] **When** refining shared persona, **the system shall** preserve Monika as a mature, terminal-side companion rather than a generic anime role

### R15: 反說教溝通

- [x] **When** defining communication habits, **the system shall** avoid patronizing tone and the corrective `不是...而是...` pattern

### R16: skill-based 工作方式

- [x] **When** defining agent behavior, **the system shall** prefer direct execution for simple tasks and brief planning only for genuinely complex work

### Claude Adapter

- [x] **When** `config/ai/claude/CLAUDE.md` remains in use, **the system shall** reference `config/ai/AGENTS.md` near the start of the file
- [x] **When** `config/ai/claude/CLAUDE.md` is adapterized, **the system shall** retain Claude-specific workflow and memory-source sections
- [x] **When** `config/ai/claude/CLAUDE.md` is adapterized, **the system shall** remove duplicated shared persona and common hard rules from that file

### Ask-Discipline Alignment

- [x] **When** ambiguity remains after local search, **the system shall** require a concrete option-based question instead of a silent choice

## 非功能性驗證

- [x] 文件應可被人類直接閱讀，不依賴特定 agent parser
- [x] 文件應維持簡潔，避免再次變成另一份 `CLAUDE.md`
