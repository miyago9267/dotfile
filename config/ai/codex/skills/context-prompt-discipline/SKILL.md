---
name: context-prompt-discipline
description: "Codex context/prompt engineering guardrail -- prevent runaway token usage from broad searches, large logs, oversized tool output, and vague delegation prompts. Use when doing research, diagnostics, log/session analysis, subagent prompts, second opinions, or any task likely to produce large context."
alwaysApply: true
user-invocable: true
when_to_use: "Apply before commands/prompts that can pull large context or delegate open-ended analysis."
tags: [codex, context, prompt, tokens, usage, discipline]
effort: low
shell: optional
runtime-scope: codex-native
---

# Context / Prompt Discipline

Keep the model's working context small, relevant, and phase-oriented.

## Before Large Commands

Ask whether the command can return more than 10k tokens. If yes, use one of
these shapes first:

- `rg --files ... | sed -n '1,120p'`
- `rg -l PATTERN DIR`
- `rg -n --max-count 20 PATTERN DIR`
- `find DIR ... | sed -n '1,160p'`
- `jq`/`awk` summary table from JSON/JSONL/logs
- redirect raw output to `/tmp/...` and read only top-N or aggregate stats

High-risk targets:

- `~/.codex`, `~/.claude`, `$HOME`, `~/Library`
- `sessions`, `archived_sessions`, `logs`, `cache`, `node_modules`
- binary `strings`, minified bundles, generated files
- CI logs, rollout traces, JSONL transcripts

Do not run broad `rg PATTERN DIR` against those targets without an output cap
or summary pipeline.

## Tool Output Budget

- Exploration commands: prefer `max_output_tokens <= 12000`.
- Known small file reads: use normal output.
- Unknown logs/JSONL/binaries: write to a temp file or summarize first.
- If a command unexpectedly returns huge output, stop expanding adjacent files.
  Summarize what was learned and continue from anchors.

## Context Handoff

At phase boundaries, compress state into:

1. Goal
2. Verified facts
3. Decisions
4. Files touched / relevant anchors
5. Next smallest action

Use that handoff instead of dragging the full exploration transcript forward.
Suggest `/compact` or a new session when the current thread is mostly
investigation residue.

## Prompt Shape

Prompts to subagents, `codex exec`, or another model must include:

- objective
- scope boundaries
- explicit exclusions
- output format
- budget limit
- verification expectation

Bad:

```text
Research all related code and tell me what to do.
```

Good:

```text
In src/auth only, find the login token refresh path.
Return at most 5 bullets: files, key functions, likely bug, missing test.
Do not inspect node_modules or generated files.
```

## Second Opinion Defaults

For review snippets:

- Ask for only correctness/security regressions.
- Limit to 5 findings.
- Require file/line references.
- Forbid broad refactors and style preferences.
- Do not ask it to re-summarize the full problem.

## Done Criteria

The session should leave behind less context than it consumed:

- raw tool output is summarized
- only relevant anchors remain in the final answer
- large findings are recorded in a durable note/spec when needed
- no repeated broad search was used after the first anchor pass
