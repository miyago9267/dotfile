---
name: miyago-agent-rules
description: 為 Zed 載入 Miyago 的 global agent behavior、rules、workflow preferences、safety policy、skills、plugin 與 MCP resource map。coding、debugging、documentation、planning、operations 或 repository work 開始時使用。
---

# Miyago Agent Rules for Zed（Zed 規則）

這個 skill 是 Zed 的 entrypoint，提供儲存在 `~/dotfile` 的 shared Claude/Codex
agent behavior。

此 skill 啟用時，以下列出的 files 是 authoritative rule sources，依 priority order
使用：

1. Shared agent rules：`~/.agents/rules/SHARED_AGENTS.md` → `~/dotfile/config/ai/AGENTS.md`
2. Claude behavior rules：`~/.agents/rules/CLAUDE.md` → `~/dotfile/config/ai/claude/CLAUDE.md`
3. Codex behavior rules：`~/.agents/rules/CODEX_AGENTS.md` → `~/dotfile/config/ai/codex/AGENTS.md`

## 可用的同步資源

- Zed global skills 會同步到 `~/.agents/skills`。
- Claude skills source：`~/dotfile/config/ai/claude/skills`。
- Codex skills source：`~/dotfile/config/ai/codex/skills`。
- Local plugin marketplace：`~/.agents/plugins/marketplace.json`。
- Local plugin payloads：`~/.agents/plugins/plugins/monika-codex` 與
  `~/.agents/plugins/plugins/monika-claude`。

## 執行指引

- 和 runtime-specific details 衝突時，優先使用 `SHARED_AGENTS.md` 的 shared rules。
- Claude/Codex rules 可作為 behavioral guidance；除非 current Zed environment 明確
  提供，不要假設 Zed 支援 Claude/Codex-only hooks、slash commands、plugins、MCP
  config 或 runtime session formats。
- 永遠不要在 runtimes 之間複製 auth/session/cache/runtime files。
- Synced skill 的 description 符合 user task 時，直接使用該 skill。
