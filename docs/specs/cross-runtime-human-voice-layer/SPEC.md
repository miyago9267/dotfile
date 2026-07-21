---
id: spec-cross-runtime-human-voice-layer
title: Claude-First Human-Voice Layer
status: implemented
created: 2026-07-21
updated: 2026-07-21
author: Miyago
tags: [persona, communication, human-voice, claude, skills]
priority: high
---

# Claude-First Human-Voice Layer

## Background

The Monika identity and several communication rules already exist in `config/ai/AGENTS.md`, Claude's SessionStart persona hook, and runtime adapters. The same ideas are duplicated with different coverage, and recap behavior currently conflicts: the shared contract says no trailing recap while Claude and other adapters request one.

The external `ayghri/i-have-adhd` project is useful research for reducing filler and improving scanability, but its always-on and action-first rules are too rigid for our persona, autonomy, and task ownership model. This spec defines an owned delivery-shaping layer. Claude Phase 1 validated the semantic source and recap fallback; Phase 2 distributes a Codex-native adapter and installs the xAI Grok CLI while keeping Grok auth, host recap, and post-login behavior explicitly gated.

## Outcome

Claude responses should choose a delivery shape from the request context:

- **Baseline compact** for direct questions, simple status, and small completed work.
- **Procedural rich** when Miyago must perform a procedure, recovery, migration, or troubleshooting flow.
- **Substantial-work rich** after meaningful completed work that has changes, decisions, or verification evidence.
- **Safety-rich** for destructive, costly, externally visible, security-sensitive, or under-specified operations.

The layer preserves evidence, assumptions, uncertainty, limitations, test state, safety boundaries, and rollback information regardless of mode. After meaningful work, it also guarantees Miyago receives a lazy recap of outcome, verification, and remaining work: the host may render it, but the agent must supply it when the host does not or its capability is unknown.

## Requirements (EARS)

- **R1**: When a response is generated for a direct question or low-risk status request, the system shall lead with the answer or status and omit routine process narration.
- **R2**: When work is agent-owned and complete or verifiable, the system shall report the result without handing the work back to Miyago as an artificial next step.
- **R3**: When Miyago must perform a procedure, the system shall provide bounded ordered steps, prerequisites, verification, and applicable rollback or failure handling.
- **R4**: When substantial work is complete, the system shall report outcome, material changes or decisions, verification evidence, and meaningful limits without a tool-by-tool diary.
- **R5**: When an operation is destructive, costly, externally visible, security-sensitive, or blocked on missing authority, the system shall surface the risk, stop point, needed decision, safer alternative, and rollback where applicable.
- **R6**: When the user requests a format such as a tutorial, table, or recap, the system shall follow that format unless it would hide required safety, evidence, or uncertainty.
- **R7**: When a response is compacted, the system shall retain decision-relevant evidence, assumptions, uncertainty, limitations, test state, and safety information.
- **R8**: When a question can be answered by local search, available tools, or existing context, the system shall not ask Miyago to perform that research first.
- **R9**: When meaningful execution, research, modification, or multi-step work completes, the system shall ensure Miyago receives a concise recap of outcome, verification, and remaining work.
- **R10**: When the host reliably renders an equivalent lifecycle recap, the agent shall not duplicate it; if the host does not or its capability is unknown, the agent final delivery shall include it.
- **R11**: When the response is a direct question or simple status reply without meaningful work, the system shall not force a recap.
- **R12**: When the human-voice layer is loaded, it shall shape delivery only and shall not redefine Monika identity, runtime ownership, permissions, safety rules, or SDD/TDD requirements.
- **R13**: When Claude loads the layer, the SessionStart reminder shall remain concise and shall not duplicate the full skill body.
- **R14**: When recap semantics change, existing runtime adapters shall preserve the same fallback contract; Grok remains unverified until its runtime behavior is validated.
- **R15**: When Codex loads the human-voice layer, it shall use a Codex-native skill source with the same delivery semantics without copying Claude hooks or memories.
- **R16**: When the Codex setup or plugin packaging path runs, it shall discover and validate the Codex-native human-voice skill through the existing source and allowlist mechanisms.
- **R17**: When Grok capability facts are missing or unverifiable, the system shall not activate a guessed adapter, installer, provider route, credential setup, or host-recap assumption; Grok shall remain explicitly unverified.
- **R18**: When the installed Grok CLI discovers the existing Claude-compatible skill surface, it shall reuse the repository-owned human-voice semantics without creating a divergent Grok copy.
- **R19**: When Grok compatibility discovery imports broader Claude rules, hooks, skills, or agents, authenticated/private-work sessions shall wait until that import scope is isolated or explicitly accepted.

## Non-goals

- Replacing or rewriting Monika persona identity.
- Installing, forking, syncing, or depending on `ayghri/i-have-adhd`.
- Adding a new hook or automatic per-prompt formatter.
- Shipping the full human-voice skill to Gemini or OpenCode in this Phase 2 batch.
- Activating a Grok runtime path, provider route, credential setup, or host capability when the official/local contract is not verified. A documentation-only reserved boundary is allowed.
- Building an automated LLM quality scorer before the fixture corpus is stable.

## Architecture

```text
config/ai/AGENTS.md
  shared identity, communication floor, delivery modes, and precedence
        |
config/ai/claude/skills/human-voice/SKILL.md
  operational delivery-shaping guidance and decision table
        |
config/ai/claude/hooks/persona-reminder.sh
  short Claude runtime-visible identity + policy summary
        |
config/ai/claude/memories/feedback-global.md
  preference references only; no competing canonical policy
        |
config/ai/codex/skills/human-voice/SKILL.md
  Codex-native delivery adapter; distributed by setup scanner and plugin allowlist
        |
config/ai/grok/README.md
  documentation-only reserved contract; never loaded or installed
        |
Grok capability gate
  no executable adapter, installer, routing, or credentials until official/local CLI behavior is verified
```

Existing `ask-discipline` remains responsible for whether and how to ask. Existing `efficiency` remains responsible for execution/session waste. `human-voice` owns the user-visible delivery shape after those constraints are satisfied. Runtime adapters translate the semantic contract into native loading paths; they do not copy Claude hooks or memories.

### Precedence

1. Safety, factual evidence, and explicit user format.
2. Shared contract and runtime ownership rules.
3. `ask-discipline` decision discipline.
4. Human-voice mode selection.
5. `efficiency` compression preference.

### Recap taxonomy

- **Meaningful-work recap**: required after execution, research, modification, or multi-step work; contains outcome, verification, and remaining work without replaying the tool log.
- **Host lifecycle recap**: may satisfy the meaningful-work requirement when it reliably renders equivalent information.
- **Agent fallback recap**: required in the final delivery when the host has no equivalent recap or its capability is unknown.
- **Direct-answer response**: no forced recap when no meaningful work was performed.
- **User-requested recap**: follow the requested format while preserving verification and remaining-work information.

## Alternatives Considered

### Install upstream and remove local persona rules

Rejected. It would discard Miyago-specific identity and conflict with agent autonomy, recap preferences, and runtime specialization.

### Install upstream as an always-on dependency

Rejected. It is unpinned, experimentally evaluated, and contains rigid rules that fit procedures better than all conversation types.

### Create an owned delivery layer and validate Claude first

Chosen. It reuses the useful intent, keeps source-of-truth control, limits blast radius, and provides an evidence gate before cross-runtime rollout.

## ADR

### ADR-1: Delivery shaping stays separate from persona

- Decision: Keep Monika identity in the persona layer; put response-mode selection in `human-voice`.
- Reason: Identity answers who is speaking; delivery shaping answers how this task should be communicated. Combining them increases drift and makes runtime adaptation harder.

### ADR-2: Baseline compact is contextual, not rigid

- Decision: Default to concise result-first output; activate rich modes only for user-owned procedures, substantial work, safety, or explicit format requests.
- Reason: Fixed first-line actions, timing estimates, and forced progress summaries create a new mechanical voice and can return agent-owned work to the user.

### ADR-3: Meaningful-work recap uses host-or-agent fallback

- Decision: Require a concise recap after meaningful work. A reliable host lifecycle recap satisfies it; otherwise the agent final delivery supplies outcome, verification, and remaining work. Direct answers stay recap-free unless requested.
- Reason: Miyago deliberately uses the recap as a lazy digest across runtime skins. Host capabilities differ, so an optional-only policy can silently remove that digest on Codex, Grok, or other shells.

### ADR-4: Claude-first rollout

- Decision: Validate the owned skill and hook alignment in Claude before changing other runtime adapters or distribution allowlists.
- Reason: Claude has the clearest runtime injection point and allows a small, observable blast radius.

### ADR-5: Codex-native adapter, compatibility-discovered Grok

- Decision: Give Codex a native skill source under `config/ai/codex/skills/`. Install Grok through the inspected xAI installer, reuse the existing Claude-compatible `human-voice` skill path discovered by `grok inspect`, and keep auth, host recap, and post-login behavior gated.
- Reason: Codex has a deterministic native skill loader and plugin build path. Grok now has a verified local executable and compatibility discovery path, but account access and full runtime behavior still require user-owned login and smoke tests.

## Phase Plan

### Phase 1: Claude-first layer

- Add SDD artifacts and ten-case fixture matrix.
- Update shared communication semantics and recap taxonomy.
- Add the Claude skill.
- Align the SessionStart reminder and feedback memory.
- Run repository checks and manual fixture review.

### Recap fallback correction

- Synchronize host-or-agent recap semantics across the shared contract and existing Claude, Codex, Gemini, and OpenCode adapters.
- Add a hostless substantial-work fixture to verify the agent fallback.
- Keep Grok delivery explicitly unverified until its setup and adapter path are implemented.

### Phase 2: Codex rollout and Grok capability gate

- Add and validate the Codex-native human-voice skill through the existing setup scanner and plugin allowlist/build path.
- Run sanitized Codex fixtures for compact, procedural, substantial-work, safety-rich, and hostless recap behavior.
- Install the xAI Grok CLI only after inspecting the official installer; avoid sudo and shell-profile edits, then verify executable/version and discovered instruction paths.
- Reuse the existing Claude-compatible human-voice skill when Grok discovery reports it enabled; keep OAuth, free-trial eligibility, tool/workdir behavior, and host recap capability pending until a user-owned login smoke test.
- If any future Grok capability fact is missing, record the blocker and leave that capability unverified without creating a divergent adapter, provider route, or credential setup.

### Deferred follow-up

- Gemini rollout remains separately gated; do not broaden its allowlist in this batch.
- OpenCode remains adapter-only because its primary agent disables skill loading; changing that requires a separate architecture decision.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Rules become another rigid template | medium | Contextual mode table; ten-case fixture review; no fixed opener/closer beyond result-first. |
| Compact mode drops safety or uncertainty | high | Make evidence/safety retention a hard requirement and test it explicitly. |
| Recap rules drift again | high | Keep host-or-agent fallback taxonomy in the shared contract; synchronize existing adapters and test a hostless case. |
| Claude skill is not loaded through the existing setup | medium | Verify source path and symlink after implementation; stop before cross-runtime rollout. |
| Codex native skill and plugin artifact diverge | medium | Keep Codex source precedence explicit; run setup symlink, build, and validate checks together. |
| Grok capability is inferred from an unverified path | high | Require executable, instruction, auth, host, and workdir evidence; stop without an adapter when any fact is missing. |
| Grok imports broader Claude context than intended | high | Inspect compatibility sources before login; isolate or explicitly accept the scope before private-work sessions. |
| External upstream text or dependency leaks in | low | Write original repository-owned rules and prohibit upstream linkage in non-goals. |
