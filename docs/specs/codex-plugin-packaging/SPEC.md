---
id: spec-codex-plugin-packaging
title: Package Monika Codex Agent Settings as a Codex Plugin
status: implemented
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [codex, plugin, agents, packaging]
priority: high
---

# Package Monika Codex Agent Settings as a Codex Plugin

## Background

目前 repo 已有：

- shared contract：`config/ai/AGENTS.md`
- Codex adapter：`config/ai/codex/AGENTS.md`
- Claude plugin 雛形：`config/ai/claude-plugin/`

但 Codex 還沒有自己的可發布 plugin。現況只有 `AGENTS.md` 內容可手動引用，缺少：

- Codex plugin manifest
- repo-local marketplace 入口
- 可重建的 build/export 流程
- 專案初始化模板

## Requirements

- When Codex agent settings are packaged, the system shall keep `config/ai/*` as the source of truth.
- When the plugin artifact is rebuilt, the system shall regenerate `plugins/monika-codex/` from source files and curated allowlists.
- When the plugin is used for project bootstrap, the system shall provide a composed `AGENTS.md` plus spec templates.
- When the plugin is listed in a local marketplace, the system shall expose one `monika-codex` entry pointing to `./plugins/monika-codex`.
- When Codex-specific packaging is introduced, the system shall not claim Claude-only commands, agents, or hooks as Codex plugin components.
- When the Codex install script runs, the system shall build and install `monika-codex` into the user's local plugin directories automatically.

## Decisions

### ADR-1: Dotfile stays source of truth

- Decision: maintain shared contract and Codex adapter in `config/ai/*`; build the plugin artifact from there.
- Reason: avoids copy-paste drift and keeps runtime adapters centralized.

### ADR-2: Codex plugin ships Codex-consumable toolkit only

- Decision: package manifest, skills, templates, and runtime-neutral scripts.
- Reason: Claude-specific commands, agents, and hooks are not directly consumable by Codex plugin loading.

### ADR-3: Artifact is committed

- Decision: commit `plugins/monika-codex/` and `.agents/plugins/marketplace.json` alongside build scripts.
- Reason: enables repo-local install/testing and makes release diffs inspectable.

## Source Mapping

- Shared contract source: `config/ai/AGENTS.md`
- Codex adapter source: `config/ai/codex/AGENTS.md`
- Plugin source metadata: `config/ai/codex-plugin/`
- Generated plugin artifact: `plugins/monika-codex/`
- Generated marketplace entry: `.agents/plugins/marketplace.json`

## Non-goals

- 不在這次實作中拆出獨立 Git repo
- 不在這次實作中重新設計全部 skills 內容
- 不在這次實作中為 Codex 增加 Claude hooks / commands 相容層
