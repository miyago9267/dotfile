# OpenCode Studio Toolchain Matrix

Phase 3 policy: detection-only. Agents may check whether a tool exists, but must not install tools, enable new MCP servers, or modify secrets.

## Defaults

- Default artifact root: `.ai/artifacts/`
- First-class engine priority: Godot first, then Unity, then Unreal
- Browser/MCP: Playwright is configured but disabled by default
- Missing tools: report the missing command and fallback plan

## Capability matrix

| Capability | Tool | Detection command | Use when available | Fallback when missing |
| --- | --- | --- | --- | --- |
| Raster image inspect/convert | ImageMagick | `command -v magick || command -v convert` | image metadata, resize, format conversion | describe manual steps or use existing file metadata only |
| Audio/video/frame processing | ffmpeg | `command -v ffmpeg && command -v ffprobe` | extract frames, convert audio/video, inspect streams | request exported frames or metadata from Miyago |
| 3D assets/render scripting | Blender | `command -v blender` | run existing `.blend` scripts, inspect/export via CLI | produce Blender Python script only, do not run |
| Pixel art/sprites | Aseprite | `command -v aseprite` | export spritesheets from existing files | write sprite spec/manifest only |
| Godot projects | Godot | `command -v godot || command -v godot4` | inspect project, run targeted headless checks when safe | static file inspection and suggested command |
| Unity projects | Unity | `command -v unityhub || command -v Unity` | document batchmode command if present | static inspection of `Assets/`, `Packages/`, `ProjectSettings/` |
| Unreal projects | Unreal | `command -v UnrealEditor || command -v RunUAT.sh` | document AutomationTool/editor command if present | static inspection of `.uproject`, `Config/`, `Content/` manifests |
| Tile maps | Tiled | `command -v tiled` | inspect/export `.tmx`/`.tsx` if CLI available | static XML/JSON inspection |
| Level data | LDtk | `command -v ldtk` | inspect/export project if CLI available | static JSON inspection |
| Local image generation | ComfyUI | `test -d ~/ComfyUI || test -d /Applications/ComfyUI.app` | only report availability; do not invoke by default | produce prompt/spec for external generation |

## Agent behavior

- `asset-worker` may write only under `.ai/artifacts/`, `generated/`, or a task-declared generated path.
- `game-engine-worker` must list affected files before modifying engine projects.
- `technical-artist` must keep shader/VFX/import edits scoped to declared files.
- `qa-playtester` should prefer real commands, logs, screenshots, or user-provided captures.
- Any destructive command, source asset overwrite, package installation, or project migration requires explicit Miyago confirmation.
