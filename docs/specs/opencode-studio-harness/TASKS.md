# Tasks

## Phase 1: Harness validation

- [x] Run `och` dry-run and confirm `monika-large` starts with `task: allow`.
- [x] Verify at least one bounded subagent can be invoked from `och`.
- [x] Verify `repo-explorer` returns scope, files read, findings, confidence, and uncertainty.
- [x] Verify `reviewer` can review a small diff without editing files.
- [x] Document dry-run prompts in `config/opencode/USAGE.md` or a studio usage doc.

## Phase 2: Studio skeleton

- [x] Create `config/opencode-studio/opencode.json`.
- [x] Create `config/opencode-studio/AGENTS.md`.
- [x] Create `config/opencode-studio/agents/studio-monika.md`.
- [x] Create `art-director`, `asset-worker`, `multimodal-looker`, `game-engine-worker`, `technical-artist`, and `qa-playtester` agents.
- [x] Add `ocstudio` zsh function that points `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` to the studio config.
- [x] Document rollback path.

## Phase 3: Toolchain capability matrix

- [x] Document detection commands for ImageMagick, ffmpeg, Blender, Aseprite, Godot, Unity, Unreal, Tiled, LDtk, and ComfyUI.
- [x] Define fallback behavior for missing tools.
- [x] Keep all new external MCP/API integrations disabled by default.

## Phase 4: Workflow prompts

- [x] Add prompt recipe for reference image analysis.
- [x] Add prompt recipe for sprite / icon / texture placeholder generation.
- [x] Add prompt recipe for Godot scene/script change.
- [x] Add prompt recipe for shader/VFX review.
- [x] Add prompt recipe for qa-playtester report.

## Phase 5: Demo and benchmark

- [x] Add a studio dry-run prompt without file modification.
- [x] Add a generated-asset path dry-run prompt.
- [x] Add a game-engine project inspection dry-run prompt.
- [x] Define wall-clock, model route, files touched, and validation result metrics.
