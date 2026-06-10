---
description: "SDD + TDD development rules. Apply to every non-trivial task."
always_apply: true
---

# Development Rules

## SDD (hard rules)

1. Non-trivial tasks: find or create a spec (`docs/specs/<slug>/SPEC.md`) before implementing.
2. Never re-ask decisions already recorded in the spec.
3. Never skip the spec and jump into a mid/large implementation; wait for user confirmation before starting one.
4. After implementing, update `PROGRESS.md` checkboxes; `SPEC.md` changes only on design changes.

## TDD (strong default)

1. Tests first for new features, bugfixes, refactors: Red -> Green -> Refactor.
2. Coverage target 80%+; 100% for finance/auth/security logic.
3. If skipping TDD, state why.
4. Always report: tests added? executed? what remains unverified?

## Combined Flow

spec found/created -> requirements & plan confirmed -> user confirms -> RED failing test -> GREEN minimal impl -> REFACTOR -> repeat -> update PROGRESS.md / changelog.

## General

1. Concise and direct; no over-engineering.
2. Change only what was asked; no speculative design for hypothetical futures.
3. Security first (OWASP Top 10).
4. Every implementation reports blast radius and test status.
