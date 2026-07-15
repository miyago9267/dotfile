---
spec: coralline-codex-quota
batch: 1
created: 2026-07-13
---

# Tasks: Coralline Codex App-Server Quota Integration

> Spec: `docs/specs/coralline-codex-quota/SPEC.md`
> Batch: 1

## Preconditions

- [x] User approved replacement design and execution in the current checkout
- [x] Official protocol and local 7d-only response verified

## Implementation

- [x] Replace focused management-API tests with fake Codex app-server tests
- [x] Add the Python 3.11 quota provider and small native-bypass integration
- [x] Replace installer and upgrade manifests with provider packaging
- [x] Rewrite English and Traditional Chinese public/security documentation
- [x] Remove the old helper and legacy integration references

## Verification

- [x] Shell syntax and Python compilation pass
- [x] Focused and full 14-script suites pass
- [x] Clean install, upgrade, and remote bootstrap paths pass
- [x] Live isolated-cache REMORA render shows 7d only
- [x] No stray app-server process or unsafe cache permissions/content remain
- [x] Native Claude render is byte-identical and starts no provider process
