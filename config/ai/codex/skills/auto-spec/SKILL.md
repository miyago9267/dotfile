---
name: auto-spec
description: "Codex spec gate -- only use spec tracking for large, cross-module, or architecture-changing tasks."
user-invocable: true
when_to_use: "Use when the task clearly needs a committed docs/specs plan before implementation."
tags: [codex, spec, sdd, budget]
effort: low
shell: optional
runtime-scope: codex-native
---

# Codex Spec Gate

Codex should not create or scan specs for routine implementation work.

## Use spec only when

- The task is large, cross-module, architecture-changing, or product-behavior-changing.
- Miyago explicitly asks for SDD/spec/planning.
- An existing active spec is already named or clearly relevant.

## Skip spec when

- The task is a small/medium patch, review, refactor, config edit, text edit, or single-file change.
- The invocation is `codex exec` second opinion or snippet review.
- The runtime budget is Fast or Medium.

## Budget

- Search `docs/specs` at most once before deciding.
- If no obvious active spec is found, proceed without spec and mention that no spec was used.
