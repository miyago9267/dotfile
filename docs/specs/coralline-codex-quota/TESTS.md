---
spec: coralline-codex-quota
batch: 1
created: 2026-07-13
---

# Tests: Coralline Codex App-Server Quota Integration

> Spec: `docs/specs/coralline-codex-quota/SPEC.md`

## Acceptance Criteria (EARS)

### R1: Native bypass

- **When**: Native Claude rate limits are present, with or without `REMORA_ACTIVE=1`.
- **Shall**: Output stays byte-identical and neither Python provider nor Codex starts.
- **Verification**: Compare renders and assert the fake app-server log remains absent.
- **Status**: [x] Verified

### R2-R3: Protocol and mapping

- **When**: A fake app-server completes the official handshake and returns 7d-only or 5h+7d quota.
- **Shall**: The provider emits direct normalized values with correct duration mapping and child cleanup.
- **Verification**: Focused provider and renderer tests.
- **Status**: [x] Verified

### R4-R5: Cache and lock

- **When**: Cache is fresh, stale, expired, malformed, or guarded by recent/stale locks.
- **Shall**: Fresh cache avoids Codex, stale cache is fallback-only, expired/malformed data is rejected, lock handling never waits, and modes remain 0700/0600.
- **Verification**: Focused cache and lock tests.
- **Status**: [x] Verified

### R6-R7: Packaging and trust boundary

- **When**: Local install, upgrade, and file-based remote bootstrap run.
- **Shall**: The executable provider is installed and no legacy credential or trust artifact remains.
- **Verification**: Upgrade integration and repository scans.
- **Status**: [x] Verified

### R8: Live app-server

- **When**: A live isolated-cache REMORA render queries the user's current Codex app-server.
- **Shall**: It renders the current 7d window only and leaves 5h absent.
- **Verification**: Authorized live test plus process/cache inspection.
- **Status**: [x] Verified

## Test Cases

### Normal Paths

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1 | 7d-only tagged response | Empty 5h; direct 7d used/reset | [x] |
| 2 | Tagged 5h+7d response | Both windows mapped by duration | [x] |
| 3 | Fresh cache | Output returned without app-server launch | [x] |
| 4 | Local/upgrade/remote install | Provider installed executable | [x] |

### Boundary Cases

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1 | 0% and 100% | Both accepted directly | [x] |
| 2 | One tagged window | One segment only | [x] |
| 3 | Untagged positional fallback | Used only when target is unambiguous | [x] |
| 4 | Stale empty lock | Recovered and released | [x] |
| 5 | Recent lock | Nonblocking stale-cache fallback | [x] |

### Error Handling

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1 | Relative/non-executable override | Rejected without execution | [x] |
| 2 | Initialize/quota error or malformed JSON | No fresh data; stale fallback only | [x] |
| 3 | App-server timeout | Child terminated; no zombie | [x] |
| 4 | Invalid percent/reset/cache schema | Rejected | [x] |
| 5 | Forbidden management references | Scan returns none | [x] |
