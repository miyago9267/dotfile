---
name: sdd
description: "Codex SDD adapter -- explicit SDD mode only; routine coding should not enter full SDD."
user-invocable: true
when_to_use: "Use only when Miyago explicitly asks for SDD/spec-driven work or a large task needs design approval."
tags: [codex, sdd, spec]
effort: medium
shell: optional
runtime-scope: codex-native
---

# Codex SDD Adapter

Use SDD as an explicit large-task workflow, not as the default coding path.

## Flow

1. Search for a directly relevant `docs/specs/<slug>/SPEC.md` once.
2. If found, read only the relevant `SPEC.md` / `TASKS.md` sections.
3. If missing and the task is large, draft a compact spec and stop for Miyago confirmation.
4. Do not create `.ai/` working-memory files from Codex unless Miyago explicitly asks.

## Non-goals

- Do not create specs for small/medium implementation tasks.
- Do not run Claude bootstrap, handoff, snapshot, or log scripts.
