---
description: "Spec-Driven Development (SDD) v2 -- 啟動或繼續 spec 驅動開發流程。"
user-invocable: true
---

# /sdd [feature-name]

執行 SDD v2 工作流程。

若提供 feature-name，直接搜尋 `docs/specs/<feature-name>/SPEC.md`。
若未提供，從當前對話推斷相關 spec。

## SDD v2 工作流程（硬規則）

1. 非 trivial 任務 -- 找或建 `docs/specs/<slug>/SPEC.md`
2. 確認 spec -- 拆 `TASKS.md`（當前 batch only）
3. 有測試需求 -- 寫 `TESTS.md`（EARS 語法）
4. 開工 -- 更新 `.ai/CURRENT.md`
5. 完成一步 -- 打勾 `TASKS.md`
6. Batch 全完成 -- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/spec-archive.sh tasks <slug>` 封存
7. Phase 完成 -- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/spec-archive.sh phase <slug>` 封存
8. 收工 -- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/end-session.sh`（CURRENT -> HANDOFF）
9. `.ai/` 的改動不進 commit
10. `docs/specs/` 的改動才進 commit

## 目錄結構

```text
docs/specs/<slug>/
  SPEC.md          # What + Why + ADR + Alternatives + Rabbit Holes
  TASKS.md         # 當前 batch 的實作步驟（checkbox）
  TESTS.md         # 測試案例 + EARS 語法驗收條件
  PROGRESS.md      # Phase 級追蹤
  archive/         # 完成的 phase/batch 封存

.ai/               # 工作記憶（永遠 gitignore）
  CURRENT.md       # 這個 session 在幹嘛
  HANDOFF.md       # 給下一個 session 的交接
  changelog.md     # 操作紀錄
  lessons.md       # 踩坑紀錄
  sessions/        # session 摘要
  snapshots/       # mid-session checkpoint
```

## 模板

新 spec 可從 `docs/specs/_templates/` 複製模板：

- `SPEC.template.md`
- `TASKS.template.md`
- `TESTS.template.md`
- `PROGRESS.template.md`

## 職責分離

| 檔案 | 職責 | 更新時機 |
|------|------|----------|
| `SPEC.md` | 設計決策、需求、ADR | 設計變更時 |
| `TASKS.md` | 當前 batch checkbox | 每步完成時 |
| `TESTS.md` | 驗收條件 | 設計變更時 |
| `PROGRESS.md` | Phase 追蹤 | Phase 完成時 |
| `.ai/CURRENT.md` | 當前 session | 開工/執行中 |
| `.ai/HANDOFF.md` | 跨 session 交接 | end-session 時 |
