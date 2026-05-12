---
spec: shared-agent-contract
batch: 1
created: 2026-05-12
---

# Tasks: Shared AGENTS.md for Multi-Agent AI Configs

> Spec: `docs/specs/shared-agent-contract/SPEC.md`
> Batch: 1 -- 建立共用契約

## 前置條件

- [x] 讀取 `config/ai/claude/CLAUDE.md`
- [x] 讀取 `config/ai/codex/AGENTS.md`
- [x] 讀取 `config/ai/gemini/GEMINI.md`
- [x] 確認 `setup_codex.sh` / `setup_gemini.sh` 的現況
- [x] 確認 `config/ai/claude/CLAUDE.md` 目前有未提交修改

## 實作步驟

### Phase 1: 建立 shared contract

- [x] 建立 `config/ai/AGENTS.md`
- [x] 從 `CLAUDE.md` 提取跨 agent 通用規則
- [x] 排除 Claude 專屬 bootstrap / script / memory 引用
- [x] 保留 Monika persona 的共用層，但避免綁定單一 vendor runtime
- [x] 排除 context 壓縮與其他 runtime-specific workflow 規則

### Phase 2: 驗證與對齊

- [x] 檢查 shared `AGENTS.md` 是否可被 Codex / Gemini / 其他 agent 理解
- [x] 檢查內容是否與現有 `CLAUDE.md` 的硬規則一致
- [x] 確認沒有碰到 dirty 的 `config/ai/claude/CLAUDE.md`

### Phase 3: Claude adapter 化

- [x] 在 `config/ai/claude/CLAUDE.md` 開頭引用 shared `config/ai/AGENTS.md`
- [x] 移除已抽到 shared contract 的重複人格與共用硬規則
- [x] 保留 Claude 專屬 workflow、script、文件結構與記憶來源

### Phase 4: 補強 shared logic

- [x] 補入 assumptions / ambiguity 規則，避免靜默選解
- [x] 補入 simpler-path / push-back 規則，降低過度工程
- [x] 補入 surgical changes 規則，只清自己造成的 orphan
- [x] 補入 goal-driven execution 與 `step -> verify` 規則
- [x] 將多重解讀的提問格式補進 `ask-discipline`

## 驗證

- [x] `config/ai/AGENTS.md` 存在且內容為 LLM-agnostic
- [x] 文件未引入不存在的工具或流程
- [x] 文件保留 SDD / TDD / Safety / Search Before Ask
- [x] `config/ai/claude/CLAUDE.md` 已轉為 shared base + Claude extension
- [x] shared `AGENTS.md` 已補入 Karpathy-style guardrails
