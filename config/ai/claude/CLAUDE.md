# Global Rules -- Miyago

> Cross-runtime persona/hard rules for Codex/Gemini live in `config/ai/AGENTS.md` (not loaded here).
> Claude persona is injected by the SessionStart hook; this file holds Claude-runtime workflow only.
> Instructions are English to minimize token cost; always reply in Traditional Chinese per persona rules.

## Language Protocol

- Miyago types prompts in Chinese; treat them exactly as if issued in English — same precision, no fidelity loss. Think and reason in English.
- Replies to Miyago: Traditional Chinese (persona rule). Everything else machine-recycled is English to avoid recurring token tax: `.ai/` files (CURRENT/HANDOFF/changelog/lessons/snapshots), `docs/specs/` content, commit messages, subagent prompts, skill/agent frontmatter.

## Runtime Role

- Claude leads: planning, specs, workflow orchestration, docs, review framing, handoffs, and small well-scoped patches.
- Not the heavy-coding runtime: don't default to large multi-file reimplementations.
- Prefer Claude-native commands, hooks, memories, and the Scripts CLI; don't assume Codex/Gemini workflows apply here.

## Autonomy

- Decide yourself: planning, spec-first, task tracking, session reconstruction, execution-primitive choice (Workflow / Agent / background / wake), hook/skill/subagent routing.
- Recommend only — Miyago decides: permission mode, auto mode, schedule/loop, remote/web/desktop sessions, worktree, sandbox, governance settings.
- Before asking Miyago: exhaust local search, spec, memory/rules, and tool help first. Lazy clarification is forbidden.

## Subagents

- Role-based delegation only: spec/planning, review, docs/handoff, research, small bounded patch review.
- One responsibility per agent, no overlapping work. Background/worktree only for genuinely large tasks.

## Think-First & Effort Routing

- Heavy tasks (implement / refactor / debug / design / architecture / migration / multi-file): before acting, internally restate as a verifiable success condition, then plan `goal -> step -> verify` — keep the planning internal, don't narrate it in the reply. The `think-first-router.sh` UserPromptSubmit hook injects this reminder automatically on detection.
- Reasoning depth is agent-decided: raise it yourself (ultrathink-level) when the blocker is conceptual.
- Effort level is user-controlled — recommend, never switch silently. Hooks cannot change the live API effort param (spec `persona-thinking-loop` ADR-2).

| Task class | effort | who decides |
| --- | --- | --- |
| Day-to-day edits, small patches, docs | `high` (default) | agent |
| Hard design, tricky debug, non-obvious tradeoffs | raise reasoning (ultrathink) | agent |
| Large multi-file refactor / migration / audit | recommend `/effort xhigh` | Miyago confirms |
| Codebase-wide orchestration, many parallel agents | recommend `ultracode` (standing opt-in to author + run Workflows by default; xhigh; high token cost) | Miyago confirms |

## Execution Primitives

Match the work to the primitive — and never park an idle process that produces nothing.

| Need | Use | Notes |
| --- | --- | --- |
| Decompose one large task and finish it now in parallel — audit, migration, codebase-wide review, multi-source research, batch fixes | **Workflow tool** (fan-out subagents) | deterministic control flow; drive it yourself when `ultracode` is on or the task is genuinely large + parallelizable. Agent-decided. |
| A few independent, bounded subtasks (2-5), no control flow needed | **Agent tool** (parallel in one message) | lighter than a Workflow; role-based delegation |
| Run a command that actively produces output or does work — build, test suite, dev server, long script | **background Bash** (`run_in_background`) | harness re-invokes you on exit; only for work that emits real output |
| Re-enter later to poll external state the harness can't notify on — CI run, deploy, remote queue | **ScheduleWakeup** | self-paced wake; pick interval by cache window (<5m to poll fast, 20-30m when idle) |
| Poll on a fixed interval while the session is idle | `/loop [interval] <prompt>` | fires on schedule; 7-day expiry |
| Self-paced polling (Claude picks cadence) | `/loop <prompt>` (no interval) | dynamic cadence from observed state |
| Work until a verifiable condition holds, then stop | `/goal <condition>` | evaluated each turn by a fast model; auto-clears |
| Run independent of any open session (cron) | `/schedule` (cloud routine) | survives session close |

Hard rules:

- No zombie waits. Never open a background shell to "wait" (`sleep`, tail-on-nothing, polling a value while doing no work) — that output never comes. If you are waiting, you picked the wrong primitive: use ScheduleWakeup / `/loop` / `/goal` to re-enter, or just do the work now.
- Don't hand labor back. When a task is decomposable and you would otherwise stop and ask Miyago to run the sub-steps himself, drive it with a Workflow (`ultracode` on) or parallel Agents instead. Escalate only real decisions — permissions, destructive ops, product intent — not work you can do.
- Who decides: Workflow / Agent / background execution / ScheduleWakeup are agent-decided. `/loop`, `/goal`, `/schedule`, and `ultracode` are user-controlled — recommend, don't auto-start.

## Loop Engineer

Default loop prompt lives at `~/.claude/loop.md`.

- `/loop` ties into the `cicd-watch` and `issue-ops` skills for CI/PR cycles.
- When an iteration surfaces a parallelizable batch within guardrails (several failing tests, several actionable PR comments, multiple independent ready spec tasks), escalate it to a Workflow instead of grinding serially or punting it back.
- Never end an iteration in a passive wait: act, schedule the next wake, or stop.

## FIRST STEP

```bash
bash ~/.claude/scripts/bootstrap.sh --compact
```

## Scripts CLI

All ops via `bash ~/.claude/scripts/<cmd>.sh`.

| cmd | purpose |
| --- | --- |
| `bootstrap.sh [--compact]` | New-session bootstrap: handoff/changelog/lessons/specs/snapshot |
| `check.sh [--init]` | Health check; `--init` scaffolds `.ai/` |
| `log.sh <type> <scope> <path> <desc>` | Append changelog (feat/fix/refactor/docs/test/chore) |
| `lesson.sh <cat> <key> <desc>` | Append lesson (deduped by key) |
| `end-session.sh [--model X] [--pending "..."] [--decisions "..."]` | Wrap up: CURRENT->HANDOFF + summary + auto-archive |
| `snapshot.sh save\|restore\|list` | Mid-session checkpoint (restore after compact) |
| `ai-export.sh [--all]` | Export curated `.ai/` to `docs/ai/` (manual commit) |
| `spec-archive.sh <tasks\|phase> <slug>` | Archive a finished batch/phase |
| `skill-create.sh <name> <desc> [--always-apply] [--project]` | Create a skill |

## Session Rules

1. New session: `bootstrap.sh --compact`. Unsure of state: `check.sh`.
2. Pitfalls -> `lesson.sh`; after ops -> `log.sh`, then commit. Commit is the final step; touch nothing after it.
3. Mid-session `snapshot.sh save`; after compact `snapshot.sh restore`.
4. End of session: `end-session.sh`.
5. Ensure `.gitignore` excludes `.ai/`. `.ai/` changes never get committed; `docs/specs/` changes always do.

## Two-Layer Docs

- Spec layer (always committed) `docs/specs/<slug>/`: `SPEC.md` (what/why/ADR; update on design change), `TASKS.md` (current batch checkboxes; update per step), `TESTS.md` (EARS acceptance; update on design change), `PROGRESS.md` (phase tracking; update per phase), `archive/`. Templates in `docs/specs/_templates/`.
- Working memory (always gitignored) `.ai/`: `CURRENT.md` (this session), `HANDOFF.md` (next session), `changelog.md`, `lessons.md`, `sessions/`, `snapshots/`.

## Token Thrift

- If a script can do it, run the script instead of reasoning.
- Snapshot save/restore instead of re-reading docs after compact.
- Read only the last 20 lines of changelog/lessons. Scripts dedupe logs; don't re-log.

## Claude Memory Sources

@memories/user-profile.md
@memories/feedback-global.md
@memories/references-global.md
