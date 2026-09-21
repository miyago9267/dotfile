---
id: spec-pilotfish-opencode-local-routing
title: Pilotfish OpenCode Local Harness Installation and Initial Routing
status: completed
created: 2026-09-16
updated: 2026-09-16
author: Miyago
tags:
  - opencode
  - pilotfish
  - local-install
  - routing
priority: high
---

<!-- markdownlint-disable MD013 MD025 -->

# Pilotfish OpenCode Local Harness Installation and Initial Routing

## Goal

把已驗證的 pilotfish-opencode sibling package 接到本機
opencode-harness，並依 provider／model 的可用能力建立第一版 customer-owned
role routing。

## Scope

### In scope

- 在 config/opencode-harness 載入本機 pilotfish-opencode plugin。
- 保留現有 OpenCode agent prompt、permission 與 harness entrypoint。
- 將 discovery、implementation、review、security 與 verification 分到
  cheap labor、senior labor、high-level reasoning 三層。
- 在目前 dotfile project 提供 .opencode/pilotfish/catalog.json 與
  .opencode/pilotfish/routing.json 範例。
- 不在 routing files 保存 credential、API key、prompt 或 transcript。

### Out of scope

- 修改 daily config/opencode 的 slim runtime。
- 修改既有 pilotfish-codex。
- 讓 plugin 自動改寫既有 session 的 model。
- 把尚未在本機宣告的 fable、opus5 或 gpt 6 astra 假設成可用。
- live 驗證每個 provider 的付費 request。

## Decisions

- local installation target 是 opencode-harness；daily runtime 保持原樣。
- read-only discovery 優先使用 DeepSeek／Gemini。
- implementation 使用 openai/gpt-5.6-luna；independent diff review 使用
  xai/grok-4.6。
- plan、security、verification 與主 session 暫用
  openai/gpt-5.6-sol，直到 customer provider 宣告 Fable、Opus 5 或 GPT 6
  Astra。
- security routes 使用 fallback: none；一般 discovery、implementation
  與 verification 才使用明確 fallback policy。
- model assignment 由 OpenCode native agent frontmatter 生效；Pilotfish
  plugin 只驗證 customer-owned route 並產生 redacted receipt。

## Post-acceptance adjustment

- daily 與 harness 的 default primary model 統一為
  `openai/gpt-5.6-luna`，primary agent 使用 `reasoningEffort: max`，對齊
  Pilotfish Codex 的本機預設。
- `small_model` 維持 `openai/gpt-5.5`，保留低成本的內部摘要／標題路徑。
- plan、security、verification 等 named high-level roles 仍維持
  `openai/gpt-5.6-sol`；這次只調整 default primary，不改 role routing。

## Evidence boundary

| Model or class | Local evidence | Route state |
| --- | --- | --- |
| DeepSeek V4 Flash | OpenCode catalog and auth entry observed | active cheap tier |
| Gemini 2.5 Flash | OpenCode catalog and GEMINI_API_KEY presence observed | active cheap tier, live request unverified |
| GPT-5.6 Luna／Sol | OpenCode effective config and auth entry observed | active |
| Grok 4.6 | xAI model catalog and auth entry observed | active config candidate, live request unverified |
| Fable／Opus 5／GPT 6 Astra | No local provider/model identity observed | pending, not active |

## Acceptance

- harness effective config contains the local Pilotfish plugin path.
- harness agent listing reflects the initial role assignments.
- local catalog and routing files pass the package resolver tests.
- one local route receipt is generated without exposing credential values.
- daily OpenCode config and pilotfish-codex remain unchanged.
- generated plugin artifact is local-only and excluded from the dotfile diff.

## Tasks

- [x] Define local target, tiers, evidence boundary, and rollback boundary.
- [x] Build and install the local harness plugin artifact.
- [x] Apply the initial agent model assignments.
- [x] Validate harness config, agent assignments, catalog, routing, and package
  regression tests.
- [x] Record final verification and remaining live-provider uncertainty.

## Verification record

- opencode debug config loaded the local Pilotfish plugin path and showed the
  expected harness role model assignments.
- The local installer rebuilds the sibling package and installs only the
  ignored harness plugin artifact.
- The local route tool read .opencode/pilotfish/ and generated a redacted
  scout receipt with declared capability status.
- All five local Pilotfish routes resolved through the customer catalog;
  security routes kept fallback: none.
- Sibling package tests passed: 15 pass, 2 intentionally skipped live tests;
  typecheck and build passed.
- Markdown lint, JSON parsing, and git diff --check passed.
- The generated plugin has the same SHA-256 as the sibling build and is ignored
  by the dotfile diff.
- No daily config/opencode file or pilotfish-codex file changed.
- Gemini and Grok 4.6 live requests remain unverified in this slice. Fable,
  Opus 5, and GPT 6 Astra remain pending until a local customer provider
  declares their identities.

## Rollback

- Remove the local Pilotfish plugin entry from
  config/opencode-harness/opencode.json.
- Restore only the changed harness agent model fields to their previous values.
- Remove the generated ignored plugin artifact.
- Leave daily OpenCode, auth storage, and pilotfish-codex untouched.
