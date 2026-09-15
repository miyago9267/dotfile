---
name: miyago-agent-rules
description: "Zed task 需要 Miyago shared rules、Astra identity、runtime config 或 skill routing 時使用。一般 coding 不觸發。"
when_to_use: "只有需要載入或判斷 agent 規則邊界時觸發；self-contained edit 跳過。"
tags: [zed, agent-rules, astra, runtime, skills]
effort: low
shell: optional
runtime-scope: shared-core
alwaysApply: false
---

# Miyago Agent Rules for Zed（Zed 規則）

這個 skill 是 Zed 的 entrypoint，提供儲存在 `~/dotfile` 的 shared agent
behavior 與 Astra compatibility routing。

此 skill 啟用時，以下列出的 files 是 authoritative rule sources，依 priority order
使用：

1. Entry boundary：`~/dotfile/config/ai/AGENT-ENTRY.md`
2. Shared rules：`~/dotfile/config/ai/AGENTS.md`
3. Current runtime adapter：只讀目前使用 runtime 的
   `~/dotfile/config/ai/<runtime>/AGENTS.md`；不因為 Zed 啟動就讀 Claude、Codex、Gemini 全套。

## Identity

Astra 是唯一 canonical identity。`Monika`、`monika`、`monika-large`、
`studio-monika` 只保留為舊 runtime、plugin 與 OpenCode ID 的 compatibility
aliases，不建立第二個 persona。

## 可用的同步資源

- Zed global skills 會同步到 `~/.agents/skills`。
- Shared skills source：`~/dotfile/config/ai/shared/skills`。
- Current runtime skill source：`~/dotfile/config/ai/<runtime>/skills`。
- Explicit Astra profile：`~/dotfile/config/ai/astra/`。
- Local plugin marketplace：`~/.agents/plugins/marketplace.json`。
- Local plugin payloads：`~/.agents/plugins/plugins/monika-codex` 與
  `~/.agents/plugins/plugins/monika-claude`；舊名稱保留作為 compatibility IDs。

## 執行指引

- 和 runtime-specific details 衝突時，優先使用 `config/ai/AGENTS.md` 的 shared rules。
- Claude/Codex rules 可作為 behavioral guidance；除非 current Zed environment 明確
  提供，不要假設 Zed 支援 Claude/Codex-only hooks、slash commands、plugins、MCP
  config 或 runtime session formats。
- 永遠不要在 runtimes 之間複製 auth/session/cache/runtime files。
- Synced skill 的 description 明確符合 user task 時才使用；不要因為 skill 名稱相近
  就載入它。Astra profile 預設只用 shared contract、`safe-ops` 與一個明確 task skill。
