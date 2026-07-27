---
id: spec-grok-runtime-isolation
title: Grok Runtime Isolation and Controlled Claude Compatibility
status: in-progress
created: 2026-07-22
updated: 2026-07-22
author: Miyago
tags: [grok, claude, compatibility, isolation, agents, persona]
priority: high
---

# Grok Runtime Isolation and Controlled Claude Compatibility

## Background

Grok discovers native configuration and Claude-compatible paths in the same
session. Claude compatibility can therefore import project instructions,
skills, plugins, hooks, and subagent definitions into a Grok session. The
`compat.claude.agents` flag controls instruction compatibility and does not
currently gate `.claude/agents` subagent discovery.

Grok needs a native Monika layer while keeping Claude compatibility explicit,
reversible, and isolated from normal use.

## Goal

Make the Claude loading surface controllable without changing Claude Code's
own home, agents, hooks, or settings.

## Requirements (EARS)

- **R1**: When Grok runs in native mode, it shall load the Grok persona adapter
  and shall not inherit the user's Claude home or project Claude discovery
  surface.
- **R2**: When Grok runs in native mode, it shall disable Claude compatibility
  cells through environment overrides as defense in depth.
- **R3**: When Grok runs in compatibility mode, it shall use the normal home and
  preserve the user's existing Grok configuration and Claude discovery behavior.
- **R4**: The setup script shall install launchers without overwriting Grok
  auth, sessions, marketplace, or Claude state.
- **R5**: Native and compatibility launchers shall be explicit and separately
  testable; the bare `grok` command shall remain untouched.
- **R6**: Verification shall prove native mode excludes Claude instructions and
  Claude agents while compatibility mode remains available.
- **R7**: Repository-managed Grok files shall not contain credentials or
  machine-local session state.

## Non-goals

- Do not rename, move, or delete `~/.claude/agents`.
- Do not change Claude Code configuration or hooks.
- Do not claim `compat.claude.agents = false` independently fixes subagent
  discovery.
- Do not replace Grok's existing user config wholesale.
- Do not send prompts to the external Grok service during local verification.

## Architecture

### Native mode

`grok-native` captures the real Grok state directory, then runs Grok with a
private synthetic `HOME`. This prevents Grok's home-level Claude discovery while
keeping auth and Grok state in `GROK_HOME`. Compatibility environment variables
are also set to `false` for defense in depth.

### Compatibility mode

`grok-compat` runs with the user's normal `HOME` and `GROK_HOME`, explicitly
setting Claude compatibility variables to `true`. This is an opt-in escape
hatch for sessions that intentionally need Claude-compatible content.

### Source layers

1. Grok-native adapter: `config/ai/grok/AGENTS.md`
2. Explicit configured shared skills: existing `[skills].paths`
3. Optional vendor compatibility: selected by launcher mode
4. Claude runtime source: never modified by Grok setup

## Verification

- `bash -n` and `shellcheck` pass for setup and launchers.
- `grok-native inspect --json` has no Claude project instructions or Claude
  agents and still reports the Grok adapter.
- `grok-compat inspect --json` can see the existing Claude surface when the
  user's compatibility settings permit it.
- Re-running setup is idempotent.
- `git diff --check` passes and existing unrelated changes remain untouched.
