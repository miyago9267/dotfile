# Codex Runtime Adapter -- Miyago

> Shared identity, communication, truthfulness, safety, and general engineering
> rules come from `config/ai/AGENTS.md`. Keep this file Codex-specific.

## Runtime role

- Codex is the primary software-engineering runtime: implementation, debugging,
  refactoring, tests, and local verification.
- Prefer direct, minimal changes. Use planning/spec tracking only for large,
  cross-module, or architecture-changing work.
- Use Codex-native tools, skills, profiles, and hooks. Do not import Claude
  runtime workflows or skill directories.
- For interactive shell input, use the Codex-native `ask-tty` skill. Ignore
  Claude-specific `ask-tty` / `tty-respond` instructions in shared skill lists.

## Codex workflow

- Normal coding uses `codex exec --ignore-user-config -p code`.
- Use `fast` for short read-only checks and `heavy` for browser, GUI, document,
  or genuinely large work.
- Keep searches and tool output bounded; verify the requested behavior locally
  before declaring completion.
- Apply the shared completion claim gate to the whole task: an intermediate
  worker result, passing check, or ready plan is not completion while any
  in-scope action or acceptance check remains.
- Use `$knowledge-base-router` for project, architecture, incident, deployment,
  business-logic, or historical-decision lookups.

## Codex continuity

- For a new session with an existing task, run:
  `agent-workflow session-start --runtime codex --cwd "$PWD"`.
- Use the returned experience bundle only when it matches the current scope.
- Record meaningful verified milestones with the Context Harness checkpoint.

## Codex-native skills

- `architecture-review`, `auto-spec`, `context-prompt-discipline`, `diagnose`,
  `human-voice`, `prototype`, `reverse-skill-router`, `sdd`, and `tdd` are
  loaded from `config/ai/codex/skills/`.
- `final-state-publication` is the only shared skill installed by default.

## Pilotfish

Pilotfish remains an optional orchestration layer for bounded routing, approval,
security, isolation, and verification. Use its skill when the task requires
those controls; it does not replace the shared contract or this adapter.
