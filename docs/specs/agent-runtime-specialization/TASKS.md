---
spec: agent-runtime-specialization
batch: 1
created: 2026-05-12
---

# Tasks: Runtime Specialization and Isolation for Codex, Claude, and Gemini

> Spec: `docs/specs/agent-runtime-specialization/SPEC.md`
> Batch: 1

## 前置條件

- [x] 讀取 shared `config/ai/AGENTS.md`
- [x] 讀取 `config/ai/codex/AGENTS.md`
- [x] 讀取 `config/ai/claude/CLAUDE.md`
- [x] 讀取 `config/ai/gemini/GEMINI.md`
- [x] 讀取 `setup_codex.sh` / `setup_gemini.sh`

## 實作步驟

### Phase 1: Spec

- [x] 記錄目前 runtime leakage 與共享 skill 供給問題
- [x] 定義 Codex / Claude / Gemini 的主職與非主職
- [x] 定義 shared-core skills 與 runtime-native skills 的邊界

### Phase 2: 待確認後實作

- [x] 收斂 `config/ai/codex/AGENTS.md`
- [x] 收斂 `config/ai/gemini/GEMINI.md`
- [x] 規劃 shared-core skill 目錄或對等結構
- [x] 調整 `setup_codex.sh`
- [x] 調整 `setup_gemini.sh`

## 驗證

- [x] 現況問題已有 spec 記錄
- [x] 使用者確認 specialization 方案
- [x] adapter 與 setup 變更完成
- [x] runtime leakage 清理完成
