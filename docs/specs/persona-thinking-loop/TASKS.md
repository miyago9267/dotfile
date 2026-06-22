---
spec: persona-thinking-loop
batch: 1
created: 2026-06-22
---

# Tasks: Persona Rewrite, Think-First Mechanism, Loop Engineer

> Spec: `docs/specs/persona-thinking-loop/SPEC.md`
> Batch: 1

## 前置條件

- [x] Spec 已獲 Miyago 核准 (goal phase1/2/3 set)
- [x] Claude Code >= 2.1.154 (actual 2.1.185) confirmed

## Phase 1: Persona layer rewrite

- [x] Rewrite `hooks/persona-reminder.sh` with condensed communication rules
- [x] Rewrite AGENTS.md Persona + Communication sections; remove mandatory recap (ADR-3)
- [x] Trim `memories/feedback-global.md` duplicated/contradictory lines to references

## Phase 2: Think-first mechanism + effort routing

- [x] Add `hooks/think-first-router.sh` (UserPromptSubmit), fail-open, keyword-gated
- [x] Register hook in `settings.json` UserPromptSubmit
- [x] Add think-first protocol + effort-routing table to CLAUDE.md
- [x] Verify hook does not fire on trivial prompts (typo/rename)

## Phase 3: Loop Engineer

- [x] Create `~/.claude/loop.md` default Loop Engineer prompt (repo + symlink + setup_claude.sh)
- [x] Add `/loop` vs `/goal` vs `/schedule` decision table to CLAUDE.md

## 驗證

- [ ] All steps complete
- [ ] Tests pass (see TESTS.md)
- [ ] Docs updated

## 備註

<!-- Batch 完成後用 spec-archive.sh tasks persona-thinking-loop 封存 -->
