---
id: spec-hook-automation-rationalization
title: Claude Hook Automation Rationalization
status: draft
created: 2026-05-12
updated: 2026-05-12
author: Codex
tags: [claude, hooks, skills, automation]
priority: medium
---

# Claude Hook Automation Rationalization

## Background

目前 `config/ai/claude/` 內同時存在 `skills/`、`commands/`、`hooks/` 三種能力入口，但哪些功能應自動觸發、哪些應保留給 agent 推理，邊界還不夠清楚。

現況有兩個問題：

1. 有些功能已明顯適合 hook，但還停留在 skill 描述，例如 `strategic-compact`
2. 有些規則需要 agent 反覆記得，實際上可以用很小的 hook 先做第一層攔截，例如 `git add .` 與 AI attribution commit message

這次工作要把功能整理成兩條線：

- `hook 線`：事件明確、邏輯短、低副作用、可快速驗證的自動化
- `skill / command 線`：需要上下文理解、分流、推理或副作用控制的工作

第一批只做高確定、低風險的 hook 接線，不把重邏輯硬塞進 hook。

## Requirements (EARS)

- **R1**: When a Claude behavior can be triggered by a clear runtime event and decided with short deterministic logic, the system shall classify it into the hook line
- **R2**: When a Claude behavior requires task understanding, multi-step reasoning, or user-facing branching, the system shall keep it in the skill or command line
- **R3**: When hook automation is introduced, the implementation shall keep the hook logic small, explicit, and side-effect-light
- **R4**: When the first batch is implemented, the system shall wire `strategic-compact` into Claude `PreToolUse` for `Edit|Write`
- **R5**: When the first batch is implemented, the system shall deny `git add .` and `git add -A` style staging via a `PreToolUse/Bash` hook and tell the agent to stage explicit paths
- **R6**: When the first batch is implemented, the system shall deny obvious AI attribution commit message patterns via a `PreToolUse/Bash` hook
- **R7**: While hook logic remains intentionally narrow, the system shall keep `repo-status` and `project-map` on the conservative line instead of auto-running them as hooks in this batch
- **R8**: When the classification is documented, the spec shall record both lines so future changes do not drift back into ad-hoc decisions

## Non-goals

- 不在這一批把 `repo-status` 改成 session hook
- 不在這一批把 `project-map` 改成 session hook
- 不在這一批把需要推理的 skill 改寫成 hook
- 不在這一批重構整個 Claude hook framework

## Alternatives Considered

### 方案 A：全部保留 skill，由 agent 自己記得

最少改動，但會持續浪費提醒成本與 token，且已知有些規則很適合機械化攔截。

### 方案 B：大量把規則搬進 hook

自動化最多，但很容易把上下文判斷、網路存取、重邏輯塞進 shell script，增加脆弱度與除錯成本。

### 方案 C：雙軌制

把嚴格、短小、事件明確的部分放 hook；保留需要理解任務的部分在 skill / command。這最符合目前需求。

## Rabbit Holes

1. 不要把 `repo-status`、`project-map`、`auto-spec` 這類需要上下文或外部狀態的流程硬改成 always-on hook
2. 不要為了「完整攔截」把 commit message parser 做成一個複雜 mini linter；第一批只抓明顯違規字樣
3. 不要在 hook 裡加入裝飾性輸出或大量診斷文字

## Architecture

### 分類原則

#### Hook 線

符合以下條件才放 hook：

- 有明確事件點，例如 `PreToolUse`、`PostToolUse`、`SessionStart`
- 規則可以只靠當前事件資料決定
- 腳本應在數秒內完成
- 失敗時可安全略過，不會中斷整體工作流

#### Skill / Command 線

符合以下任一條件就保留：

- 需要理解使用者意圖或 repo context
- 需要多步規劃、分流、驗證
- 需要外部認證、網路查詢或重狀態判斷
- 有明顯副作用或需要使用者明確觸發

### 初版分類

#### Hook 線

- `strategic-compact`
- `git-workflow` 的 `git add` 明確路徑規則
- `no-ai-attribution` 的明顯 commit message 違規攔截

#### 保守線

- `repo-status`
- `project-map`
- `ask-discipline`
- `auto-spec`
- `health-check`
- `code-review`

## ADR

### ADR-1: 先做窄 hook，不做胖 hook

- 決策：第一批只落地三個 hook 能力，且每支 hook 只做單一檢查
- 原因：降低誤觸發與維護成本，讓自動化邊界穩定

### ADR-2: repo-status 與 project-map 先保留在保守線

- 決策：本批不把它們改成 `SessionStart` hook
- 原因：兩者都會增加 context 或外部狀態依賴，值得保留第二條線慢慢驗證

## Phase 計畫

### Phase 1: 分類與最小 hook 接線

- 建立雙軌分類 spec
- 接上 `strategic-compact`
- 新增 `git add` guard hook
- 新增 commit attribution guard hook

### Phase 2: 保守線評估

- 重新評估 `repo-status` 是否能縮成非阻塞單行摘要
- 重新評估 `project-map` 是否能縮成超小型 session injector

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| hook 誤判造成不必要攔截 | medium | 第一批只抓明顯 pattern，訊息明確可修正 |
| `strategic-compact` 太常提醒 | low | 沿用既有 threshold 與 interval，不新增更激進提醒 |
| commit message 攔截不完整 | low | 明確承認第一批只抓 obvious patterns，保留 skill 規則作第二層 |
