---
id: spec-claude-plugin-packaging
title: Package Monika Claude Plugin as a Rebuildable Artifact
status: implemented
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [claude, plugin, packaging, agents]
priority: high
---

# Package Monika Claude Plugin as a Rebuildable Artifact

## Background

repo 內已經有 `config/ai/claude-plugin/`，但它目前是 source tree 與半成品混合：

- 內含 `.claude-plugin/plugin.json` 與 marketplace metadata
- 內含 commands / agents / skills / hooks / scripts / templates
- 尚未有統一的 artifact build/validate 流程
- 尚未產出與 Codex 一致的 `plugins/*` 發布目錄

## Requirements

- When the Claude plugin is packaged, the system shall keep `config/ai/claude-plugin/` as the source of truth.
- When the plugin artifact is rebuilt, the system shall generate `plugins/monika-claude/` from the source tree without copying `.git`.
- When the artifact is generated, the system shall expose Claude plugin metadata under the `monika-claude` name in the artifact.
- When validation runs, the system shall confirm the generated artifact contains manifest, marketplace metadata, install script, and representative plugin content.
- When the Claude install script runs, the system shall rebuild and install the Claude plugin automatically after CLI installation or upgrade checks.

## Decisions

### ADR-1: Preserve Claude source layout

- Decision: keep `config/ai/claude-plugin/` as-is and layer packaging scripts on top.
- Reason: avoids a disruptive refactor of an already structured plugin source tree.

### ADR-2: Artifact gets Monika branding

- Decision: generate `plugins/monika-claude/` with rewritten manifest, marketplace file, and README.
- Reason: matches the new Codex packaging direction while leaving existing source naming intact.

## Non-goals

- 不在這次實作中改寫 Claude plugin 的 commands、skills 或 install workflow
- 不在這次實作中拆掉 `dev-discipline` 既有 source 命名
