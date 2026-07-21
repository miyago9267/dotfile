---
spec: cross-runtime-human-voice-layer
created: 2026-07-21
---

# Progress: Cross-Runtime Human-Voice Layer

> Spec: `docs/specs/cross-runtime-human-voice-layer/SPEC.md`

## Phase 2: Codex rollout and Grok capability gate

> Status: completed

- Gate: Claude semantic and recap-fallback evaluations passed on 2026-07-21 (`EVAL.md`).
- Codex: native skill, plugin allowlist, setup symlink, profile checker, plugin validation, and sanitized direct/substantial fixtures passed.
- Grok: xAI CLI `0.2.106` installed to `~/.grok/`; `grok inspect --json` reports the existing Claude-compatible `human-voice` skill enabled from `~/.claude/skills/human-voice`.
- Grok: xAI CLI `0.2.106` installed, `grok.com` login confirmed, default model `grok-4.5`, and Codex-native `human-voice` discovered through configured `skills.paths`.
- Grok fixture: sanitized no-tools test passed outcome, verification, remaining work, and no tool diary; routine process narration was partial and needs a delivery-tuning pass.
- Grok pending: compatibility scope isolation/review, free-trial/account limits, real tool/workdir smoke test, and host lifecycle recap equivalence.
- Safety stop: `grok inspect` reports broader Claude-compatible rules/hooks/skills/agents in addition to `human-voice`; no private-work session should run until that scope is accepted or isolated.
- Scope: Gemini/OpenCode unchanged; no divergent Grok skill, provider route, or repository credential setup added.
- Outcome: Phase 2 Codex rollout completed; Grok CLI and skill sync verified, with real execution parity still pending.

---

## Completed Phases

- Phase 1: Claude-first human-voice layer completed on 2026-07-21.
- Recap fallback correction completed on 2026-07-21: host-or-agent fallback synchronized across the shared contract, Claude hook/skill/memory, and the Codex/Gemini/OpenCode adapters; hostless-recap fixture (F1-F3) passed (`EVAL.md`).

<!-- Phase completion: bash ~/.claude/scripts/spec-archive.sh phase cross-runtime-human-voice-layer -->
