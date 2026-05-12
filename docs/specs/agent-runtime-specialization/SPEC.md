---
id: spec-agent-runtime-specialization
title: Runtime Specialization and Isolation for Codex, Claude, and Gemini
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [agents, codex, claude, gemini, skills, runtime]
priority: high
---

# Runtime Specialization and Isolation for Codex, Claude, and Gemini

## Background

目前三個 agent 已經有共享人格與硬規則層：

- `config/ai/AGENTS.md`

但 runtime adapter 與 skill 供給仍然高度混線：

1. `config/ai/codex/AGENTS.md` 仍是一份舊的整包 prompt，尚未 adapter 化
2. `config/ai/gemini/GEMINI.md` 仍大量沿用 Claude 專屬敘述，甚至保留 `Claude Max` 與 Claude 工作流語境
3. `script/common/setup_codex.sh` 與 `script/common/setup_gemini.sh` 目前都會把 `config/ai/claude/skills/` 整包 symlink 到各自 runtime
4. `Gemini` 已開始有原生 `skills/` 與 `policies/`，但仍與大量 Claude 共用 skill 混在一起
5. `Claude` 已有較明確的 runtime-specific 區塊，例如 hooks、memory sources、Scripts CLI

這導致三個問題：

1. agent 的角色不夠鮮明，容易互相模仿彼此
2. runtime 入口與可用功能沒有隔離，Claude 專屬 skill 可能滲進 Codex / Gemini
3. 共用規則與 runtime 專屬能力的邊界沒有落到實體結構

使用者現在要的目標是明確分工：

- `Codex`：軟體工程、實作、寫 code、修 code
- `Claude`：策劃、規格、文件、小改動、流程編排
- `Gemini`：提問導向、研究導向、Google 生態 / 自家服務導向

而且三個 runtime 應盡可能使用各自原生能力，不互相串用不必要的功能。

## Requirements (EARS)

- **R1**: When runtime roles are defined, the system shall keep shared identity and hard rules in `config/ai/AGENTS.md` and move role specialization into runtime adapters
- **R2**: When `Codex` is configured, the adapter shall bias toward software implementation, code changes, local verification, and engineering execution
- **R3**: When `Claude` is configured, the adapter shall bias toward planning, specification work, orchestration, documentation, and small targeted edits
- **R4**: When `Gemini` is configured, the adapter shall bias toward clarifying questions, research assistance, and Google ecosystem workflows
- **R5**: When runtime-specific features exist, the system shall prefer each runtime's native mechanism instead of routing everything through Claude-derived skills
- **R6**: When skills are shared across runtimes, the system shall separate truly shared core skills from runtime-native skills
- **R7**: When a skill or workflow is Claude-specific, the system shall not automatically expose it to Codex or Gemini unless a compatible native adapter exists
- **R8**: When `setup_codex.sh` and `setup_gemini.sh` provision skills, they shall install only approved shared-core skills plus each runtime's native skills
- **R9**: When a runtime adapter references product-specific quotas, hooks, scripts, memory loading, or UX, those details shall stay local to that runtime and not leak into the others
- **R10**: When runtime specialization is implemented, the resulting structure shall make it obvious which files are shared, which are Claude-only, which are Codex-only, and which are Gemini-only
- **R11**: When `Gemini` is specialized for Google workflows, the configuration shall reserve room for Google service skills or policies without assuming Claude-style hooks or Codex-style coding workflows
- **R12**: When `Codex` is specialized for software execution, the configuration shall avoid planner-heavy or reminder-heavy baggage that belongs in Claude
- **R13**: When `Claude` is specialized for planning and small changes, the configuration shall avoid positioning it as the primary heavy implementation runtime
- **R14**: When roles are specialized, the system shall treat role bias as a default preference rather than deleting overlapping capabilities outright
- **R15**: When runtime capabilities overlap, the system shall allow cross-use through approved shared-core skills while preserving each runtime's own hooks, policies, MCPs, and native tools

## Non-goals

- 不在本 spec 階段重寫全部 20+ skills
- 不在本 spec 階段設計完整的 Google Cloud 專屬 Gemini skill 套件
- 不在本 spec 階段移除 shared `AGENTS.md`
- 不在本 spec 階段處理每一個 plugin skill 的重新命名

## Alternatives Considered

### 方案 A：維持現在的共享方式，只改文字描述

最省事，但 `setup_codex.sh` / `setup_gemini.sh` 仍會把 Claude skills 全灌過去，實際上沒有隔離。

### 方案 B：三邊完全分家，不留共享層

隔離最強，但會回到規則重複維護與漂移問題，違反前面剛建立的 shared contract。

### 方案 C：共享硬規則 + runtime adapter + 分層 skill 供給

保留共享人格與硬規則，同時把角色、工具鏈、skill 供給分 runtime 收斂。這最符合目前需求。

## Rabbit Holes

1. 不要把「角色 specialization」做成只改 prompt 文案，卻不改 skill/link 結構
2. 不要把所有共用 skill 全數保留，然後只靠 agent 自己「盡量別用」
3. 不要在 `Gemini` 裡保留 Claude hooks、Claude Max 額度、Claude CLI workflow 這種 runtime leakage
4. 不要把 `Codex` 的角色定成「什麼都會做」，這會讓分工再次失焦

## Architecture

### 1. 四層結構

#### Shared Base

- `config/ai/AGENTS.md`
- 只放人格、Truthfulness、Search Before Ask、SDD、TDD、Safety、Communication

#### Runtime Adapter

- `config/ai/codex/AGENTS.md`
- `config/ai/claude/CLAUDE.md`
- `config/ai/gemini/GEMINI.md`

每個 adapter 只做：

- role bias
- runtime-native tool / workflow / memory / policy
- 明確列出「這個 runtime 不主打什麼」

#### Shared Core Skills

僅保留真正跨 runtime 的小型 guardrails，例如：

- `ask-discipline`
- `safe-ops`
- `path-aware`
- `git-workflow`
- `search-discipline` 的 runtime-adapted 版本

這層需要和 Claude-native skills 在概念上分開，避免 `setup_*` 直接吃整包 Claude skills。
在過渡期可由 setup script 用 allowlist 從既有 skill 來源挑選 shared-core。

#### Runtime-Native Skills

- `config/ai/codex/skills/`
- `config/ai/claude/skills/`
- `config/ai/gemini/skills/`

只放該 runtime 的 native workflows。

### 2. 目標分工

#### Codex

- 主職：coding、refactor、debug、tests、local verification、codebase surgery
- 次職：技術判斷
- 不主打：長篇策劃、heavy process narration、過多提醒

#### Claude

- 主職：spec、planning、workflow orchestration、docs、review framing、小改動
- 次職：thin implementation
- 不主打：大規模 coding 主戰場

#### Gemini

- 主職：clarification、question decomposition、research、Google / GCP / Workspace / Gemini-native workflows
- 次職：light drafting
- 不主打：Claude-style hook workflow、Codex-style heavy code execution

### 3. 技能供給原則

#### Codex 安裝集合

- `shared-core-skills`
- `codex-native-skills`
- 保留 Codex 自己的 tools / plugins / MCP 能力
- 不直接整包 symlink `config/ai/claude/skills/`

#### Gemini 安裝集合

- `shared-core-skills`
- `gemini-native-skills`
- 保留 `policies/`
- 保留 Gemini 自己的 tools / MCP / Google-first 流程能力
- 不直接整包 symlink `config/ai/claude/skills/`

#### Claude 安裝集合

- `shared-core-skills`
- `claude-native-skills`
- hooks / commands / memories

## ADR

### ADR-1: 共享規則與共享 skill 要分開

- 決策：`AGENTS.md` 繼續共享，但 skill 供給不再等於「整包 Claude skills」
- 原因：共享人格與硬規則合理，整包共享 runtime skill 會導致功能污染

### ADR-2: Claude 不再作為其他 runtime 的預設 skill source of truth

- 決策：Claude 仍可作為部分共用規則來源，但 shared-core skills 必須有獨立概念或獨立目錄
- 原因：目前 `setup_codex.sh` / `setup_gemini.sh` 直接吃 Claude 目錄，導致角色混線

### ADR-3: specialization 必須同時落在 adapter 與 setup 層

- 決策：角色分工不是只改 prompt，還要改 skill 連結和 runtime 安裝集合
- 原因：若只改 prompt，不會真正改變 agent 能力面

## Phase 計畫

### Phase 1: 定義 specialization contract

- 建立 spec
- 明確列出三個 runtime 的主職 / 非主職
- 定義 shared-core vs runtime-native 的邊界

### Phase 2: Runtime adapter 收斂

- 瘦身 `config/ai/codex/AGENTS.md`
- 瘦身 `config/ai/gemini/GEMINI.md`
- 強化三邊 adapter 的角色偏向

### Phase 3: Skill 供給結構收斂

- 建立 shared-core skill 結構
- 調整 `setup_codex.sh`
- 調整 `setup_gemini.sh`
- 必要時補 `config/ai/codex/skills/` 與 Gemini native skills

### Phase 4: 清理 runtime leakage

- 移除 Gemini 中不該出現的 Claude-specific 敘述
- 移除 Codex 中不該保留的 planner / Claude quota / skill baggage

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| shared-core 切太薄，三邊開始重複維護 | medium | 只把 truly universal guardrails 留在 shared-core |
| shared-core 切太厚，仍然混入 Claude-specific 能力 | high | 以「Codex/Gemini 是否能原生理解並需要」作為收錄門檻 |
| 調整 setup 後某些既有 skill 消失造成退化 | medium | 先建立 inventory 與 mapping，再逐步切換 |
| Gemini 特化目標太抽象，落不到實體 skill | medium | 先把 leakage 清掉，再補少數高價值 Gemini-native skills |
