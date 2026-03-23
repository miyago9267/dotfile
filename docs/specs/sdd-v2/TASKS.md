---
spec: sdd-v2
batch: 1
created: 2026-03-24
---

# Tasks: SDD v2 Spec 系統重新設計

> Spec: `docs/specs/sdd-v2/SPEC.md`
> Batch: 1 -- 全功能實作

## 前置條件

- [x] 確認現有 SDD 系統的三個結構性問題（changelog 無窮迴圈、文件膨脹、手動封存）
- [x] 確認兩層分離架構設計（規格層 vs 工作記憶層）
- [x] 確認 .gitignore 已排除 `.ai/`

## 實作步驟

### R1/R2: 封存機制

- [x] 實作 `spec-archive.sh tasks <slug>` -- 封存 TASKS.md + TESTS.md 到 `archive/` 帶日期前綴
- [x] 實作 `spec-archive.sh phase <slug>` -- 從 PROGRESS.md 擷取已完成 Phase 到 `archive/`

### R3: .ai/ 隔離

- [x] 建立 `.ai/` 目錄結構（CURRENT.md, HANDOFF.md, changelog.md, lessons.md, sessions/, snapshots/）
- [x] 確認 `.gitignore` 包含 `.ai/` 規則
- [x] 所有 script 寫入 `.ai/` 而非 `docs/ai/`

### R4/R5: Session 生命週期

- [x] 實作 `end-session.sh` -- 合併 CURRENT.md 到 HANDOFF.md 並清空 CURRENT.md
- [x] 實作 `bootstrap.sh` -- 讀取 HANDOFF.md 恢復上下文
- [x] 支援 `--compact` 模式精簡輸出
- [x] 支援 `snapshot.sh save/restore/list` 中段存檔

### R6/R7: Changelog 和 Lessons 分離

- [x] 實作 `log.sh` 寫入 `.ai/changelog.md`
- [x] 實作 `lesson.sh` 寫入 `.ai/lessons.md`
- [x] `lesson.sh` 支援 key 去重

### R8: 手動匯出

- [x] 實作 `ai-export.sh` -- 從 `.ai/` 複製精選內容到 `docs/ai/`
- [x] 支援 `--all` 參數匯出全部

### 輔助工具

- [x] 實作 `check.sh` 健康檢查（`--init` 初始化 .ai/ 結構）
- [x] 實作 `skill-create.sh` 建立新 skill

### 模板系統

- [x] 建立 `docs/specs/_templates/SPEC.template.md`
- [x] 建立 `docs/specs/_templates/TASKS.template.md`
- [x] 建立 `docs/specs/_templates/TESTS.template.md`
- [x] 建立 `docs/specs/_templates/PROGRESS.template.md`

### 行為規則整合

- [x] 更新 CLAUDE.md 全域規則反映兩層分離架構
- [x] 更新 Scripts CLI 對照表
- [x] 定義職責分離原則（規格層 vs 工作記憶層）
- [x] 定義 Token 節省原則

## 驗證

- [x] 所有 R1-R10 需求對應的 script 已實作
- [x] .ai/ 目錄結構完整
- [x] 模板系統完整
- [x] CLAUDE.md 行為規則已更新
