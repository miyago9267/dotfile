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
           |- 有 -> 讀 spec，確認設計，照 PROGRESS.md 追蹤進度
           +- 沒有 -> 先建 spec + PROGRESS.md 對應區段，等 Miyago 確認，再實作
```

## 職責分離（硬規則）

- **Spec** (`docs/specs/<slug>/SPEC.md`)：只放設計文件（需求、ADR、架構決策）
- **Task** (`PROGRESS.md`)：只放任務追蹤（checkbox、Phase、Step）
- 不得在 Spec 中放 checkbox，不得在 PROGRESS.md 中放設計決策

## Commit 連動規則（硬規則）

每次 git commit 前，必須確認：

- 修改了對應 spec 的功能 -> 更新 `PROGRESS.md` 的 checkbox
- 新增功能但沒有 spec -> 先建 spec 和 `PROGRESS.md` 區段再 commit
- Commit message 格式：`<type>(<scope>): <desc>`，不加 AI 署名
- `docs/ai/` 不加入 commit（changelog、lessons 等是 AI 工作記錄，不上版控）
- commit 後不再修改任何檔案

## 工作流程

### 開始任務時

1. 讀取 `PROGRESS.md`（如有）
2. 讀取 `docs/ai/changelog.md` 最近記錄
3. 掃描 `docs/specs/` 找 active spec
4. 確認當前任務與已有進度的關係

### 執行任務中

- 重大決策立即記錄到 spec 的 `## 設計決策` 區
- 遇到阻礙記錄到 `PROGRESS.md` 的 pending 區

### 完成任務後

1. 更新 `PROGRESS.md` checkbox（`- [ ]` -> `- [x]`）
2. 更新 `docs/ai/changelog.md`
3. Spec 只在設計有變更時更新 `updated` 日期

## Context Compact 恢復

被 compact 後，按此順序重建 context：

1. 讀 `docs/ai/sessions/` 最新檔
2. 讀 `docs/ai/changelog.md` 最近 20 行
3. 讀 `PROGRESS.md` 確認全局進度
4. 讀取當前任務相關的 spec 檔
