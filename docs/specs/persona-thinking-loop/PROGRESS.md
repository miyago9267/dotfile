---
spec: persona-thinking-loop
created: 2026-06-22
---

# Progress: Persona Rewrite, Think-First Mechanism, Loop Engineer

> Spec: `docs/specs/persona-thinking-loop/SPEC.md`

## Phase 1: Persona layer rewrite

> Status: completed

- 目標：runtime-visible human-voice rules; resolve recap conflict; trim duplicated memory.
- Done: persona-reminder.sh rewritten; AGENTS.md Communication condensed 14->10, recap removed; feedback-global pointer updated.

## Phase 2: Think-first mechanism + effort routing

> Status: completed

- 目標：UserPromptSubmit think-first router (fail-open, keyword-gated) + effort-routing table.
- Done: think-first-router.sh added + registered; tested heavy/trivial/garbage/empty all pass; effort-routing table in CLAUDE.md (ADR-2 honest ceiling).

## Phase 3: Loop Engineer

> Status: completed

- 目標：`~/.claude/loop.md` default prompt + `/loop` vs `/goal` vs `/schedule` decision table.
- Done: loop.md created in repo, symlinked to ~/.claude, registered in setup_claude.sh; decision table in CLAUDE.md.

---

## Completed Phases

<!-- Phase 完成後用 spec-archive.sh phase persona-thinking-loop 將 phase block 搬到 archive/ -->
