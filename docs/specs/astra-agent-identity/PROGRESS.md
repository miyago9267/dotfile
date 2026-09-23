---
spec: astra-agent-identity
created: 2026-09-15
---

# Progress: Astra 單一 Agent 身份與舊 runtime 相容

> Spec: `docs/specs/astra-agent-identity/SPEC.md`

## Phase 1: Canonical identity

> Status: completed

- 目標：將 shared contract、entry metadata 與 runtime labels 統一為 Astra
- Batch 1：保留 Monika、`monika-*` 與 `studio-monika` 作為 compatibility aliases

## Phase 2: Skill routing

> Status: completed

- 目標：縮小 Skill trigger、移除無關文件強制讀取、合併重複檢查
- Batch 1：Claude、Gemini、Zed 與 domain trigger 已收斂；`safe-ops` 是唯一常駐安全層

## Phase 3: Astra profile

> Status: completed

- 目標：建立 explicit-only Astra adapter、allowlist 與 isolated setup
- Batch 1：`config/ai/astra/` 與 `script/common/setup_astra.sh` 已建立

## Phase 4: Verification

> Status: completed

- 目標：重新生成 outputs 並完成 compatibility、syntax、metadata、YAML、Markdown 與
  diff checks
- Batch 1：Astra isolation smoke、runtime sync、shell/YAML、plugin validators、skill
  metadata 與 scoped Markdown lint 均通過；未把既有 legacy 文件的 repository-wide
  lint debt 混入本次 patch

## Superseded（2026-09-23）

- Miyago 要求恢復改名前的 Monika persona：shared contract 的 Identity/Persona、
  Claude persona hook、OpenCode agents 與 Astra overlay 的 identity 都改回 Monika。
- `Astra` 只保留為 alias 與 `gpt-6-astra` model mode 名稱；`config/ai/astra/`
  overlay 與 `setup_astra.sh` 保留。
