---
spec: cross-runtime-human-voice-layer
date: 2026-07-21
model: claude-opus-4-8
effort: high
status: passed
---

# Claude Human-Voice A/B Evaluation

## Purpose

Compare the previous delivery policy (condition A: concise output plus a mandatory recap) against the new human-voice policy (condition B: context-sensitive compact, procedural, substantial-work, and safety-rich delivery).

This evaluation used synthetic, anonymized scenarios. No private persona or user-profile material was included in the test prompts.

## Runtime setup

- Claude CLI print mode with session persistence disabled.
- Model: `claude-opus-4-8`.
- Effort: `high`.
- Tools: disabled, so the comparison measures response shaping rather than tool behavior.
- User/project settings and hooks excluded via `--setting-sources local`.
- `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL` were unset for the final run so Claude Code used its Claude subscription login rather than the local proxy route.
- One generation per condition for each case.

An initial partial run used the inherited proxy authentication and emitted an auth warning. It was stopped and discarded before the final evaluation.

## Cases

1. Short macOS port-occupancy command.
2. Small completed repository health-check report.
3. User-operated `launchd` suspend, verification, and restore procedure.
4. SQLite versus MongoDB recommendation under explicit constraints.
5. Ambiguously authorized production MongoDB deletion request.
6. Explicit three-line recap for a completed multi-file refactor.

## Blind judging

Two independent Claude Opus 4.8 judge calls scored each pair on a 5-25 scale:

1. Task fit.
2. Human voice.
3. Information density.
4. Evidence and safety retention.
5. Task ownership.

The response labels were reversed between judge runs to reduce position bias. Judges did not receive the A/B policy mapping.

## Results

| Metric | Condition A | Condition B | Change |
| --- | ---: | ---: | ---: |
| Blind pair wins | 0 / 12 | 12 / 12 | B won every judgment |
| Mean judge score | 19.67 / 25 | 24.08 / 25 | +4.42 |
| Total characters | 3,570 | 3,143 | -12.0% |
| Total lines | 119 | 99 | -16.8% |
| Markdown headings | 15 | 0 | Less templated structure |
| Conclusion/recap markers | 5 | 1 | Contextual rather than mandatory |

Both judges independently selected condition B for all six cases after their label mappings were decoded.

## Observed improvements

- Direct answers stopped after the useful command and interpretation instead of appending a repeated conclusion.
- Small completed-work reports became natural short prose rather than status bullets plus a duplicated recap.
- Procedures retained prerequisites, verification, persistence warnings, and recovery steps while using less rigid heading structure.
- The database recommendation kept CJK search, concurrency, and scaling trade-offs while reducing repeated conclusions.
- The production deletion case became longer, appropriately: condition B preserved the authorization stop point, exact-target check, verified backup requirement, and rollback boundary before showing a guarded procedure.
- The explicit three-line recap case produced exactly three lines, showing that user-requested recap overrides the routine no-recap default correctly.

## Limitations

- Six scenarios are enough for a first gate, not a general writing-quality benchmark.
- Each condition was sampled once; stochastic variance is not measured.
- Claude judged Claude output, so shared model preferences may affect the scores.
- The isolated system prompts test the delivery policy directly; they do not measure every interaction with the full live Claude Code context, tools, hooks, or long sessions.
- Chinese creative writing, casual conversation, disagreement, and extended multi-turn drift remain untested.

## Decision

The Claude-first human-voice layer passes the initial A/B gate. Keep condition B as the Claude policy and collect natural-session evidence before starting cross-runtime rollout.

## Recap fallback fixture (2026-07-21)

Follow-up fixture for the host-or-agent recap fallback (TESTS F1-F3). Same isolated setup: Claude CLI print mode, `claude-opus-4-8`, tools disabled, `--setting-sources local`, subscription auth (proxy vars unset), anonymized delivery-policy system prompt with no persona/user-profile content.

One substantial-completed-work task (migrate three handlers to async/await, update two test files, suite 41 pass / 0 fail, one flaky test quarantined) generated under two runtime conditions:

- **host-without-recap**: reply is the only thing the user sees.
- **host-with-recap**: host renders a structured outcome/verification/remaining block separately.

A schema-scored blind judge (`claude-opus-4-8`) evaluated both replies:

| Criterion | Result |
| --- | --- |
| F2 hostless: outcome present | pass |
| F2 hostless: verification present | pass |
| F2 hostless: remaining work present | pass |
| F2 hostless: no tool diary | pass |
| F3 hosted: preserves the same facts | pass |
| F3 hosted: avoids duplicating the structured recap block | pass |

The hostless reply carried an explicit verification line and the quarantined-test residue; the hosted reply folded the same facts into terse prose without a labeled recap block. This confirms the agent supplies the fallback recap when no host recap exists and suppresses the duplicate when the host renders one.

## Codex Phase 2 fixture (2026-07-21)

The Codex adapter was tested with an isolated temporary `CODEX_HOME` containing only a symlink to the existing local subscription auth and the repository-owned Codex-native `human-voice` skill. The synthetic project had no private instructions or persona data. `--ignore-user-config`, `--ephemeral`, read-only sandbox, and no tools were used.

| Fixture | Result | Evidence |
| --- | --- | --- |
| Direct factual answer | pass | HTTP 404 explanation returned in one sentence; no forced recap or process diary. |
| Substantial completed work, hostless | pass | Outcome, explicit 41/0 verification, quarantined-test remaining work, and no tool diary. |
| Hosted lifecycle recap | unverified | Codex host-equivalent lifecycle recap was not established; agent fallback remains the default. |

## Grok capability gate (2026-07-21)

| Required fact | Result |
| --- | --- |
| Repository-owned Grok/xAI runtime adapter | no divergent adapter; compatibility contract documented |
| Local `grok` executable | installed: `grok 0.2.106` at `~/.local/bin/grok` |
| Official installer source | inspected local copy from `https://x.ai/cli/install.sh`; no sudo; shell profile edits disabled |
| Instruction injection/discovery path | `grok inspect --json` reports Codex-native `human-voice` from `config/ai/codex/skills/human-voice/SKILL.md` |
| Codex skill discovery | 8 Codex-native skills found through configured `skills.paths` |
| Compatibility scope | broader Claude global rules/hooks/skills/agents also reported as loaded; isolation/review required |
| Authentication boundary | logged in with `grok.com`; default model `grok-4.5` |
| Free-trial/account eligibility | account access confirmed; exact trial/limits not separately measured |
| Host lifecycle recap capability | unverified |
| Tool/workdir contract | synthetic no-tools fixture only; real tool/workdir smoke test remains pending |

The executable, authentication, Codex skill path, and delivery fixture are now verified. `config/ai/grok/README.md` documents the activation boundary. No divergent Grok skill, provider route, or repository credential setup was added. Full Grok parity remains unverified because the fixture deliberately supplied synthetic facts and disabled tools.

## Grok human-voice fixture (2026-07-21)

Command shape: `grok --no-memory --no-subagents --tools "" --single ...` with a synthetic completed-work prompt. No repository files were changed and no tools were available to the model.

| Criterion | Result |
| --- | --- |
| Outcome included | pass |
| Verification included | pass |
| Remaining work included | pass |
| Tool diary avoided | pass |
| Routine process narration avoided | partial | Opening announced a read/search plan even though tools were disabled; final recap itself was concise. |
| Direct-answer recap suppression | not covered by this fixture |
| Real execution/tool/workdir behavior | not covered by this fixture |

The response correctly summarized the supplied synthetic facts as outcome, verification, and remaining work. This validates delivery shaping only; it does not prove that Grok performed the migration or ran the test suite.
