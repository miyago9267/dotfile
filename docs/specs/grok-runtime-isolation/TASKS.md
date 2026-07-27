---
spec: grok-runtime-isolation
batch: 1
created: 2026-07-22
---

# Tasks: Grok Runtime Isolation

## Implementation

- [x] Record the native / compatibility / strict-isolation boundary.
- [x] Add native and compatibility launcher sources.
- [x] Extend `setup_grok.sh` to install launchers safely and idempotently.
- [x] Document launcher usage and the `.claude/agents` compatibility gap.

## Verification

- [x] Run shell syntax and static checks.
- [x] Verify native inspect excludes Claude instructions and agents.
- [x] Verify compatibility inspect remains available.
- [x] Verify repeated setup does not overwrite user state.
- [x] Update `PROGRESS.md` and changelog.
