# OpenCode Studio Workflow Prompts

Use these through `ocstudio` unless the task is pure code or general large-engineering work.

## Reference image analysis

```text
Use `multimodal-looker` and `art-director`.
Scope: analyze these reference files/paths: <paths>.
Output: visual motifs, palette, silhouettes, UI/asset constraints, risks, and next asset brief.
Limits: read-only; do not generate files; do not use unverified provider routes.
```

## Sprite / icon / placeholder asset generation

```text
Use `art-director` for the brief, then `asset-worker` for generated placeholders.
Goal: create <asset type> for <game/context>.
Inputs: <paths or none>.
Output path: `.ai/artifacts/<task-slug>/` unless I specify another generated path.
Constraints: do not overwrite source assets; use only tools already available; if tools are missing, write a manifest/spec instead.
Return: output paths, format/dimensions, command used, verification result, and risks.
```

## Godot scene/script change

```text
Use `game-engine-worker`.
Engine: Godot first-class path.
Scope: <project path>, target scene/script <paths>.
Task: <change request>.
Before edits: list affected-file plan.
Verification: prefer static checks or safe Godot CLI command if available; do not run destructive imports or migrations.
Return: files changed, verification command/result, runtime risks, and next action.
```

## Shader / VFX / import pipeline review

```text
Use `technical-artist`.
Scope: <shader/material/import files>.
Task: review or patch <specific issue>.
Before edits: list affected-file plan.
Constraints: do not overwrite source assets; keep edits scoped; do not install plugins/packages.
Return: visual risk, files changed/read, verification plan, and unresolved engine-specific uncertainty.
```

## QA playtest report

```text
Use `qa-playtester`.
Surface: <scene/route/asset/build command>.
Evidence: <logs/screenshots/user notes or command to run>.
Constraints: read-only; do not edit files.
Return: exact environment, steps tested, findings, reproduction steps, evidence, and risk ranking.
```
