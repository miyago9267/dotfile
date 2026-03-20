---
id: spec-sdd-v2
title: SDD v2 Spec 系統重新設計
status: in-progress
created: 2026-03-20
updated: 2026-03-20
author: Miyago
tags: [sdd, spec, architecture, workflow]
priority: high
---

# SDD v2 Spec 系統重新設計

## Background

現有 SDD 系統有三個結構性問題：

1. **Changelog 無窮迴圈**：`docs/ai/changelog.md` 每次操作都會改動，commit 後又產生新的 unstaged change，導致每次 commit 都要處理它
2. **文件膨脹**：`PROGRESS.md` 累積所有 phase 的 checkbox，越來越肥；SPEC.md 也混入了本應分離的進度追蹤
3. **手動封存**：完成的 phase/batch 需要人工提醒才會封存，容易遺忘

根本原因：不同生命週期的內容混在同一層。changelog/lessons/sessions 是 session 級別的工作記錄（每次操作都改），SPEC/TASKS/PROGRESS 是 feature 級別的設計文件（設計變更時才改）。兩者應該分離。

## Requirements (EARS)

### 核心需求

- **R1**: When all checkboxes in TASKS.md are checked, the system shall archive TASKS.md and TESTS.md to `archive/` with timestamp prefix
- **R2**: When a Phase in PROGRESS.md is marked completed, the system shall move that Phase block to `archive/`
- **R3**: While `.ai/` files are modified, the system shall NOT include them in git commits
- **R4**: When `end-session.sh` runs, the system shall merge CURRENT.md into HANDOFF.md and clear CURRENT.md
- **R5**: When `bootstrap.sh` runs, the system shall read HANDOFF.md to restore context
- **R6**: When `log.sh` runs, the system shall write to `.ai/changelog.md` (not `docs/ai/`)
- **R7**: When `lesson.sh` runs, the system shall write to `.ai/lessons.md` (not `docs/ai/`)
- **R8**: When `ai-export.sh` runs, the system shall copy selected `.ai/` content to `docs/ai/` for manual commit

### 封存需求

- **R9**: When `spec-archive.sh tasks <slug>` runs, the system shall move `TASKS.md` and `TESTS.md` to `archive/YYYYMMDD-TASKS.md` and `archive/YYYYMMDD-TESTS.md`
- **R10**: When `spec-archive.sh phase <slug>` runs, the system shall extract completed Phase blocks from PROGRESS.md to `archive/`

## Non-goals

- 不做自動 commit（所有 commit 仍由使用者/AI 手動觸發）
- 不做跨 repo 的 spec 同步
- 不做 spec 版本控制（用 git history 即可）
- 不做 spec 的 CI/CD 驗證

## Alternatives Considered

### spec-kit (npm)

通用 spec 管理工具，但過度工程 -- 我們只需要 markdown + shell script。引入 npm 依賴不合理。

### OpenSpec

結構化 API spec 格式，但針對 API 設計，不適合通用的 feature spec。

### GSD (Get Stuff Done)

任務管理框架，但缺乏 spec/design 層面的追蹤，只有 task tracking。

### 維持現狀 + gitignore

最簡單的方案：把 `docs/ai/` 加入 `.gitignore`。問題是 `docs/ai/` 下的 changelog 和 lessons 有長期價值，完全 gitignore 會遺失這些資訊。所以採用兩層分離：工作記憶（`.ai/`）永遠 gitignore，精選內容透過 `ai-export.sh` 手動匯出到 `docs/ai/` 再 commit。

## Rabbit Holes

1. **不要試圖自動判斷 "batch 是否完成"** -- checkbox 可能被部分勾選又改回，自動封存會造成混亂。封存一律手動觸發。
2. **不要把 HANDOFF.md 做成 JSON** -- markdown 更容易人工閱讀和編輯，JSON 解析在 shell 中也很麻煩。
3. **不要讓 end-session.sh 自動 commit** -- 違反 "commit 是最後一步" 原則。
4. **sed -i 在 macOS 和 Linux 行為不同** -- macOS 的 `sed -i` 需要 `sed -i ''`，Linux 不需要。所有 script 都要處理這個差異。

## Architecture

### 兩層分離設計

```text
規格層（永遠 commit）                      工作記憶層（永遠 gitignore）
docs/specs/<slug>/                        .ai/
  SPEC.md          What + Why + ADR         CURRENT.md       這個 session 在幹嘛
  TASKS.md         當前 batch 的步驟         HANDOFF.md       給下一個 session 的交接
  TESTS.md         驗收條件 (EARS)           changelog.md     操作紀錄
  PROGRESS.md      Phase 級追蹤              lessons.md       踩坑紀錄
  archive/         完成的封存                 sessions/        session 摘要
                                            snapshots/       mid-session checkpoint
```

### 資料流

```text
操作中:  log.sh -> .ai/changelog.md        (不進 git)
         lesson.sh -> .ai/lessons.md       (不進 git)

收工時:  end-session.sh -> .ai/HANDOFF.md  (不進 git)
                        -> .ai/sessions/   (不進 git)

新 session: bootstrap.sh <- .ai/HANDOFF.md (讀取交接)
                          <- .ai/changelog.md (最近 20 行)

手動匯出: ai-export.sh -> docs/ai/         (手動 commit)

封存:    spec-archive.sh -> docs/specs/<slug>/archive/
```

### 檔案職責

| 檔案 | 層 | 職責 | 更新時機 |
|------|----|------|----------|
| `SPEC.md` | 規格 | 設計決策、需求、ADR | 設計變更時 |
| `TASKS.md` | 規格 | 當前 batch 的 checkbox | 實作中每步完成 |
| `TESTS.md` | 規格 | 驗收條件 (EARS) | 設計變更時 |
| `PROGRESS.md` | 規格 | Phase 級追蹤 | Phase 完成時 |
| `CURRENT.md` | 工作記憶 | 當前 session 狀態 | 開工時/執行中 |
| `HANDOFF.md` | 工作記憶 | 跨 session 交接 | end-session 時 |
| `changelog.md` | 工作記憶 | 操作記錄 | 每次操作後 |
| `lessons.md` | 工作記憶 | 踩坑記錄 | 發現教訓時 |

## ADR

### ADR-1: .ai/ 放在 repo root 而非 docs/ai/

`docs/ai/` 的問題是它在 git 追蹤範圍內，即使加了 `.gitignore` 也容易被 `git add .` 意外加入。`.ai/` 作為隱藏目錄，更不容易被誤操作，且 `.gitignore` 中 `.ai/` 的規則更明確。

### ADR-2: HANDOFF.md 取代 session summary 作為跨 session 接力

Session summary 是「回顧」，HANDOFF 是「交接」。回顧記錄做了什麼，交接記錄下一步該做什麼。bootstrap 讀 HANDOFF 比讀 session summary 更有方向性。

### ADR-3: TASKS.md 從 PROGRESS.md 分離

PROGRESS.md 追蹤 Phase 級別（高層），TASKS.md 追蹤當前 batch 的具體步驟（低層）。分離後 TASKS.md 可以在 batch 完成時整份封存，PROGRESS.md 保持精簡。
