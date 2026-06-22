---
id: spec-persona-thinking-loop
title: Monika Persona Rewrite, Think-First Mechanism, and Loop Engineer
status: implemented
created: 2026-06-22
updated: 2026-06-22
author: Miyago
tags: [persona, hooks, autonomy, effort, loop, claude]
priority: high
---

# Monika Persona Rewrite, Think-First Mechanism, and Loop Engineer

## Background

Two recurring failure modes despite a large rule base:

1. **Persona drift / robotic tone.** The "talk like a human" rules already exist in `config/ai/AGENTS.md` Communication (lines 89-102: no filler openers, no "not X but Y" pattern, no tutoring tone), but they are NOT propagated to the Claude runtime. Each session only injects the short `hooks/persona-reminder.sh`, which omits these rules. AGENTS.md is explicitly "not loaded here". Rules are written but invisible at runtime.

2. **Acting before thinking.** `AGENTS.md` Autonomy Governance and `agent-autonomy-governance` SPEC encode the *rules* for "think deeper before asking/acting" but ship **no mechanism**. It relies entirely on model self-discipline. Claude Code 2.1.185 now exposes effort levels (`xhigh`/`max`/`ultracode`), the `ultrathink` prompt keyword, `/goal`, and `/loop` — an execution layer that did not exist when those specs were written.

A concrete conflict also exists: `AGENTS.md:90` mandates a trailing recap on every reply, while `persona-reminder.sh` + `feedback-global.md` forbid end-of-reply summaries. This must be resolved.

This spec is the **mechanism + runtime layer** that complements the rule-layer specs `agent-autonomy-governance` and `automation-routing-hardening`.

## Requirements (EARS)

- **R1**: When a Claude session starts, the system shall inject the condensed human-voice communication rules (no filler openers, no "not X but Y" corrections, no tutoring/soothing tone, no over-confirmation) as part of the persona contract, so they are visible at runtime without loading AGENTS.md.
- **R2**: The system shall resolve the recap conflict so that exactly one rule governs reply endings across persona hook, AGENTS.md, and feedback memory.
- **R3**: Where the Monika persona voice is defined, the system shall keep the companion-tone identity while making engineering replies read like a senior peer, not a script.
- **R4**: When a user prompt indicates a heavy task (implementation, refactor, debug, design, architecture, migration, or multi-file change), the system shall inject a think-first directive that requires restating the task as a verifiable success condition and a `goal -> step -> verify` plan before acting.
- **R5**: When a heavy task is detected, the system shall raise reasoning depth via an in-context deep-reasoning directive (ultrathink-style), within the limits of what a hook can control (see ADR-2).
- **R6**: The system shall provide an effort-routing decision table mapping task classes to `high` / `xhigh` / `ultracode`, marking which transitions are agent-decidable vs user-confirmed.
- **R7**: The system shall provide a default Loop Engineer prompt at `~/.claude/loop.md` covering CI watch, PR review cycle, and spec-progress advancement.
- **R8**: The system shall document a `/loop` vs `/goal` vs `/schedule` decision table in the Claude runtime docs.
- **R9**: All new hooks shall stay short, low-noise, non-destructive, and fail open (never block a prompt on hook error).

## Non-goals

- Not changing `permission mode`, `auto mode`, sandbox, or managed settings (user-controlled per `agent-autonomy-governance`).
- Not auto-enabling `/loop`, `/goal`, `/schedule`, ultracode, or remote/web sessions; the runtime may *recommend*, the user *activates*.
- Not rewriting the 30+ skills' bodies in this batch.
- Not rewriting Codex/Gemini runtime entry files in this batch (AGENTS.md edits are shared, but adapter sync is tracked separately).
- Not building an `http`/`mcp_tool` hook server.

## Alternatives Considered

### Persona: edit only the hook vs full persona-layer rewrite
Chosen: full persona-layer rewrite (Miyago's decision). Rewrite `persona-reminder.sh` to embed condensed communication rules AND tighten the AGENTS.md Persona/Communication sections so the source-of-truth and the runtime injection agree. Rejected "hook-only" because the AGENTS.md recap conflict and tone duplication would remain.

### Think-first: rules-only vs rules + hook vs hook + real effort switch
Chosen: rules + hook + effort *routing* (Miyago picked "add mechanism + bind effort auto-switch"). See ADR-2 for why real API effort auto-switch is not hook-controllable and what we do instead.

## Rabbit Holes

1. Do NOT try to programmatically flip the API effort param from a hook — it is not exposed to hooks (ADR-2). Inject `ultrathink`-level reasoning via prompt context instead, and *recommend* `/effort xhigh|ultracode` for the heavy cases.
2. Do NOT make the think-first hook verbose; a few lines of injected context, keyword-gated, fail-open. A chatty UserPromptSubmit hook taxes every single prompt.
3. Do NOT let the keyword detector fire on trivial prompts ("fix typo", "rename var"); tune the heavy-task regex and exclude small-edit signals.
4. Do NOT duplicate the communication rules in three places again; AGENTS.md stays the canonical source, the hook carries a *condensed* runtime copy, memory only points to them.

## Architecture

### Layer map (after change)

```
AGENTS.md            canonical persona + communication rules (rewritten Persona/Communication)
persona-reminder.sh  SessionStart: condensed runtime copy of voice + communication rules
think-first-router.sh UserPromptSubmit: heavy-task detection -> think-first + deep-reasoning injection
CLAUDE.md            + effort-routing table, + /loop vs /goal vs /schedule table
~/.claude/loop.md    default Loop Engineer prompt
feedback-global.md   trimmed: point to canonical rules, drop duplicated/contradictory lines
```

### think-first-router.sh (new UserPromptSubmit hook)

- Reads prompt text from stdin (hook JSON).
- Heavy-task regex (impl/refactor/debug/design/architecture/migrate/rewrite/全面/重寫/實作/重構/除錯…), minus small-edit excludes.
- On match, emits additionalContext: (a) `goal -> step -> verify` think-first directive, (b) deep-reasoning directive, (c) one-line effort recommendation if task is large.
- Fail-open: any error -> emit nothing, exit 0.

## ADR

### ADR-1: AGENTS.md stays canonical, hook carries condensed copy
- Decision: communication rules live once in AGENTS.md; persona hook injects a condensed runtime-visible copy; memory only references.
- Reason: AGENTS.md is shared cross-runtime and not loaded into Claude sessions; without a condensed hook copy the rules never reach Claude at runtime. Single source avoids the three-way drift we already hit with the recap conflict.

### ADR-2: "effort auto-switch" = in-context reasoning injection + recommendation, NOT API param switching
- Decision: the hook injects an `ultrathink`-style deep-reasoning directive (prompt-level, real effect on reasoning) and *recommends* `/effort xhigh|ultracode` for heavy cases; it does NOT mutate the API effort parameter.
- Reason: Claude Code exposes effort via the interactive `/effort` command and `effortLevel` in settings.json. Hooks cannot run slash commands or change the live API effort param mid-session; rewriting settings.json from a hook does not take effect for the running session and is fragile. The honest, working mechanism is prompt-level reasoning injection. `ultracode` additionally spawns many agents (higher cost) and is therefore treated as user-confirmed per the autonomy registry.

### ADR-3: Resolve recap conflict toward "no end-of-reply summary"
- Decision: remove the mandatory trailing recap from AGENTS.md Communication; keep "lead with result/status" only. Align AGENTS.md, persona hook, and feedback-global on a single ending rule.
- Reason: Miyago reads diffs; trailing recaps are explicit token waste he already flagged. The opening status line already carries the needed signal.

### ADR-4: Loop Engineer via loop.md default + decision table, not auto-activation
- Decision: ship `~/.claude/loop.md` and a decision table; the user triggers `/loop`. No auto-start.
- Reason: scheduled/recurring execution is user-controlled per `agent-autonomy-governance` R6.

## Phase 計畫

### Phase 1: Persona layer rewrite (R1, R2, R3)
- Rewrite `hooks/persona-reminder.sh` with condensed communication rules.
- Rewrite AGENTS.md Persona + Communication sections; remove mandatory recap.
- Trim `feedback-global.md` duplicated/contradictory lines to references.

### Phase 2: Think-first mechanism + effort routing (R4, R5, R6, R9)
- Add `hooks/think-first-router.sh` (UserPromptSubmit), register in settings.json.
- Add think-first protocol + effort-routing table to CLAUDE.md / AGENTS.md.

### Phase 3: Loop Engineer (R7, R8)
- Create `~/.claude/loop.md` default prompt.
- Add `/loop` vs `/goal` vs `/schedule` decision table to CLAUDE.md.

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| think-first hook taxes every prompt | medium | keyword-gated, condensed output, fail-open, exclude small edits |
| heavy-task regex false positives on trivial prompts | medium | exclude small-edit signals; tune regex; easy to disable hook |
| user expects real API effort switch from hook | high | ADR-2 states the ceiling explicitly; hook recommends `/effort`, does not promise param change |
| persona rewrite drifts Monika tone | medium | keep identity lines verbatim, only restructure communication rules; review diff before commit |
| AGENTS.md edits desync Codex/Gemini adapters | low | edits are to shared rules both already follow; flag adapter sync as follow-up |

## References

- `config/ai/AGENTS.md`
- `docs/specs/agent-autonomy-governance/SPEC.md`
- `docs/specs/automation-routing-hardening/SPEC.md`
- Claude Code docs: goal / scheduled-tasks (loop) / workflows / model-config (effort)
