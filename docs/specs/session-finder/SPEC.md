# SPEC — sesh: unified CC + Codex session finder

## Background

The user works across many project directories and frequently switches between them.
When he wants to resume a past session he can't find it: Claude Code (CC) and Codex CLI
each store sessions separately, keyed by directory, with no cross-tool view. He wants a
Zed/Copilot-history-style experience: one searchable list of "what I did before" across
both tools, that resumes the chosen session.

## Requirements (EARS)

1. WHEN the user runs `sesh`, the system SHALL list all CC and Codex sessions merged into
   one view, sorted by last-updated descending.
2. WHEN the user types in the fuzzy finder, the system SHALL filter by tool, cwd, and title.
3. WHEN the user selects a session, the system SHALL exec the correct resume command for
   its tool, restoring the interactive session in the correct working directory.
4. WHERE a query arg or `--cc`/`--codex` flag is given, the system SHALL pre-filter the list.
5. IF fzf is absent, the system SHALL print a clear message and fall back to a plain list.

## Data sources (verified 2026-07-14)

| Tool | List source | cwd | Title | Time | Resume |
| --- | --- | --- | --- | --- | --- |
| CC | `~/.claude/projects/<enc-cwd>/<uuid>.jsonl` | first `type:user` line's `cwd` | first user prompt | file mtime | `cd <cwd> && claude --resume <id>` |
| Codex | `~/.codex/session_index.jsonl` (`id`,`thread_name`,`updated_at`) | rollout first `payload.cwd` | `thread_name` | `updated_at` | `codex resume <id>` |

- Codex rollout files: `~/.codex/{sessions,archived_sessions}/rollout-<ts>-<uuid>.jsonl`;
  the `<uuid>` matches `session_index.id`. Build uuid→path map once.
- Rollout files absent from the index are still included (title from first user prompt).

## Design

- Single self-contained Go binary, stdlib only; shells out to `fzf` (only runtime dep).
- Lazy CC parse: stop at the first user+cwd line per file (~348 files, must feel instant).
- Selection execs via `sh -c` (CC needs the `cd`) or direct `codex resume` so the resumed
  TUI takes over the terminal.
- Location: `dotfile/tools/sesh/`, built to `~/.local/bin/sesh`.

## ADR

- **ADR-1 Go single binary** (over Python/Bash): user preference (Go first-class),
  zero-runtime-dep distribution, fast startup. Cost: slower to author than a script.
- **ADR-2 Reuse codex `session_index.jsonl`** rather than parsing every rollout for titles:
  codex already maintains human-readable `thread_name`; only fall back to rollout parsing
  for cwd and for sessions missing from the index.
- **ADR-3 fzf for interaction** (not a custom TUI): matches the Zed/Copilot feel with
  near-zero code; graceful plain-list fallback when absent.

## Status

- Implementation delegated to executor (Go). Interactive fzf selection is not
  auto-testable; parsing verified via a `--list` debug flag.
