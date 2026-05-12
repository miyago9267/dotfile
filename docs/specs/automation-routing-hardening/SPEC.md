---
id: spec-automation-routing-hardening
title: Automation Routing Hardening for Skills, Hooks, and MCP
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [automation, skills, hooks, mcp, claude, codex, gemini]
priority: high
---

# Automation Routing Hardening for Skills, Hooks, and MCP

## Background

目前自建的自動化已經有明顯基礎：

- 多個 `skills/`
- 一組 Claude hooks
- shared `AGENTS.md`
- runtime specialization

但距離「少量溝通即可高效操作」還有三個缺口：

1. 高頻 skill 缺少一致 metadata，導致自動路由依賴 description 與隱性慣例
2. `skill` / `hook` / `MCP` 的責任分工沒有正式制度化
3. Claude hooks 已可用，但事件面仍偏窄，缺少 compact、cwd、instructions、subagent、task completion 這類高價值自動化

## Requirements (EARS)

- **R1**: When a shared skill is authored or updated, the system shall require consistent routing metadata including `when_to_use`, `tags`, `effort`, `shell`, and `runtime-scope`
- **R2**: When a capability can be executed deterministically from an event with low side effects, the system shall prefer a hook over a skill reminder
- **R3**: When a capability requires contextual reasoning or multi-step domain workflow, the system shall prefer a skill over a hook
- **R4**: When a capability depends on live external state or third-party platform interaction, the system shall prefer MCP or equivalent external-tool integration over local prompt-only logic
- **R5**: While runtime roles remain specialized, the system shall treat role specialization as a default bias rather than deleting overlapping capabilities
- **R6**: When Claude runtime automation is expanded, the system shall add high-value event hooks for `InstructionsLoaded`, `CwdChanged`, `PreCompact`, `PostCompact`, `SubagentStop`, and `TaskCompleted`
- **R7**: When new hooks are added, they shall stay short, low-noise, and non-destructive
- **R8**: When high-frequency skills are updated, the system shall backfill the new metadata without changing their core workflow semantics

## Non-goals

- 不在這一批導入 `http` hook server
- 不在這一批導入 `mcp_tool` hook
- 不在這一批重寫全部 20+ skills 的正文
- 不在這一批更動 non-Claude runtime 的 hook 系統

## Architecture

### Routing order

1. deterministic + event-driven + low-side-effect -> `hook`
2. contextual + workflow-driven -> `skill`
3. live external state / service interaction -> `MCP`
4. 以上都不足才詢問使用者

### Metadata contract

每個高頻 skill 至少有：

- `name`
- `description`
- `when_to_use`
- `tags`
- `effort`
- `shell`
- `runtime-scope`
- `alwaysApply` 或 `user-invocable`

### High-frequency first batch

- `code-review`
- `health-check`
- `log-analysis`
- `issue-ops`
- `repo-status`
- `project-map`
- `auto-spec`
- `search-discipline`
- `efficiency`
- `docker-k8s`

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| metadata 太多導致維護成本上升 | medium | 先限制在高頻 skill，欄位定義保持短而固定 |
| hook 新事件造成上下文噪音 | medium | 每支 hook 僅輸出 1-3 行高密度提示 |
| 路由規則寫進 shared 後與 runtime adapter 打架 | low | shared 只定優先序與欄位契約，runtime-specific 行為留在 adapter |
