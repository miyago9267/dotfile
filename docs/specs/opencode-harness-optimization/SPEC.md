---
id: spec-opencode-harness-optimization
title: OpenCode Harness Optimization and Prompt Diet
status: archived
created: 2026-05-27
updated: 2026-05-27
author: Codex
tags: [opencode, harness, prompt, subagents, mcp, plugins, token-control]
priority: high
archived: 2026-05-27
---

# OpenCode Harness Optimization and Prompt Diet

## Archive Summary

Archived on 2026-05-27 after implementing the activation-ready split:

- Daily `opencode` path uses only the slim `monika` primary agent
- Heavy `oh-my-openagent`, MCP servers, and subagents moved to explicit `opencode-harness` / `och`
- Default daily path has no MCP, no plugin, no task tool, and no skill tool
- Harness path keeps bounded subagents and Playwright/browser MCP for large or research-heavy work
- Harness path enables oh-my-openagent Team Mode with conservative member and runtime bounds
- Small daily dry-run and browser-crawler MCP dry-run both passed
- Full large multi-subagent simulation is deferred until the first real large task, because it is not an activation blocker and would spend unnecessary tokens

## Background

OpenCode 已經接上 `oh-my-openagent`，目前可用 provider 包含：

- OpenAI OAuth / Codex 系列
- GitHub Copilot OAuth
- DeepSeek API

現況適合當成新的 harness playground，但還不適合直接重度日用。主要原因是：

1. `oh-my-openagent` 的主 agent prompt 很大，且預設鼓勵大量 parallel delegation
2. `~/.claude/skills` 仍會被掃入 OpenCode resolved prompt，造成 prompt 污染與 token 浪費
3. subagent 能力很有價值，但需要任務分級、輸出格式與讀檔責任邊界
4. MCP 與 browser crawler 應該被大量使用，但必須限制 crawl 範圍、摘要格式與快取策略
5. plugin 生態有 token / quota / ignore / memory / orchestration 類工具，但上線前需要分層評估

本 spec 的目標是在正式使用前先替 OpenCode harness 減肥，保留大工程下的多 agent 優勢，同時避免主 session 被重複讀寫、長 prompt、背景任務與工具輸出污染。

## Requirements (EARS)

- **R1**: When OpenCode starts a normal task, the default agent shall use a slim Miyago-specific prompt rather than the full `oh-my-openagent` heavy orchestration prompt
- **R2**: When a task is small or single-file, the harness shall avoid spawning subagents unless the user explicitly asks for delegation
- **R3**: When a task is medium-sized, the harness shall allow at most one or two bounded subagents with non-overlapping read scopes
- **R4**: When a task is large engineering work, the harness shall prefer subagents for exploration, implementation, review, and browser research so the main session stays focused
- **R5**: When subagents are used, each subagent shall return a compact summary, touched files, evidence, and next action instead of raw logs
- **R6**: When browser crawling is needed, the harness shall prefer MCP/browser tooling with explicit URL scope, depth, page count, deduplication, and source capture
- **R7**: When MCP servers are added, each server shall have a clear job, permission boundary, and disable path
- **R8**: When plugins are installed, token-control and safety plugins shall take priority over additional orchestration frameworks
- **R9**: When `oh-my-openagent` remains installed, heavy agents such as `Sisyphus` shall be reserved for explicit ultra-work / large-task flows
- **R10**: When Claude-derived skills are exposed to OpenCode, the system shall expose only an allowlist or native OpenCode adapters, not the full Claude runtime surface
- **R11**: When the harness reads the Obsidian knowledge base, it shall use targeted `rg` searches and bounded node reads before delegating or writing notes
- **R12**: When token usage grows, the harness shall provide local observability through `opencode stats` and at least one plugin or command that surfaces token/context pressure

## Priority Plan

### P0: Baseline, Safety, and Reversibility

上線前必做。

- Capture current `opencode debug config`, model list, provider list, and `opencode stats`
- Keep OpenCode config symlinked from dotfiles and keep npm/bun plugin artifacts ignored
- Add explicit `share: "disabled"` if supported by current config schema
- Add watcher / ignore rules for `node_modules`, secrets, generated caches, logs, and vault trash
- Keep risky Claude-only skills denied or unexposed
- Keep direct `google/*` and `anthropic/*` routes out until credentials exist

### P1: Prompt Diet

上線前必做。

- Create a slim daily OpenCode agent that carries Miyago identity, core engineering rules, token discipline, and knowledge-base access only
- Reserve `oh-my-openagent` heavy agents for explicit `ulw` / large engineering flows
- Reduce duplicate rule text between `opencode.json`, `AGENTS.md`, plugin prompt, and skill prompts
- Stop full `~/.claude/skills` prompt leakage where possible; otherwise document it as a known residual risk and compensate with explicit skill deny rules
- Validate resolved prompt after changes with `opencode debug config`

### P2: Subagent Strategy for Large Engineering

High priority after P0/P1.

- Define task size classes: small, medium, large, research-heavy, browser-heavy
- Add OpenCode-specific subagent roles:
  - `repo-explorer`: read-only codebase locator
  - `vault-librarian`: read-only Obsidian knowledge-base searcher
  - `browser-crawler`: bounded web/MCP crawler
  - `implementation-worker`: scoped file owner for implementation
  - `reviewer`: diff and risk reviewer
- Require each subagent to declare scope, files read, sources used, confidence, and remaining uncertainty
- Prefer subagents for large work to reduce main-session context pollution
- Prevent duplicate exploration by assigning one owner per search axis

### P3: MCP and Browser Crawler Layer

High priority after subagent policy.

- Add a browser crawling MCP path for documentation, changelog, GitHub issue, and web research tasks
- Add a docs/context MCP path for library documentation if it proves lighter than browser crawling
- Keep GitHub MCP/plugin usage scoped to PR / issue / CI tasks
- Require browser crawler outputs to include canonical URLs, retrieval time, page count, and summary
- Add crawl limits: default max pages, max depth, same-domain policy, and raw-content truncation

### P4: Plugin Evaluation and Install Queue

Medium priority. Install only after P0/P1 baseline.

| Candidate | Priority | Why | Risk |
| --- | --- | --- | --- |
| `opencode-snip` | high | Filters noisy shell output before it enters context | May hide useful logs if over-aggressive |
| `Context Analysis` | high | Shows token usage and context pressure | Observability only; does not reduce usage alone |
| `Dynamic Context Pruning` | high | Prunes obsolete tool outputs from conversation context | Needs compatibility test with `oh-my-openagent` |
| `Envsitter Guard` | high | Prevents `.env*` value leaks while preserving safe inspection | Must not block intended secret key-name checks |
| `Opencode Ignore` | high | Adds explicit file/dir ignore behavior | Pattern mistakes can hide needed files |
| `Opencode Quota` / `opencode-mystatus` | medium | Tracks provider quotas and subscription pressure | Provider support may lag model/auth changes |
| `Handoff` | medium | Creates cleaner session handoff prompts | Could duplicate existing docs/spec workflow |
| `Background Agents` / `OpenCode Agent Tmux` | low | Better visibility for async agents | Adds more orchestration before prompt diet is done |
| `Micode` / `Opencode Workspace` / similar mega-harnesses | defer | Powerful, but overlaps with `oh-my-openagent` | High prompt and behavior stacking risk |

## Non-goals

- 不在這一階段把 OpenCode 取代 Codex 或 Claude
- 不在這一階段安裝第二套大型 orchestration harness
- 不在這一階段把 Claude hooks、Claude commands、Claude memories 全部移植成 OpenCode native behavior
- 不在這一階段讓 browser crawler 無限制爬外部網站
- 不在這一階段重做所有 shared skills

## Architecture

### Runtime Split

- `Codex`: 主力實作與本地驗證
- `Claude`: 規劃、長文、流程與既有 Pro 使用情境
- `OpenCode`: multi-model harness、cheap parallel runner、browser/MCP-heavy sidecar
- `DeepSeek`: cheap burst / fallback
- `Copilot`: quota-friendly fallback and Gemini/Claude model access through Copilot provider

### OpenCode Layers

1. **Slim Daily Layer**
   - small prompt
   - no default subagent fan-out
   - strict token discipline
   - knowledge-base access by targeted search

2. **Large Engineering Layer**
   - explicit large-task mode
   - bounded subagents
   - role-specific output contracts
   - summarized handoff to main session

3. **MCP Research Layer**
   - browser crawler
   - docs/context lookup
   - GitHub issue/PR context when needed
   - crawl budget and source attribution

4. **Plugin Control Layer**
   - token/output reducers
   - quota/status observability
   - file ignore and secret guards
   - orchestration plugins deferred until baseline is healthy

## Validation

- `opencode debug config` shows no unexpected direct provider routes
- `opencode stats` is captured before and after real use
- A small dry-run task completes without spawning background agents
- A large dry-run task delegates to bounded subagents and returns compact summaries
- Browser crawler dry-run cites sources and respects page/depth limits
- Plugin trial can be disabled by reverting one config change

## References

- OpenCode config documentation: <https://opencode.ai/docs/config/>
- OpenCode agents documentation: <https://opencode.ai/docs/agents/>
- OpenCode MCP servers documentation: <https://opencode.ai/docs/mcp-servers/>
- OpenCode plugins documentation: <https://opencode.ai/docs/plugins/>
- Awesome OpenCode plugin list: <https://github.com/awesome-opencode/awesome-opencode>
