---
spec: persona-thinking-loop
batch: 1
created: 2026-06-22
---

# Tests: Persona Rewrite, Think-First Mechanism, Loop Engineer

> Spec: `docs/specs/persona-thinking-loop/SPEC.md`

## 驗收條件 (EARS)

### R1: runtime-visible communication rules

- **When**: a Claude session starts
- **Shall**: persona hook output contains the condensed human-voice rules
- **驗證方式**: run `bash hooks/persona-reminder.sh`, grep for no-filler / no-tutoring rules
- **狀態**: [x] 通過

### R2: recap conflict resolved

- **When**: searching all three layers for ending rules
- **Shall**: exactly one ending rule exists (no-summary), no mandatory-recap line
- **驗證方式**: grep AGENTS.md + persona hook + feedback-global for "recap"/"summary"
- **狀態**: [x] 通過

### R4/R5: think-first injection on heavy task

- **When**: a heavy-task prompt is submitted
- **Shall**: hook emits goal->step->verify + deep-reasoning directive
- **驗證方式**: pipe a sample heavy prompt JSON to `think-first-router.sh`, assert output
- **狀態**: [x] 通過

### R9: hooks fail open

- **When**: hook receives malformed input or errors
- **Shall**: exit 0, emit nothing, never block the prompt
- **驗證方式**: pipe empty/garbage to hook, assert exit 0
- **狀態**: [x] 通過

## 測試案例

### 正常路徑

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | persona hook 輸出 | 含 condensed communication rules | [x] |
| 2 | heavy prompt 進 router | 注入 think-first + deep-reasoning | [x] |
| 3 | `~/.claude/loop.md` 存在且非空 | Loop Engineer 預設 prompt | [x] |

### 邊界案例

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | trivial prompt ("fix typo") | router 不注入 think-first | [x] |
| 2 | 中文 heavy prompt ("全面重構") | router 正常命中 | [x] |

### 錯誤處理

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | router 收到空 stdin | exit 0，無輸出 | [x] |
| 2 | router 收到非 JSON | exit 0，無輸出 | [x] |

## 備註

<!-- Batch 完成後隨 TASKS.md 一起封存 -->
