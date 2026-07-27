---
spec: grok-runtime-isolation
created: 2026-07-22
---

# Tests: Grok Runtime Isolation

- **[R1] Native persona:** Given `grok-native inspect --json`, the report
  contains the repository-managed Grok `AGENTS.md` and no Claude instruction
  entries.
- **[R2] Native compatibility gate:** Given `grok-native inspect --json`, no
  Claude-origin agents are reported even when `~/.claude/agents` exists.
- **[R3] Compatibility escape hatch:** Given `grok-compat inspect --json`, the
  normal Grok home and explicitly enabled compatibility cells are used.
- **[R4] Safe installation:** Given an existing `~/.grok/config.toml` and auth
  state, setup leaves both files unchanged.
- **[R5] Idempotence:** Given two consecutive setup runs, the second run makes
  no additional backup or content change.
- **[R7] Secret boundary:** Given a repository diff, no auth token or session
  state is added under `config/ai/grok` or `script/common`.
