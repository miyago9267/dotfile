---
id: spec-astra-agent-identity
title: Astra 單一 Agent 身份與舊 runtime 相容
status: implemented
created: 2026-09-15
updated: 2026-09-15
author: Miyago
tags: [astra, identity, compatibility, skills, runtime]
priority: high
---

<!-- markdownlint-disable-next-line MD025 -->
# Astra 單一 Agent 身份與舊 runtime 相容

## Background

目前 shared contract、runtime adapters、OpenCode agents 與 plugins 使用不同的
persona 名稱，且高頻 Skills 會在不相關的任務中常駐。這會造成身份漂移、重複檢查、
無關文件讀取與不必要的確認。

本 spec 將 Astra 定為唯一 canonical identity，保留既有檔名、plugin 名稱與 runtime
agent ID 作為 compatibility aliases，並把 optional Astra profile 限制在明確啟用的
main session。

## Requirements (EARS)

- **R1**: When any shared runtime loads the canonical contract, the speaking identity
  shall be Astra.
- **R2**: When a legacy name such as `Monika`, `monika`, `monika-large`, or
  `studio-monika` appears in a runtime binding, the system shall treat it as a
  compatibility alias and shall not create a second persona.
- **R3**: When a self-contained local task does not mention a capability, the runtime
  shall not load unrelated session notes, vault nodes, or optional Skills solely
  because the files exist.
- **R4**: When a routine Skill is not handling its named event, the runtime shall
  not keep it `alwaysApply`; each canonical provider tree and the explicit Astra
  profile shall keep only its compact `safe-ops` safety floor always-on.
- **R5**: When Astra is explicitly selected for the main session, the runtime shall
  use the Astra adapter and compact allowlist without automatically switching
  normal Luna/Sol roles or creating an Astra child.
- **R6**: When generated entries or compatibility artifacts are rebuilt, they shall
  preserve the existing runtime/plugin/OpenCode IDs while carrying the Astra identity.
- **R7**: When the requested scope has remaining implementation, integration, or
  acceptance work, the agent shall report progress or blockage instead of completion.

## Non-goals

- 不移除既有 `monika-*` plugin、OpenCode agent 檔名或 runtime binding ID
- 不自動切換 model、permission mode、worktree、remote session 或 production route
- 不移除外部 Claude plugin，也不把其文件讀入 Astra profile
- 不把所有 Claude、Codex、Gemini 的 runtime-specific workflow 合併成一份格式
- 不因這次整理改寫歷史 spec 的事件敘述

## Alternatives Considered

### 保留 Monika 作為 canonical identity

不採用。舊名稱需要長期相容，但多個 persona 名稱會繼續讓 runtime 產生身份分叉。

### 直接重命名所有檔案與 plugin

不採用。會破壞既有安裝路徑、plugin discovery 與 OpenCode invocation；alias 層能
保留相容性，且 blast radius 較小。

### 把所有 Skills 設成常駐

不採用。高頻 routine check 應由 event trigger 啟動；全域只保留 safety gate。

## Architecture

```text
config/ai/AGENT-ENTRY.md
  canonical boundary + Astra identity metadata
        |
config/ai/AGENTS.md
  shared identity, communication, safety, autonomy, completion contract
        |
config/ai/<runtime>/AGENTS.md
  native runtime adapter; legacy IDs remain bindings
        |
config/ai/astra/
  explicit main-session adapter + compact allowlist
        |
config/ai/generated/<runtime>/AGENTS.md
  generated runtime entry, never an independent source
```

Skill loading uses the following order:

1. Shared contract and runtime adapter
2. `safe-ops` as the compact safety floor
3. At most one explicitly triggered task Skill in the Astra profile
4. Domain, vault, Office, design, reverse-engineering, and session Skills only when
   the request matches their boundary

## ADR

### ADR-1: Astra is canonical; legacy names are aliases

- 決策：shared contract 只使用 Astra；`Monika` 與既有 ID 保留為相容名稱。
- 原因：統一對外身份，同時避免破壞現有 runtime、plugin 與 OpenCode consumers。

### ADR-2: Astra is an explicit profile, not an automatic fallback

- 決策：Astra 只在 main session 明確選擇時啟用；普通 session 維持既有 Luna/Sol
  路由。
- 原因：model 與 permission 是 user-controlled state，不能因任務變難而靜默切換。

### ADR-3: One safety floor, event-driven optional Skills

- 決策：canonical Claude/Gemini trees 與 Astra profile 只保留 compact `safe-ops` 的
  `alwaysApply: true`；其他高頻 Skills 改為明確事件觸發。
- 原因：保留安全邊界，同時移除重複 pre-ask、session、search、lint 與 efficiency
  檢查。

## Phase 計畫

### Phase 1: Canonical identity

- 更新 shared entry、runtime bindings、OpenCode labels 與相關 compatibility docs。

### Phase 2: Skill routing

- 收斂高頻 Skills metadata、domain trigger、Zed entrypoint 與 duplicate rules。

### Phase 3: Astra profile

- 建立 explicit adapter、allowlist、isolated setup script 與 generated entry。

### Phase 4: Verification

- 重新生成 runtime outputs，執行 sync、syntax、metadata、YAML、Markdown 與 diff checks。

## Risks

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| 舊 consumer 依賴 Monika ID | runtime 啟動失敗 | 保留檔名、plugin 名稱與 binding aliases |
| 常駐 Skill 被誤改成不觸發 | 安全或互動流程缺失 | `safe-ops` 保持 always-on，執行 sync checks |
| generated output 過期 | 實際 runtime 與 source 不一致 | 執行 setup scripts 並檢查 generated prefix |
| Astra 被錯誤自動啟用 | model、權限或成本改變 | explicit-only activation 與 target root guard |
