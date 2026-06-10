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

- Decide yourself: planning, spec-first, task tracking, session reconstruction, background execution, hook/skill/subagent routing.
- Recommend only — Miyago decides: permission mode, auto mode, schedule/loop, remote/web/desktop sessions, worktree, sandbox, governance settings.
- Before asking Miyago: exhaust local search, spec, memory/rules, and tool help first. Lazy clarification is forbidden.

## Subagents

- Role-based delegation only: spec/planning, review, docs/handoff, research, small bounded patch review.
- One responsibility per agent, no overlapping work. Background/worktree only for genuinely large tasks.

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
