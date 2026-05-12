---
spec: agent-runtime-specialization
created: 2026-05-12
---

# Progress: Runtime Specialization and Isolation for Codex, Claude, and Gemini

> Spec: `docs/specs/agent-runtime-specialization/SPEC.md`

## Phase 1: 定義 specialization contract

> Status: completed

- 目標：把三個 runtime 的角色與 skill 隔離原則明文化
- Batch 1：shared/core/runtime-native 分層、角色偏向、setup leakage 記錄

## Phase 2: Runtime adapter 收斂

> Status: completed

- 目標：瘦身 Codex / Gemini adapter，強化三邊角色

## Phase 3: Skill 供給結構收斂

> Status: completed

- 目標：改 setup 與 skill 供給，不再整包灌 Claude skills

## Phase 4: 清理 runtime leakage

> Status: completed

- 目標：清掉 Gemini / Codex 中最明顯的 Claude runtime leakage，並避免再由 setup script 灌回去
