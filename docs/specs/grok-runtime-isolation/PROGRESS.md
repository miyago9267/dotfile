---
spec: grok-runtime-isolation
created: 2026-07-22
---

# Progress: Grok Runtime Isolation

## Phase 1: Native / compatibility boundary

> Status: completed

- Confirmed `GROK_HOME` alone does not isolate Claude discovery.
- Confirmed an alternate process `HOME` removes home-level Claude instructions
  and agents while retaining the real `GROK_HOME` state.

## Phase 2: Launcher implementation

> Status: completed

- Added `grok-native` with isolated process `HOME` and Claude compatibility
  environment overrides.
- Added `grok-compat` as an explicit compatibility escape hatch.
- Setup preserves existing Grok and Claude state and is idempotent.

## Phase 3: Verification

> Status: completed

- Native inspect excludes Claude instructions and agents while retaining the
  Grok adapter.
- Compatibility inspect still exposes the existing Claude surface.
- Shell syntax, ShellCheck, idempotence, and `git diff --check` pass.
