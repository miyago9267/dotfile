---
spec: sdd-v2
created: 2026-03-24
---

# Tests: SDD v2 Spec 系統重新設計

> Spec: `docs/specs/sdd-v2/SPEC.md`

## 驗收條件 (EARS)

### R1: Batch 完成時封存 TASKS + TESTS

- [x] **When** `spec-archive.sh tasks <slug>` 執行，**the system shall** 將 `TASKS.md` 移動到 `archive/YYYYMMDD-TASKS.md`
- [x] **When** `spec-archive.sh tasks <slug>` 執行，**the system shall** 將 `TESTS.md` 移動到 `archive/YYYYMMDD-TESTS.md`
- [x] **When** 目標 slug 目錄不存在，**the system shall** 顯示錯誤訊息並退出

### R2: Phase 完成時封存

- [x] **When** `spec-archive.sh phase <slug>` 執行，**the system shall** 從 `PROGRESS.md` 擷取已完成的 Phase block 到 `archive/`
- [x] **When** PROGRESS.md 無已完成的 Phase，**the system shall** 顯示提示訊息

### R3: .ai/ 不進 git

- [x] **While** `.ai/` 目錄下的檔案被修改，**the system shall** 不將其納入 git commit
- [x] **When** 檢查 `.gitignore`，**the system shall** 包含 `.ai/` 排除規則
- [x] **When** `log.sh` 執行，**the system shall** 寫入 `.ai/changelog.md` 而非 `docs/ai/changelog.md`
- [x] **When** `lesson.sh` 執行，**the system shall** 寫入 `.ai/lessons.md` 而非 `docs/ai/lessons.md`

### R4: end-session 交接

- [x] **When** `end-session.sh` 執行，**the system shall** 合併 `CURRENT.md` 內容到 `HANDOFF.md`
- [x] **When** `end-session.sh` 執行，**the system shall** 清空 `CURRENT.md`
- [x] **When** `end-session.sh` 執行，**the system shall** 產生 session summary 到 `.ai/sessions/`

### R5: bootstrap 恢復上下文

- [x] **When** `bootstrap.sh` 執行，**the system shall** 讀取 `HANDOFF.md` 恢復上下文
- [x] **When** `bootstrap.sh --compact` 執行，**the system shall** 以精簡格式輸出
- [x] **When** `HANDOFF.md` 不存在，**the system shall** 正常啟動不報錯

### R6: log.sh 寫入 .ai/

- [x] **When** `log.sh <type> <scope> <path> <desc>` 執行，**the system shall** 追加記錄到 `.ai/changelog.md`
- [x] **When** 記錄已存在（重複），**the system shall** 跳過不重複寫入

### R7: lesson.sh 寫入 .ai/

- [x] **When** `lesson.sh <cat> <key> <desc>` 執行，**the system shall** 追加記錄到 `.ai/lessons.md`
- [x] **When** 相同 key 已存在，**the system shall** 跳過不重複寫入（去重）

### R8: ai-export 手動匯出

- [x] **When** `ai-export.sh` 執行，**the system shall** 複製精選 `.ai/` 內容到 `docs/ai/`
- [x] **When** `ai-export.sh --all` 執行，**the system shall** 匯出全部 `.ai/` 內容

### R9: spec-archive tasks 封存

- [x] **When** `spec-archive.sh tasks <slug>` 執行，**the system shall** 將 TASKS.md 移動到 `archive/YYYYMMDD-TASKS.md`
- [x] **When** `spec-archive.sh tasks <slug>` 執行，**the system shall** 將 TESTS.md 移動到 `archive/YYYYMMDD-TESTS.md`

### R10: spec-archive phase 封存

- [x] **When** `spec-archive.sh phase <slug>` 執行，**the system shall** 從 PROGRESS.md 擷取已完成 Phase block 到 `archive/`

## 非功能性驗證

- [x] 所有 script 在 macOS (zsh) 環境下正常執行
- [x] `sed -i` 在 macOS 和 Linux 的差異已處理（Rabbit Hole #4）
- [x] 模板系統完整（SPEC/TASKS/TESTS/PROGRESS 四份模板到位）
- [x] CLAUDE.md 全域規則已反映兩層分離架構
