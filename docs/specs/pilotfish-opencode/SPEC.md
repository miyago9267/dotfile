---
id: spec-pilotfish-opencode
title: Pilotfish OpenCode Role Routing
status: completed
created: 2026-09-16
updated: 2026-09-16
author: Miyago
approved_by: Miyago (2026-09-16)
tags:
  - opencode
  - pilotfish
  - routing
  - agents
  - providers
priority: high
---

<!-- markdownlint-disable MD025 -->

# Pilotfish OpenCode Role Routing

這份 spec 定義一個獨立的 `pilotfish-opencode` runtime project，沿用
Pilotfish 的 role 分工概念，並讓 OpenCode 擁有 provider、model、session、
permission 與 plugin 行為。

## Goal

建立一個可獨立發布的 OpenCode agent package，讓不同客戶可以使用完全
不同的 provider 與 model 組合，仍然能透過穩定的 role 分工使用相同的
工作流程。

## Scope

### In scope

- 建立 `pilotfish-opencode` sibling project，不改動 `pilotfish-codex`。
- 保留 role taxonomy、責任邊界、輸入／輸出契約與最小 role registry。
- 使用 OpenCode native agents、providers、permissions、sessions 與
  plugins。
- 支援客戶自訂 provider、model、variant、candidate order 與 fallback。
- 將 CLIProxyAPI 視為一個普通的 OpenCode-compatible provider。
- 建立 route resolution、capability validation、redacted receipt 與
  offline／live verification。

### Out of scope

- 將 Codex 的 role TOML、`MultiAgentV2` metadata、native hooks 或
  `routing_contract.py` 移植到 OpenCode。
- 固定 `Luna`、`Sol`、`Terra`、`Astra` 或任何預設 model catalog。
- 建立第二套 permission、sandbox、session 或 credential manager。
- 直接修改現有 dotfile OpenCode production config。
- 以中央 service 取代 OpenCode 的 provider runtime。
- 在第一版提供 routing GUI、billing optimizer 或跨 runtime orchestration。

### Stop condition

Implementation 必須在 `approved_by` 填入前停止。第一個 release slice
只有在以下條件全部成立後才算完成：

- role-only contract、OpenCode version boundary 與 customer config shape
  通過 review。
- 至少兩個不同 provider configuration 在沒有修改 package code 的情況下
  完成 role agent smoke。
- 缺少 provider、model、auth 或 capability 時會在 request 前 fail closed。
- route receipt 能區分 requested、resolved、fallback 與 unknown，且不含
  prompt、credential 或其他 secret。
- 可以停用 package 並回到原生 OpenCode 行為。

## Requirements

### R1. Role-only contract

Role 是唯一從 Pilotfish 概念保留的核心抽象。每個 role 至少定義：

- stable role ID
- responsibility
- scope 與 non-goals
- input contract
- output contract

Role contract 不得要求特定 provider、model、reasoning effort、endpoint、
permission syntax 或 session implementation。

初始 role examples 可以包含 `scout`、`executor`、`verifier`、
`security-reviewer` 與 `security-executor`。名稱是可配置 alias，不能把
Codex 版的 role 名稱當成 OpenCode runtime 的硬編碼清單。

### R2. OpenCode-native agent mapping

每個 role 映射到 OpenCode agent。agent 使用 OpenCode 的 Markdown
frontmatter 或 native configuration，並由 OpenCode 管理：

- `primary`、`subagent` 或 `all` mode
- model preference
- system prompt
- permission rules
- subagent allowlist
- step、context 與 session behavior

Package 的 role definition 不得複製 Codex developer instructions。Role
agent 可以不設定 model；此時必須把 parent model inheritance 視為明確的
OpenCode 行為並寫入 receipt。

### R3. Customer-owned provider catalog

客戶可以使用 OpenCode 內建 provider 或 custom provider。route resolver
只能引用客戶在 OpenCode resolved configuration 中實際宣告的 provider
與 model。

Provider 與 model 在 normalized route type 中必須是兩個欄位：

```yaml
provider: cliproxyapi
model: gpt-5.6-luna
variant: high
```

不使用單一字串承載 provider／model，也不在 role registry 中維護全域
model allowlist。

Credentials 必須留在 OpenCode auth、environment 或 file reference；
package、route config 與 receipt 不得保存 secret value。

### R4. Customer-owned routing

第一版優先使用 OpenCode native `agents` 與 `providers` 設定完成：

```text
role -> OpenCode agent -> provider/model/variant
```

只有 native configuration 無法表達 candidate order、availability 或
fallback 時，才新增獨立的 optional routing overlay。Overlay 必須是
customer-owned、versioned、可驗證的設定，不得把 routing instruction
塞進 system prompt。

### R5. Resolution and fail-closed behavior

Resolver 在建立新 session 或 subagent 前，必須驗證：

- role 與 agent 存在且 mode 可用
- provider 已宣告且 credential state 可用
- model 存在於 provider catalog
- variant 與 required capability 可用
- fallback policy 是合法且顯式的

任何未知或不一致的項目都必須停止該 route，回傳可操作的錯誤。不得
靜默改用 parent model、第一個可用 provider 或 package 內建 model。

### R6. Automatic routing boundary

MVP 先支援 explicit role／agent selection 與 native model mapping。

Task signal 到 role／agent 的 automatic routing 只有在 OpenCode 提供
可驗證的 pre-session 或 model-selection seam 後才實作。若 plugin 只能
觀察事件、不能可靠地改變即將使用的 model，必須退回 explicit command
或新 session flow，不使用 prompt-only routing。

### R7. Session semantics

Route resolution 的時點必須明確記錄為 session creation、subagent creation
或 explicit model switch。既有 session 不得因 agent alias 變更而靜默改用
另一個 provider/model。

每個 receipt 都要記錄 model source：`explicit`、`agent_config`、
`inherited` 或 `fallback`。

### R8. Permission ownership

Permission 完全由 OpenCode native permission system 管理。Pilotfish
OpenCode 不增加第二套 allow／ask／deny engine，也不因 route fallback
放寬 agent permission。

Role package 可以附 conservative example，但 customer config 仍是實際
permission source。Route resolver 只能檢查 permission compatibility，
不能授予額外的 shell、edit、external directory 或 subagent 權限。

### R9. Fallback policy

Fallback 必須是 customer 可見且可驗證的設定。至少支援：

- `none`
- `ordered_candidates`
- `same_capability`

Proxy 內部的 account rotation 或 upstream retry 不得被 receipt 宣稱成
Pilotfish route fallback。若 CLIProxyAPI 無法回報實際 upstream identity，
receipt 必須標記為 `proxy-resolved` 或 `unknown`。

### R10. CLIProxyAPI integration

CLIProxyAPI 以 OpenCode custom provider 接入，負責自己的 endpoint、
account selection、refresh、cooldown、retry 與 protocol translation。

Pilotfish OpenCode 不直接理解 CLIProxyAPI 的 upstream provider policy，
也不把 CLIProxyAPI 當成第二個 task router。它只接收 OpenCode 對應的
provider/model result，並在可觀測範圍內記錄 proxy boundary。

### R11. Capability truth

Capability 至少區分三種來源：

1. OpenCode/provider catalog 宣告
2. customer explicit override
3. live request observation

未知 capability 不得當成支援。需要 tools、vision、streaming、reasoning
variant 或長 context 的 role，若沒有足夠證據，必須停止或使用 customer
明確允許的 fallback。

### R12. Version compatibility

第一個 implementation target 是本機已安裝的 OpenCode `1.18.19`。SPEC
必須另列 V1 configuration shape 與新版 V2 `providers`、`permissions`
及 agent shape 的差異。

V1 與 V2 若需要不同 adapter，必須在 version boundary 分開驗證，不以
文件推測兩者行為相同。

### R13. Observability and receipt

每次 route 至少產生以下 redacted fields：

```json
{
  "role": "verifier",
  "agent": "verifier",
  "requested": {
    "provider": "openai",
    "model": "gpt-5.6-sol",
    "variant": "high"
  },
  "resolved": {
    "provider": "cliproxyapi",
    "model": "gpt-5.6-sol",
    "variant": "high",
    "source": "fallback"
  },
  "fallback": "ordered_candidates",
  "capability_status": "declared",
  "provider_identity": "proxy-resolved"
}
```

Receipt 不得保存 prompt、transcript、API key、credential path、完整
external URL 或未經 redaction 的 error body。

### R14. Installation boundary

Package 必須以 opt-in 方式載入。第一個 target 是明確啟用的
`opencode-harness`；daily `opencode` 的 slim behavior 不得因安裝
package 而增加固定 prompt、MCP、subagent 或 plugin 成本。

安裝與移除都必須有可重跑的 check、rollback 與 version pinning。

## Architecture / Plan

### Ownership

| Concern | Owner |
| --- | --- |
| Role taxonomy and responsibility | `pilotfish-opencode` |
| Agent mode, prompt, model field | OpenCode |
| Provider catalog and credentials | OpenCode/provider runtime |
| Permission and approval | OpenCode native permissions |
| Session and subagent lifecycle | OpenCode |
| Upstream account rotation and translation | Provider or CLIProxyAPI |
| Route validation and redacted receipt | `pilotfish-opencode` plugin |

### Runtime flow

```text
Customer OpenCode config
  -> provider/model catalog
  -> role agent selection
  -> optional Pilotfish resolver
  -> OpenCode session or subagent
  -> direct provider or CLIProxyAPI
  -> redacted route receipt
```

The resolver owns selection evidence. OpenCode owns actual execution semantics.
CLIProxyAPI owns what happens after its endpoint receives the request.

### Role package shape

The package should begin with a small role registry and OpenCode-native agent
files:

```text
pilotfish-opencode/
  roles/
    scout.md
    executor.md
    verifier.md
    security-reviewer.md
    security-executor.md
  src/plugin/
    pilotfish-opencode.ts
  tests/
    role-contract.test.ts
    route-resolution.test.ts
    receipt.test.ts
  docs/
    provider-compatibility.md
```

Role files describe responsibility and output shape. Customer model and
permission choices remain in OpenCode configuration or customer-owned agent
overrides.

### Configuration layering

The intended precedence is:

1. OpenCode mandatory permission and runtime constraints
2. explicit session or user model choice
3. customer agent/provider configuration
4. optional customer routing overlay
5. provider-native availability and fallback behavior

No layer may silently override an explicit user model choice or hide a
provider/model resolution failure.

### Proposed route configuration

The first version should keep provider and agent configuration in OpenCode
native files. An optional overlay can be added later with this conceptual
shape:

```yaml
version: 1
roles:
  verifier:
    agent: verifier
    candidates:
      - provider: openai
        model: gpt-5.6-sol
        variant: high
      - provider: cliproxyapi
        model: gpt-5.6-sol
        variant: high
    fallback: same_capability
```

This is a proposed normalized contract, not an OpenCode configuration key.
The adapter must compile it to the installed OpenCode version and reject
unsupported fields.

### Recommendations

- **Strong:** Keep `pilotfish-codex` and `pilotfish-opencode` as independent
  release lines.
  - This keeps Codex-native verification stable while OpenCode provider
    diversity evolves independently.
- **Strong:** Carry role semantics only; implement runtime behavior with
  OpenCode native mechanisms.
  - This prevents a second permission, session or provider abstraction.
- **Strong:** Start with explicit role／agent mapping before automatic routing.
  - The current OpenCode model/session semantics must be proven before a plugin
    is allowed to change selection.
- **Worth exploring:** Add a small routing overlay after native configuration
  cannot express candidate order or fallback.
  - This gives customers customization without prematurely inventing a full
    routing language.
- **Speculative:** Extract a shared code package for Codex and OpenCode now.
  - First establish two stable consumers; share contract semantics before
    sharing runtime implementation.

## Verification strategy

### Offline checks

- Role files contain no fixed provider, model, endpoint or credential value.
- Resolver accepts separate provider/model/variant fields.
- Missing provider, model, variant or capability fails closed.
- Explicit model choice wins over customer fallback rules.
- Inherited model is visible in the receipt.
- Receipt schema rejects prompts, transcripts, credentials and raw URLs.
- Package can be disabled without modifying unrelated OpenCode settings.

### Live checks

- One direct OpenCode provider completes a read-only `scout` role.
- One different provider completes the same role without package code changes.
- CLIProxyAPI completes a compatible role through its local endpoint.
- Streaming and tool calls are tested only for models that declare support.
- An unavailable provider does not silently become the parent model.
- A fresh session and an existing session preserve their documented model
  semantics.

### Verification verdicts

Every integration check reports one of:

- `CONFIRMED`: resolved route and runtime behavior match the contract.
- `REFUTED`: observed behavior violates the contract.
- `INCONCLUSIVE`: the provider or OpenCode surface does not expose enough
  evidence to prove the claim.

## Proposed decisions

- **Decision:** Create `pilotfish-opencode` as a sibling project with an
  independent release line.
  - **Reason:** OpenCode provider diversity and lifecycle differ materially from
    Codex native model routing.
  - **Review state:** Approved by Miyago (2026-09-16).
- **Decision:** Reuse only role taxonomy and responsibility semantics.
  - **Reason:** Codex model bindings, hooks and dispatch metadata have no stable
    OpenCode equivalent.
  - **Review state:** Approved by Miyago (2026-09-16).
- **Decision:** Let OpenCode own provider, model, permission and session
  behavior.
  - **Reason:** Native behavior is more observable and avoids duplicate policy
    engines.
  - **Review state:** Approved by Miyago (2026-09-16).
- **Decision:** Treat CLIProxyAPI as a normal custom provider.
  - **Reason:** It is a transport and upstream-account layer, not the task-level
    routing authority.
  - **Review state:** Approved by Miyago (2026-09-16).
- **Decision:** Use explicit routing first and defer automatic model selection
  until the plugin seam is proven.
  - **Reason:** OpenCode agent selection and session model selection have separate
    semantics.
  - **Review state:** Approved by Miyago (2026-09-16).
- **Decision:** Target `opencode-harness` before the daily `opencode` entry.
  - **Reason:** Preserve the existing slim daily runtime and its token boundary.
  - **Review state:** Approved by Miyago (2026-09-16).

## Tasks

- [x] P0: Review and approve this SPEC; confirm target OpenCode version,
  role aliases, fallback policy and package distribution boundary.
- [x] P1: Create the sibling `pilotfish-opencode` repository and minimal role
  agent pack without fixed provider/model bindings. Verified that OpenCode
  `1.18.19` loads all five role agents from an isolated target directory.
- [x] P2: Implement the offline role registry, provider/model resolver,
  capability validation and redacted receipt schema. The sibling's targeted
  tests, typecheck, and build all pass.
- [x] P3: Run an OpenCode plugin/command seam spike and decide whether automatic
  routing is supported. The isolated server exposed `pilotfish_route` through
  `/experimental/tool/ids`; current hooks do not prove pre-session model
  replacement, so the package keeps explicit routing.
- [x] P4: Add direct-provider and CLIProxyAPI integration tests, then package
  install, disable, rollback and fresh/existing-session verification. Direct
  OpenAI-compatible fixture, actual OpenCode `1.18.19` tool loop, model
  continuity, installer lifecycle, and authenticated CLIProxyAPI custom
  provider smoke are `CONFIRMED` without changing the current OpenCode config.

## Files

- `docs/specs/pilotfish-opencode/SPEC.md` - this completed spec in the dotfile
  planning repository.
- `/Users/miyago/Project/Active/Forks/Fork-Remaster-code/pilotfish-opencode/`
  - independent implementation repository on `feat/opencode-role-routing`.
- `pilotfish-codex/` - existing Codex project; must remain outside this change.
- OpenCode customer `opencode.json(c)` and `.opencode/agents/` - runtime-owned
  provider, model, permission and agent configuration.
- OpenCode customer auth storage - runtime-owned credentials; never committed.

## Open questions

- Should the first package support only OpenCode `1.18.19`, or also ship a V2
  configuration adapter in the first release?
- Which role aliases are user-facing, and which are only compatibility aliases?
- Should `same_capability` be available for security roles, or must those roles
  default to `none`?
- Can the installed OpenCode plugin API change model selection before session
  creation with enough evidence for `CONFIRMED` routing?
- Should the optional routing overlay be JSONC to match OpenCode config, or use
  a separate schema format with a compiler?
- What upstream license and attribution requirements apply before publishing the
  sibling fork for customer installation?

## Notes

- This SPEC does not authorize changes to the existing Codex project or current
  OpenCode configuration.
- Current local OpenCode configuration uses a V1-style `provider` section;
  version-specific adapters must be verified against the installed CLI rather
  than inferred from documentation alone.
- A provider being declared does not prove that it is authenticated, available,
  or capable of the requested tool and reasoning behavior.
