---
name: auto-spec
description: "跨模組、architecture、product behavior 或明確指定 SDD 時，建立並追蹤最小 spec。"
when_to_use: "只有高影響或使用者明確要求 spec 時觸發；local reversible config、docs、prompt edit 跳過。"
tags: [spec, sdd, architecture, planning]
effort: medium
shell: optional
runtime-scope: shared-core
alwaysApply: false
---

# 自動規格追蹤

## 觸發決策樹（不需使用者提醒）

```text
任務進來
  |
是否為跨模組、architecture、product behavior 或明確 SDD？
  |- 否 -> 直接執行，做 targeted verification
  +- 是 -> 找 active spec
              |
         docs/specs/ 下有相關 spec？
           |- 有 -> 讀 spec，確認設計，照 TASKS.md / PROGRESS.md 追蹤進度
           +- 沒有 -> 建立最小 spec；若 shared contract 要求 approval，才等待確認
```

## 職責分離（硬規則）

- **Spec** (`docs/specs/<slug>/SPEC.md`)：只放設計文件（需求、ADR、架構決策）
- **Tasks** (`docs/specs/<slug>/TASKS.md`)：只放當前 batch 的 checkbox
- **Tests** (`docs/specs/<slug>/TESTS.md`)：只放驗收條件（EARS 語法）
- **Progress** (`docs/specs/<slug>/PROGRESS.md`)：只放 Phase 級追蹤
- 不得在 Spec 中放 checkbox，不得在 TASKS.md 中放設計決策

## Commit 連動規則（硬規則）

涉及 spec 的 git commit 前，確認：

- 修改了對應 spec 的功能 -> 更新 `TASKS.md` 的 checkbox
- 新增功能但沒有 spec -> 先建 spec 和 TASKS.md 再 commit
- Commit message 格式預設為 `<type>: <中文簡短說明>`；scope 只有能提升辨識度時才
  加成 `<type>(<scope>): <中文簡短說明>`，不加 AI 署名
- `.ai/` 不加入 commit（changelog、lessons 等是 AI 工作記錄，不上版控）
- commit 後不再修改任何檔案

## 工作流程

### 需要 spec 時

1. 讀取與目前目標直接相關的 `SPEC.md`、`TASKS.md`、`TESTS.md` 或 `PROGRESS.md`
2. 確認當前任務與已有進度的關係
3. 只有發生 design change、phase change 或使用者要求時才更新 tracking

### 執行任務中

- 重大決策立即記錄到 spec 的 ADR 區
- 遇到阻礙記錄到 `.ai/CURRENT.md`

### 完成 spec-backed 任務後

1. 更新 `TASKS.md` checkbox（`- [ ]` -> `- [x]`）
2. 更新 `.ai/changelog.md`（透過 log.sh）
3. Spec 只在設計有變更時更新 `updated` 日期
4. Batch 完成 -> `spec-archive.sh tasks <slug>`
5. Phase 完成 -> `spec-archive.sh phase <slug>`

一般 local task 不因為 compact 而讀取整套 `.ai/` 或 `docs/specs/`；只有明確 resume
或 spec-backed task 才恢復相關檔案。
