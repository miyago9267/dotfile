# OpenCode Studio Demo and Benchmark Plan

Phase 5 is a manual validation layer. Run demos only when the target repo and tool availability are safe.

## Demo 1: Studio dry-run without file modification

Prompt:

```text
Use `art-director` only. Scope: this repository's OpenCode Studio docs. Summarize what creative/game tasks this harness supports. Do not edit files. Return scope, files read, findings, risks, and next action.
```

Expected:

- No files changed.
- Output follows compact contract.
- Studio config remains `default_agent=studio-monika`.

## Demo 2: Generated-asset path dry-run

Prompt:

```text
Use `asset-worker`. Create only a text manifest for a placeholder 32x32 coin icon under `.ai/artifacts/studio-demo/`. Do not generate binary files. If no tools are needed, write the manifest only. Return output path and verification result.
```

Expected:

- Only `.ai/artifacts/studio-demo/` changes.
- No source assets overwritten.
- Binary content is not pasted into chat.

## Demo 3: Game-engine project inspection dry-run

Prompt:

```text
Use `game-engine-worker`. Inspect <project path> for Godot/Unity/Unreal markers. Do not edit files. Report detected engine, key config files, available CLI command, fallback plan, and risks.
```

Recommended command form for repo-external projects:

```sh
ocstudio run --dir "<project path>" 'Use `game-engine-worker`. Inspect the current directory for Godot/Unity/Unreal markers. Do not edit files. Do not inspect parent directories. Report detected engine, key config files, available CLI command, fallback plan, and risks. Keep output under 20 bullets.'
```

Expected:

- No files changed.
- Missing tools are reported, not installed.
- Affected-file plan is included before any future edit proposal.

## Metrics to record

- Entrypoint: `ocstudio`, `och`, or raw `opencode`
- Model route and agent/subagent used
- Wall-clock time
- Files read and changed
- Tool detection results
- Verification commands and result
- Remaining uncertainty

## Current status

- Phase 1-2 validation is complete.
- Phase 3-5 docs are complete.
- Demo 3 passed on `/Users/miyago/Project/Assignments/micro-device/final` with `ocstudio run --dir ...`: `game-engine-worker` detected Godot 4.6.1, found `godot/project.godot`, scenes/scripts, CLI `/opt/homebrew/bin/godot`, and reported `Changes made: none`.
- Demo 1 and Demo 2 remain optional manual demos; Demo 2 intentionally writes `.ai/artifacts/studio-demo/`.
