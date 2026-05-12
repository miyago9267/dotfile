---
id: spec-shared-agent-contract
title: Shared AGENTS.md for Multi-Agent AI Configs
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [agents, ai-config, docs, codex, claude, gemini]
priority: medium
---

# Shared AGENTS.md for Multi-Agent AI Configs

## Background

目前 `config/ai/` 內的 agent 規則分散在多個入口檔：

- `config/ai/claude/CLAUDE.md`：混合了共用工程規則、Monika 人格、Claude 專屬 bootstrap/script workflow
- `config/ai/codex/AGENTS.md`：幾乎完整複製一份人格與規則
- `config/ai/gemini/GEMINI.md`：明確標示同步自 Claude 規則

這種結構有三個問題：

1. 共用規則重複維護，容易漂移
2. Claude 專屬流程和跨 agent 通用規則混在一起，不利於其他 agent 重用
3. `config/ai/claude/CLAUDE.md` 目前已有未提交修改，直接在該檔上重構風險較高

依據目前檔案與腳本：

- `commands/init-ai-dir.md` 已定義「把 Claude 規則轉成 LLM-agnostic 格式」的方向
- `setup_codex.sh` 目前只會 link `config/ai/codex/AGENTS.md`
- `setup_gemini.sh` 目前只會 link `config/ai/gemini/GEMINI.md`

因此本次工作先建立一份共享的 `AGENTS.md` 作為跨 agent 的共用契約，再逐步讓各 agent 入口檔引用或對齊。

## Requirements (EARS)

### 核心需求

- **R1**: When a shared agent contract is introduced, the system shall store it at `config/ai/AGENTS.md` so multiple agent configs can reference the same source
- **R2**: When `config/ai/AGENTS.md` is written, the document shall contain only cross-agent rules extracted from existing `CLAUDE.md`, `config/ai/codex/AGENTS.md`, and `config/ai/gemini/GEMINI.md`
- **R3**: While defining the shared contract, the document shall exclude agent-specific bootstrap commands, tool names, and vendor-specific adapter syntax unless clearly marked as agent-specific extension points
- **R4**: When shared rules are extracted, the document shall preserve the currently enforced constraints:
  - 繁體中文（台灣）回應、編輯與註解
  - 文件與註解預設不使用表情符號
  - 回應開頭先交代結果或當前進度
  - 回應結尾附簡短 recap
  - 回答前進行 fact-check thinking
  - 資訊不足時不得臆測或補完
  - Search Before Ask
  - 非 trivial 任務先建 spec，中大型實作前等確認
  - TDD 優先與回報測試狀態
  - AI 不做 sudo/root 操作
  - CI/CD 管理的 container 不用 `docker run`
  - CLI 前先 `source ~/.zshrc 2>/dev/null`
- **R5**: When the shared contract is written, the document shall exclude runtime-specific workflow rules such as context compaction, bootstrap/handoff/snapshot flow, and vendor-specific memory loading
- **R6**: When agent-specific entry files remain in use, the shared contract shall state that local `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` files may extend or override the shared rules for their own runtime needs
- **R7**: While implementing the shared contract, the change shall avoid editing files that already contain unrelated user changes unless the edit is necessary and can be merged safely
- **R8**: When shared rules are refined, the document shall explicitly require assumptions to be surfaced, not silently chosen
- **R9**: When a task has multiple plausible interpretations, the system shall require those interpretations to be named before implementation proceeds
- **R10**: When editing existing code, the system shall require surgical changes: only task-related lines, matching local style, and only removing orphans created by the current change
- **R11**: When executing multi-step work, the system shall require brief success criteria and `step -> verify` style plans
- **R12**: When producing user-facing responses, the shared contract shall optimize for brevity and information density rather than filler or ceremonial phrasing
- **R13**: When adapting Claude-specific behavior, the local adapter shall explicitly counter Claude verbosity without adopting meme speech patterns

## Non-goals

- 不在本階段調整 `setup_codex.sh` / `setup_gemini.sh`
- 不在本階段重新設計 Monika persona，只抽出跨 agent 共通部分
- 不在本階段建立自動同步 script

## Alternatives Considered

### 1. 繼續讓每個 agent 維護自己的入口檔

最省事，但規則會持續漂移，且已經存在 Claude/Codex/Gemini 三份近似內容。

### 2. 把共用 `AGENTS.md` 放在 `config/ai/claude/`

可以直接參考 `CLAUDE.md`，但語意上仍偏 Claude 私有空間，不適合作為跨 agent source of truth。

### 3. 直接重構 `CLAUDE.md` 成唯一真相來源

會把 Claude 專屬 bootstrap、script workflow、記憶掛載機制一起帶進共用規則，而且該檔目前是 dirty state，風險高。

## Proposed Design

### 檔案位置

新增：

- `config/ai/AGENTS.md`：跨 agent 共用規則

第二階段：

- `config/ai/claude/CLAUDE.md`：改為 shared base + Claude extension

暫不修改：

- `config/ai/codex/AGENTS.md`
- `config/ai/gemini/GEMINI.md`

### 內容分層

`config/ai/AGENTS.md` 只保留：

1. 共用身份與語氣原則
2. 共用真實性/事實查核規則
3. 共用 SDD/TDD 原則
4. 共用安全與工具使用規則
5. 共用環境、技術棧與偏好摘要
6. 專案級 `AGENTS.md` 優先規則

不保留：

1. `bash ~/.claude/scripts/bootstrap.sh --compact`
2. Claude 專屬 Scripts CLI 表格
3. Claude 專屬記憶檔案引用（如 `@memories/...`）
4. 任何特定 vendor 的工具名或 hook 機制
5. context 壓縮、bootstrap、handoff、snapshot 等 runtime-specific 工作流

## Decisions

### D1: shared contract 只保留人格與共用規則

shared `AGENTS.md` 只承載跨 agent 都適用的人格、真實性、SDD/TDD 與安全規則，不直接承載任何特定 runtime workflow。

### D2: context 壓縮與 session workflow 不進 shared contract

context 壓縮策略、bootstrap、handoff、snapshot、記憶掛載方式都與特定 agent runtime 強相關，應保留在各自入口檔或本地設定。

### D3: Claude 採用 shared base + local extension

`config/ai/claude/CLAUDE.md` 在開頭引用 `config/ai/AGENTS.md`，並只保留 Claude 專屬 workflow、script、文件結構與記憶來源。

### D4: 補強 shared contract 採用 Karpathy-style guardrails

在不引入 vendor-specific workflow 的前提下，補入四種缺失較明顯的 guardrails：顯式 assumptions、避免靜默選解、surgical changes、goal-driven verification。

### D5: 反廢話的目標是高資訊密度，不是 caveman 風格

shared 規則要明確要求簡短、直接、少重複，但不應把輸出壓成 meme 口吻。Claude 本地 adapter 另外補一層反 verbosity 提醒即可。

## Files

- Create: `config/ai/AGENTS.md`
- Update: `config/ai/claude/CLAUDE.md`
- Update: `config/ai/claude/skills/ask-discipline/SKILL.md`
- Create: `docs/specs/shared-agent-contract/SPEC.md`
- Create: `docs/specs/shared-agent-contract/TASKS.md`
- Create: `docs/specs/shared-agent-contract/TESTS.md`
- Create: `docs/specs/shared-agent-contract/PROGRESS.md`

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| 共用檔抽得太薄，失去實際約束力 | medium | 明確保留硬規則與操作禁令，只移除 vendor-specific 部分 |
| 共用檔抽得太厚，混入 Claude 專屬流程 | medium | 以「其他 agent 是否可直接遵守」作為收錄門檻 |
| 觸碰 dirty 的 `CLAUDE.md` 造成衝突 | high | 只做 adapter 化，保留 Claude 專屬段落，不硬改 runtime 內容 |

## Open Questions

1. 第二階段是否要把 `config/ai/codex/AGENTS.md` 與 `config/ai/gemini/GEMINI.md` 改成引用 shared contract 的 adapter
