---
id: spec-opencode-studio-harness
title: OpenCode Studio Harness for Creative and Game-Engine Work
status: proposed
created: 2026-06-02
updated: 2026-06-02
author: Monika
tags: [opencode, harness, subagents, creative, game-engine, multimodal, assets]
priority: high
---

# OpenCode Studio Harness for Creative and Game-Engine Work

## Background

Miyago wants OpenCode to grow beyond a slim coding harness into a Codex Desktop-like workbench that can coordinate software engineering, visual assets, browser research, and game-engine workflows.

Current runtime split:

- `opencode`: slim daily path, no subagent, low fixed context cost
- `och` / `opencode-harness`: large engineering path, bounded subagents, Playwright MCP, oh-my-openagent Team Mode
- `ulw`: aggressive large-work orchestration through the harness path

This spec introduces a separate studio harness so creative/game-engine capabilities do not pollute the daily path.

## Goals

- Add an explicit `opencode-studio` / `ocstudio` entrypoint for creative and game-engine tasks.
- Preserve the existing slim `opencode` daily path.
- Preserve `och` as the general large-engineering harness.
- Add role-specific studio agents for art, assets, game engines, technical art, and multimodal inspection.
- Keep all new external tools and MCP integrations disabled by default unless they already exist and are safe to reuse.
- Define safe output boundaries for generated assets and engine project modifications.

## Non-goals

- Do not install Blender, Aseprite, Godot, Unity, Unreal, ComfyUI, or new MCP servers in Phase 1-2.
- Do not enable new paid APIs or secrets.
- Do not replace Codex Desktop.
- Do not make daily `opencode` heavier.
- Do not allow agents to overwrite source assets without explicit confirmation.

## Requirements

- When daily `opencode` starts, the system shall remain slim and keep `task` denied.
- When `och` starts, the existing large engineering harness shall keep its current behavior.
- When `ocstudio` starts, the system shall use a separate config directory and a studio primary agent.
- When studio work uses subagents, each subagent shall have explicit file/tool boundaries and a compact output contract.
- When assets are generated, the system shall write them to a generated/artifacts path rather than overwriting source assets.
- When engine projects are modified, the system shall list touched files and verification commands.
- When an external tool is unavailable, the system shall report the missing capability and provide a fallback plan rather than installing it.
- When browser or docs research is needed, the system shall bound page count, depth, and raw output.

## Architecture

### Entrypoints

| Entrypoint | Purpose | Fixed cost | Subagents | MCP/browser |
| --- | --- | --- | --- | --- |
| `opencode` | Daily code/docs tasks | low | no | no default MCP |
| `och` | Large engineering | medium/high | bounded | Playwright enabled |
| `ulw` | Aggressive orchestration | high | team mode | harness tools |
| `ocstudio` | Creative/game-engine work | medium/high | bounded studio agents | browser optional, toolchain disabled by default |

### Proposed config layout

```text
config/opencode-studio/
  opencode.json
  AGENTS.md
  agents/
    studio-monika.md
    art-director.md
    asset-worker.md
    multimodal-looker.md
    game-engine-worker.md
    technical-artist.md
    qa-playtester.md
```

### Studio agents

| Agent | Role | Default permissions |
| --- | --- | --- |
| `studio-monika` | Primary planner/router for studio tasks | task allow, edits controlled |
| `art-director` | Style, reference, asset specs | read-only, web allowed |
| `asset-worker` | Generate or transform assets via existing CLI tools | write only to generated/artifacts paths |
| `multimodal-looker` | Inspect screenshots/images/assets | read-only, multimodal model route |
| `game-engine-worker` | Godot/Unity/Unreal project changes | scoped edit, no destructive ops |
| `technical-artist` | Shaders, VFX, import pipeline | scoped edit |
| `qa-playtester` | Run targeted checks, capture findings | read/test, no edits |

## Safety model

- Generated files go under one of:
  - `.ai/artifacts/`
  - `generated/`
  - project-specific generated asset folder documented in the task
- Source asset overwrite requires explicit Miyago confirmation.
- Engine project edits require an affected-file plan before patching.
- Large binary outputs are summarized by path, dimensions, format, and generation command; raw binary content never enters context.
- Tool installation is out of scope; agents may detect tools with `command -v` and report missing tools.

## Phase plan

### Phase 1: Harness and subagent validation

- Confirm `och` can invoke bounded subagents.
- Add documented dry-run prompts for `repo-explorer`, `browser-crawler`, and `reviewer`.
- Keep daily path unchanged.

### Phase 2: Studio harness skeleton

- Add `config/opencode-studio/` with separate primary agent and studio subagents.
- Add `ocstudio` zsh function.
- Add documentation and rollback path.

### Phase 3: Toolchain capability matrix

- Add detection-only scripts or docs for Blender, Aseprite, ImageMagick, ffmpeg, Godot, Unity, Unreal, Tiled, LDtk, and ComfyUI.
- Keep unavailable tools as reported capabilities, not install steps.

### Phase 4: Creative/game workflows

- Add reusable prompts for reference analysis, sprite spec, placeholder asset generation, Godot scene edits, shader/VFX review, and playtest reports.

### Phase 5: Benchmarks and demos

- Run bounded demo scenarios and record cost, wall-clock, files touched, and validation results.

## Rollback

Rollback should require only:

- Delete `config/opencode-studio/`
- Remove `ocstudio` from `config/zsh/.zshrc.d/opencode.zsh`
- Re-run dotfile setup if symlinks were added

## Open questions

- Which engine should be first-class first: Godot, Unity, or Unreal?
- Should generated assets live in repo-local `generated/` or `.ai/artifacts/` by default?
- Which multimodal route is preferred for image inspection: OpenAI, Gemini through Copilot, or another provider?
