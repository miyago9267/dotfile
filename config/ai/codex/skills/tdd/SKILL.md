---
name: tdd
description: "Codex risk-based testing -- use TDD for high-risk behavior; otherwise prefer targeted verification."
user-invocable: true
when_to_use: "Use when a bug fix or behavior change benefits from a failing test first."
tags: [codex, tdd, tests, verification]
effort: medium
shell: optional
runtime-scope: codex-native
---

# Codex Risk-Based Testing

Prefer targeted verification over automatic full TDD.

## Use TDD for

- Reproducible bug fixes.
- Public API or core business logic changes.
- Security, auth, finance, data migration, or high-risk logic.

## Patch first, then verify for

- Small UI/text/config/script changes.
- Mechanical refactors with obvious local checks.
- Second opinion or review-only tasks.

## Budget

- Find the test command with at most one focused search.
- Run targeted tests first; do not run full suites unless the touched area requires it.
- Report tests run and unverified risk.
