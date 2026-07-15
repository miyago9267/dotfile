---
id: spec-coralline-codex-quota
title: Coralline Codex App-Server Quota Integration
status: implemented
created: 2026-07-13
updated: 2026-07-13
author: Miyago
tags: [coralline, remora, codex, security]
priority: high
---

# Coralline Codex App-Server Quota Integration

## Background

The prior REMORA quota bridge used a local credentialed integration that is unsuitable for a public Coralline release. Coralline must instead query the official OpenAI Codex app-server stdio protocol and let Codex own OAuth and credential handling.

## Requirements (EARS)

- **R1**: When `REMORA_ACTIVE=1` and both native Claude rate-limit windows are absent, the statusline shall invoke a local Codex quota provider; otherwise it shall not start Python or Codex.
- **R2**: When refreshing quota, the provider shall launch an absolute executable resolved from `CORALLINE_CODEX_BINARY` or `PATH`, use `codex app-server --stdio`, complete `initialize` / `initialized` / `account/rateLimits/read` sequentially under a bounded timeout, and terminate the child reliably without `shell=True`.
- **R3**: When Codex returns rate-limit windows, the provider shall map 300 minutes to 5h and 10080 minutes to 7d, use direct `usedPercent`, validate percentages and integer reset epochs, support one window, and never duplicate a known 7d window into 5h.
- **R4**: When cached normalized quota is at most 60 seconds old, the provider shall return it without starting Codex; when refresh fails, it may return validated cache at most 900 seconds old.
- **R5**: While managing cache and lock state, the provider shall use `${XDG_CACHE_HOME:-~/.cache}/coralline`, atomic cache replacement, directory mode 0700, file mode 0600, nonblocking lock acquisition, and stale empty-lock recovery.
- **R6**: Where Coralline is installed locally, upgraded, or bootstrapped remotely, `codex-quota.py` shall be included and executable, and `remora-quota.sh` shall not be packaged.
- **R7**: The provider and documentation shall not read, request, cache, or expose third-party credentials, trust opt-ins, or a Coralline-managed network quota API.
- **R8**: When a live isolated-cache REMORA render uses the official Codex app-server, the current known 7d-only response shall render only the 7d segment and leave 5h absent.

## Non-goals

- No provider plugin framework, generic command hook, daemon, broker, or network management API.
- No changes to native Claude rate-limit parsing or unrelated Coralline rendering behavior.
- No credential discovery or OAuth implementation in Coralline.

## Alternatives Considered

### Prior local quota bridge

Rejected because it does not meet public-release trust-boundary requirements.

### Long-running quota daemon or broker

Rejected because the 60-second cache already bounds process cost and a daemon adds lifecycle and attack-surface complexity.

## Rabbit Holes

1. Do not infer a 5h window from a duration-tagged 7d primary window.
2. Do not cache the raw app-server response, account identifiers, plan metadata, or credentials.
3. Do not spawn the provider on native Claude renders.
4. Do not wait on a live lock; use stale cache or fail closed for that render.

## Architecture

`statusline.sh` conditionally executes sibling `codex-quota.py`. The provider returns four unit-separator-delimited normalized fields: 5h used/reset and 7d used/reset. It owns the cache and lock, launches Codex only on a cache miss, performs the JSONL handshake over pipes, extracts only normalized windows, atomically caches those fields, and terminates the child before exiting.

## ADR

### ADR-1: Use official Codex app-server stdio

- Decision: Query `account/rateLimits/read` through a short-lived `codex app-server --stdio` process.
- Reason: Codex retains sole responsibility for OAuth and credentials; Coralline receives only quota data over a local child-process pipe.

### ADR-2: Keep quota normalization in one Python provider

- Decision: Use a Python 3.11 executable with standard-library-only protocol, timeout, cache, and lock handling.
- Reason: Python provides portable bounded I/O and reliable subprocess cleanup without expanding the shell renderer.

### ADR-3: Cache only normalized quota

- Decision: Store fetch time plus nullable 5h/7d used/reset values in a private JSON file.
- Reason: Stale fallback needs no raw response or account metadata.

## Phase Plan

### Phase 1: Provider and shell integration

- Replace the management helper with `codex-quota.py` and a small conditional statusline call.

### Phase 2: Packaging, tests, and public documentation

- Update install paths, fake app-server tests, security documentation, and live verification.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Codex protocol shape changes | Quota temporarily disappears | Strict parsing, stale cache, focused fake-protocol tests |
| Codex child hangs or emits malformed JSON | Statusline delay or leaked process | Total timeout and terminate/kill cleanup |
| Cache or lock corruption | Incorrect or blocked quota | Exact schema validation, atomic replacement, stale empty-lock recovery |
| PATH resolves an unintended binary | Arbitrary local executable runs | Explicit override must be absolute/executable; PATH behavior remains standard and documented |
