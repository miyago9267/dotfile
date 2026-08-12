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

## Test Quality

- Test observable behavior through public interfaces.
- Name tests with the project's domain vocabulary when available.
- Prefer integration-style seams that exercise real call paths.
- Avoid tests coupled to private methods, internal helper names, or incidental
  data shape.
- Use mocks only at true external boundaries or slow/unreliable dependencies.

## Red-Green Loop

- Work one vertical slice at a time: one behavior, one failing test, one minimal
  implementation.
- Do not write all tests first and then all implementation.
- Keep each new test focused on what the previous cycle taught.
- Refactor only when green.

## Budget

- Find the test command with at most one focused search.
- Run targeted tests first; do not run full suites unless the touched area
  requires it.
- Report tests run and unverified risk.
