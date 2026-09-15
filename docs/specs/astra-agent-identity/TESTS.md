---
spec: astra-agent-identity
batch: 1
created: 2026-09-15
---

# Tests: Astra 單一 Agent 身份與舊 runtime 相容

> Spec: `docs/specs/astra-agent-identity/SPEC.md`

## 驗收條件 (EARS)

### R1-R2: Canonical identity and aliases

- **When**: 讀取 shared contract、entry metadata 與 runtime bindings
- **Shall**: 看到 Astra 為 canonical identity，且舊名稱只出現在 compatibility
  alias 或既有 ID binding
- **驗證方式**: `rg` 檢查 source、binding 與 OpenCode labels
- **狀態**: [x] 通過

### R3: Scoped loading

- **When**: 檢查 self-contained task 的 shared、Zed 與 Astra routing instructions
- **Shall**: 不要求讀取整套 session、vault 或所有 runtime 文件
- **驗證方式**: static inspection of `AGENTS.md` and Zed/Astra adapters
- **狀態**: [x] 通過

### R4: Event-driven Skills

- **When**: 掃描 canonical Claude、Codex、Gemini 與 Astra skill frontmatter
- **Shall**: only `safe-ops` remains `alwaysApply: true`
- **驗證方式**: bounded `rg` plus allowlist check
- **狀態**: [x] 通過

### R5: Explicit Astra activation

- **When**: 執行 `setup_astra.sh` without `ASTRA_TARGET_ROOT`
- **Shall**: generate the Astra entry without silently changing the default home
- **驗證方式**: shell syntax check, generation diff, and target-root guard inspection
- **狀態**: [x] 通過

### R6: Generated compatibility

- **When**: run runtime setup and plugin validation scripts
- **Shall**: generated entries and legacy artifacts retain expected IDs and shared
  prefix
- **驗證方式**: setup scripts, sync check, and plugin validators
- **狀態**: [x] 通過

### R7: Completion gate

- **When**: review the shared contract and Astra adapter
- **Shall**: completion is not claimed while in-scope work or acceptance checks
  remain
- **驗證方式**: static anchor check and final task checklist
- **狀態**: [x] 通過

## 測試案例

### 正常路徑

| # | 測試 | 預期結果 | 狀態 |
| --- | --- | --- | --- |
| 1 | Astra source composition | generated entry has shared, personal, and adapter sections | [x] |
| 2 | Legacy binding preservation | old plugin and OpenCode IDs remain discoverable | [x] |

### 邊界案例

| # | 測試 | 預期結果 | 狀態 |
| --- | --- | --- | --- |
| 1 | `ASTRA_TARGET_ROOT` omitted | no default `CODEX_HOME` overwrite | [x] |
| 2 | unrelated local task | no forced vault or session-document read | [x] |

### 錯誤處理

| # | 測試 | 預期結果 | 狀態 |
| --- | --- | --- | --- |
| 1 | regular file at target skill path | setup stops instead of overwriting it | [x] |

## 備註

這是 config、prompt、routing 與 generated-output change；不新增 application behavior，
因此以 static regression checks 取代 application TDD。Markdown 驗證採本次新增與修改的
compact surface；既有 legacy 文件的 repository-wide lint debt 不屬於本次 scope。
