---
name: auto-spec
description: 規格與進度追蹤（全域版，模型無關）
alwaysApply: true
---

# 自動規格追蹤

## 觸發決策樹（不需使用者提醒）

```text
任務進來
  |
是否為 trivial fix？（單行修正、typo、明確的 one-liner）
  |- 是 -> 直接執行，完成後 log.sh
  +- 否 -> 找 active spec
              |
         docs/specs/ 下有相關 spec？
           |- 有 -> 讀 spec，確認設計，照 TASKS.md / PROGRESS.md 追蹤進度
           +- 沒有 -> 先建 spec（從 _templates/ 複製），等使用者確認，再實作
```

## 職責分離（硬規則）

- **Spec** (`docs/specs/<slug>/SPEC.md`)：只放設計文件（需求、ADR、架構決策）
- **Tasks** (`docs/specs/<slug>/TASKS.md`)：只放當前 batch 的 checkbox
- **Tests** (`docs/specs/<slug>/TESTS.md`)：只放驗收條件（EARS 語法）
- **Progress** (`docs/specs/<slug>/PROGRESS.md`)：只放 Phase 級追蹤
- 不得在 Spec 中放 checkbox，不得在 TASKS.md 中放設計決策

## Commit 連動規則（硬規則）

每次 git commit 前，必須確認：

- 修改了對應 spec 的功能 -> 更新 `TASKS.md` 的 checkbox
- 新增功能但沒有 spec -> 先建 spec 和 TASKS.md 再 commit
- Commit message 格式：`<type>(<scope>): <desc>`，不加 AI 署名
- `.ai/` 不加入 commit（changelog、lessons 等是 AI 工作記錄，不上版控）
- commit 後不再修改任何檔案

## 工作流程

### 開始任務時

1. 讀取 `.ai/HANDOFF.md`（如有）
2. 讀取 `.ai/changelog.md` 最近記錄
3. 掃描 `docs/specs/` 找 active spec
4. 確認當前任務與已有進度的關係
5. 更新 `.ai/CURRENT.md` 記錄當前任務

### 執行任務中

- 重大決策立即記錄到 spec 的 ADR 區
- 遇到阻礙記錄到 `.ai/CURRENT.md`

### 完成任務後

1. 更新 `TASKS.md` checkbox（`- [ ]` -> `- [x]`）
2. 更新 `.ai/changelog.md`（透過 log.sh）
3. Spec 只在設計有變更時更新 `updated` 日期
4. Batch 完成 -> `spec-archive.sh tasks <slug>`
5. Phase 完成 -> `spec-archive.sh phase <slug>`

## Context Compact 恢復

被 compact 後，按此順序重建 context：

1. 讀 `.ai/HANDOFF.md`
2. 讀 `.ai/changelog.md` 最近 20 行
3. 讀 `.ai/lessons.md`
4. 掃描 `docs/specs/` 找 active spec
5. 讀取當前任務相關的 TASKS.md
