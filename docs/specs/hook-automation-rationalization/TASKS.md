---
spec: hook-automation-rationalization
batch: 1
created: 2026-05-12
---

# Tasks: Claude Hook Automation Rationalization

> Spec: `docs/specs/hook-automation-rationalization/SPEC.md`
> Batch: 1

## 前置條件

- [x] 確認使用者接受雙軌方向
- [x] 確認第一批只做嚴謹且簡單的 hook

## 實作步驟

- [x] Step 1: 建立雙軌分類 spec 與追蹤檔
- [x] Step 2: 在 `settings.json` 接上 `strategic-compact`
- [x] Step 3: 新增 `git add` guard hook 並接到 `PreToolUse/Bash`
- [x] Step 4: 新增 commit attribution guard hook 並接到 `PreToolUse/Bash`
- [x] Step 5: 用樣本 payload 驗證三個 hook 的預期行為

## 驗證

- [x] 第一批 hook 與設定已完成
- [x] 測試通過（見 `TESTS.md`）
- [x] `PROGRESS.md` 已更新
