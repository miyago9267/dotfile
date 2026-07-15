---
name: miyago-agent-rules
description: Load Miyago's global agent behavior, rules, workflow preferences, safety policy, skills, plugin and MCP resource map for Zed. Use at the start of coding, debugging, documentation, planning, operations, or repository work.
---

# Miyago Agent Rules for Zed

This skill is the Zed entrypoint for the shared Claude/Codex agent behavior stored in `~/dotfile`.

When this skill is active, treat the following files as the authoritative rule sources, in priority order:

1. Shared agent rules: `~/.agents/rules/SHARED_AGENTS.md` → `~/dotfile/config/ai/AGENTS.md`
2. Claude behavior rules: `~/.agents/rules/CLAUDE.md` → `~/dotfile/config/ai/claude/CLAUDE.md`
3. Codex behavior rules: `~/.agents/rules/CODEX_AGENTS.md` → `~/dotfile/config/ai/codex/AGENTS.md`

## Available synced resources

- Zed global skills are synced under `~/.agents/skills`.
- Claude skills source: `~/dotfile/config/ai/claude/skills`.
- Codex skills source: `~/dotfile/config/ai/codex/skills`.
- Local plugin marketplace: `~/.agents/plugins/marketplace.json`.
- Local plugin payloads: `~/.agents/plugins/plugins/monika-codex` and `~/.agents/plugins/plugins/monika-claude`.

## Operating guidance

- Prefer the shared rules in `SHARED_AGENTS.md` when they conflict with runtime-specific details.
- Use Claude/Codex rules as behavioral guidance, but do not assume Zed supports Claude/Codex-only hooks, slash commands, plugins, MCP config, or runtime session formats unless they are explicitly available in the current Zed environment.
- Never copy auth/session/cache/runtime files between runtimes.
- Use the synced skills directly when their descriptions match the user's task.
