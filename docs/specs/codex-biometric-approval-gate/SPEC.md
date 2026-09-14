---
id: spec-codex-biometric-approval-gate
title: Codex 生物驗證 Approval Gate
status: in-progress
created: 2026-09-09
updated: 2026-09-09
author: Miyago
approved_by:
tags: [codex, approval, security, macos, touch-id, passkey]
priority: high
---

# Codex 生物驗證 Approval Gate

## Background

Codex 在需要使用者核准時，目前依賴 CLI／TUI 的人工輸入。Miyago 希望
使用 macOS Touch ID 或 Passkey 完成核准，減少重複輸入密碼，同時保留
每次 command 的安全邊界。

這是一個獨立的 local approval bridge，與 Codex 的 routing、skill、hook、
MCP 層分開。第一版只服務本機 Codex，放在 dotfile 管理；通用化後再考慮
拆成獨立 repository。

## Goals

- 讓 Codex 的 approval request 可以由 Touch ID 完成核准。
- 保留 host 端對 command、workspace、session 和風險類型的最終控制。
- 每次 biometric 核准只對應一筆、可驗證且短效的 approval request。
- 驗證失敗、逾時、protocol 不明或內容變更時預設拒絕。
- 可測試、可記錄、可移除，且不把 biometric secret 暴露給 agent。

## Non-goals

- 不修改 Codex model、routing、skill、hook 或 MCP 的優先級。
- 不把 Touch ID 變成任意 shell command 的通用授權。
- 不讓 agent 自己呼叫 biometric helper 後宣稱已取得核准。
- 不自動核准 credential、production、破壞性或不可逆操作。
- 不保存指紋、Passkey private key 或其他 biometric secret。
- 第一版不處理跨機器、雲端或多人共用。

## Requirements

- **R1**: When Codex emits an approval request, the gate shall display the
  command、working directory、session identifier、sandbox mode (when supplied
  by the protocol) and risk class before asking for biometric verification;
  unavailable protocol fields shall be shown as unavailable.
- **R2**: When biometric verification succeeds, the gate shall return approval
  only for the exact request whose request identifier and command hash were
  verified.
- **R3**: When verification fails, expires, is cancelled, or cannot be matched
  to the active request, the gate shall return deny and never fall back to
  automatic approval.
- **R4**: The gate shall use a single-use approval token with a short expiry,
  bound to session, request identifier, command hash, working directory and
  runtime.
- **R5**: The gate shall keep an audit record containing decision, timestamp,
  risk class, request hash and reason, while excluding command secrets and
  biometric material.
- **R6**: The host wrapper shall own the bridge connection and biometric call;
  skills, hooks and model-generated commands shall not be trusted as the
  approval authority.
- **R7**: The gate shall expose an explicit deny and cancel path and shall
  preserve Codex's manual approval fallback during rollout.
- **R8**: The implementation shall bind only to approval request/response
  methods present in the installed Codex app-server schema; guessed method names
  are not acceptable implementation contracts.

## Architecture / Plan

```text
Codex app-server
        |
        | approval request
        v
codex-approval-gate (host-owned)
        |
        | command/risk summary
        v
macOS LocalAuthentication
        |
        | allow / deny
        v
Codex app-server approval response
```

### Components

| Component | Responsibility |
| --- | --- |
| `codex-approval-gate` | Parse request、apply policy、call authenticator、return decision |
| `TouchIDAuthenticator` | Invoke macOS `LocalAuthentication` without exposing biometric data |
| `PasskeyAuthenticator` | Optional later adapter for platform Passkey/WebAuthn |
| `RiskPolicy` | Classify requests and determine whether biometric approval is allowed |
| `AuditLog` | Write bounded local decision records without secrets |
| Codex adapter | Connect to the verified app-server transport and protocol |

### Confirmed app-server surface

The installed `codex-cli 0.153.4` generated an experimental schema containing:

- `item/commandExecution/requestApproval`
- `item/fileChange/requestApproval`
- `item/permissions/requestApproval`
- `CommandExecutionRequestApprovalParams` with `request id`, `itemId`,
  `threadId`, `turnId`, `command`, `cwd`, `kind`, `reason`, available decisions,
  and optional permission/policy amendments
- command decisions `accept`, `decline`, `cancel`, plus session or policy
  amendment variants
- command and file-change responses both use `{ "decision": ... }` with
  `accept`, `acceptForSession`, `decline`, or `cancel` variants
- permission responses use `{ "permissions": ... }` with an optional `scope`
  of `turn` or `session`; this surface requires a separate, stricter policy

The command request includes enough context for exact request binding. File
change and permission requests use different payloads and require separate
policy adapters; they shall not be treated as shell command approvals.
The installed command-approval schema does not expose sandbox mode in the
request payload, so the first version cannot display a per-request sandbox
value and must treat it as unavailable.

The remote transport on a Unix socket is WebSocket: the client first sends
`GET /rpc` with a WebSocket Upgrade, then sends app-server JSON as WebSocket
text frames. The proxy must perform both handshakes and mask frames sent to the
backend.

### Decisions

- **Decision:** gate 拆成獨立的 `miyago9267/codex-approval-gate` repository，
  以 standalone helper／package 交付。
  - **Reason:** approval bridge 有自己的 build、release、install 與 rollback
    生命週期，不應綁定 dotfile 版本。
  - **By:** Miyago (2026-09-09)
- **Decision:** 使用 host-controlled bridge，不使用 skill 直接取得核准。
  - **Reason:** model 可讀取 skill 內容，skill 不能成為權限判定根源。
  - **By:** Miyago (2026-09-09)
- **Decision:** Touch ID 作為第一個 authenticator，Passkey 保留 adapter 介面。
  - **Reason:** macOS 本機 Touch ID 整合路徑較短，Passkey 需要額外處理
    WebAuthn／credential provider lifecycle。
  - **By:** Miyago (2026-09-09)
- **Decision:** biometric approval 只核准單一 request，不建立 session-wide
  approval lease。
  - **Reason:** 降低 command substitution、replay 和誤授權風險。
  - **By:** Miyago (2026-09-09)

## Risk Policy

### Biometric approval allowed by default

- read-only command
- workspace 內可逆的寫入
- 已在目前 session 明確授權範圍內的低風險操作

### Additional gate required

- `sudo`／root
- credential broker、secret、Keychain 或 token 操作
- production、remote、deploy、release 或 external publish
- destructive、irreversible 或跨 workspace 操作
- command 內容無法穩定 hash 或 request context 不完整

這些類型預設回到人工確認或拒絕；biometric 成功本身不提升操作權限。

## Token and Audit Contract

Approval token 至少包含：

- `session_id`
- `request_id`
- `command_sha256`
- `cwd`
- `runtime`
- `issued_at`
- `expires_at`
- `decision`
- `nonce`

Audit record 可保存 metadata、hash、decision 和 deny reason，不保存 command
中的 secret、完整 credential、Passkey material 或 LocalAuthentication 回傳
內容。

## Phases

### Phase 1: Protocol discovery

- [x] 匯出目前安裝版本的 app-server JSON schema。
- [x] 找出 command、file change、permission approval request 的實際 method。
- [x] 找出 command、file change、permission response encoding。
- [x] 驗證 WebSocket request id 與 response correlation rules。
- [x] 確認 Unix socket remote transport 適合 wrapper，且其 wire format 是
  WebSocket。
- [x] 建立 request fixture，包含低風險、高風險與 malformed cases。

### Phase 2: Dry-run bridge

- [x] 建立 standalone package 與 CLI entrypoint。
- [x] 以 mock authenticator 驗證 request matching、hash、TTL 和 deny path。
- [x] 以 WebSocket fixture 驗證 proxy 可回傳真正 approval。
- [x] 加入 unit test、fixture test 和 protocol mismatch fail-closed test。

### Phase 3: Touch ID integration

- [x] 建立最小 macOS helper，透過 `LocalAuthentication` 回傳 allow／deny。
- [x] 將 biometric adapter 與 policy engine 分離。
- [x] 驗證 helper unavailable 時 fail closed；實機 allow 已由真實 Codex
  command approval 驗證；取消、鎖定與系統錯誤仍待 Touch ID device test。
- [x] 保留手動 approval fallback，先以明確 opt-in 啟用。

### Phase 4: Codex integration

- [x] 由 wrapper 啟動並連接 Codex app-server。
- [x] 對真實 app-server 執行 WebSocket `initialize` round-trip。
- [x] 以真實 model turn 觸發 command approval，並透過 mock authenticator
  完成 end-to-end round-trip。
- [x] 由 token-store tests 驗證 request hash 變更、重放、跨 session、跨
  runtime 和跨 cwd 都會拒絕。
- [x] 更新 Codex setup／usage 文件與 rollback 指令。
- [x] 將 gate 拆成獨立 `miyago9267/codex-approval-gate` repository，提供
  installer、AI playbook 與 uninstall／rollback。

## Verification

- Protocol fixture tests pass against the installed Codex version.
- Current tests cover allow、request mismatch、expiry、replay and unavailable
  helper; cancel and native timeout remain environment-dependent checks.
- Touch ID prompt test covers request id、session id、cwd and exact command.
- 實機 Touch ID allow 已通過：真實 Codex command 在 read-only sandbox 中觸發
  approval，proxy 以 Touch ID 回傳 `accept`，audit 記錄為 biometric mode。
- Touch ID helper never outputs biometric data or secrets to stdout、logs or
  files.
- A command changed after the biometric prompt is denied.
- A second approval using the same token is denied.
- Existing manual approval still works when the gate is disabled or unavailable.
- `git diff --check` and repository Markdown lint pass.

## Files

- `docs/specs/codex-biometric-approval-gate/SPEC.md` - 本規格。
- `miyago9267/codex-approval-gate` - standalone bridge repository，包含 package、
  installer、Touch ID helper 與測試。
- `config/ai/codex/` - 只在 Phase 4、protocol 驗證完成後調整。
- `config/ai/codex/USAGE.md` - 啟用、停用與 rollback 說明。

## Open Questions

- file change approval 的具體 response decision 與 request-to-item context
  如何綁定？
- permission approval 是否一律需要人工確認，或能定義有限的 biometric-safe
  permission profile？
- Touch ID helper 使用 Swift executable，或由既有 native host process 管理？
- audit log 放在 dotfile 管理範圍外的哪個 local data path？
- Passkey 是否需要第一版支援，或只保留 authenticator interface？

目前實作已選定 Swift executable、`~/.local/state/codex-approval-gate/`
audit path，並保留 Passkey interface；以上三項不再阻擋第一版。

## Evidence

- Installed binary: `codex-cli 0.153.4`
- Generated schema: `codex app-server generate-json-schema --experimental`
- Remote client capture: `codex --remote unix://PATH --no-alt-screen`
- Real smoke: `codex app-server --listen unix://PATH` through the approval proxy

The real `thread/start` and `turn/start` smoke completed successfully, but the
live model turn initially used an already-allowed workspace command and did not
emit an approval request. With a read-only sandbox and a shell redirect, the
model emitted a real command approval; the proxy returned `accept` through the
mock authenticator and the command created the expected file. The WebSocket
fixture also verifies the approval response path end to end.
- The proxy's Touch ID adapter formats the approval context into the native
  prompt; the helper itself remains fail-closed when unavailable or timed out.
- Schema artifacts were generated under a temporary directory and are not part
  of the repository.
