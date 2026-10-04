---
spec: shared-computer-use
batch: 1
created: 2026-10-04
---

# Tasks: 共通 Computer Use MCP 與 Jev 決策層

> Spec: `docs/specs/shared-computer-use/SPEC.md`
> Batch: 1（S1 共通 driver）

## 前置條件

- [x] `security-reviewer` 完成並把條件收進 plan
- [x] `plan-verifier` 回 READY
- [x] Miyago 核准 S1（2026-10-04）

## 實作步驟

- [x] Step 1: 比對 registry integrity 後安裝 `open-computer-use@0.3.6`，驗已安裝 app 的
      Team ID 與公證狀態
- [x] Step 2: 先寫 launcher 測試（Red）
- [x] Step 3: 寫 `config/ai/shared/computer-use/computer-use-mcp.sh`（Green）
- [x] Step 4: 寫 `script/common/setup_computer_use.sh`
- [x] Step 5: `--dry-run`、`--apply`、`--remove` 來回驗證，最後停在已註冊
- [x] Step 6: Miyago 執行 `open-computer-use doctor` 並授權 Accessibility、Screen Recording
- [x] Step 7: 實機驗收（TESTS.md 的 a、b、d、f、i）
- [x] Step 8: fresh `verifier` 確認

## 驗證

- [x] 所有步驟完成
- [x] 測試通過（見 TESTS.md）
- [x] 文件更新

## 備註

- 不 commit、不 push，由 Miyago 決定。
- Batch 完成後用 `spec-archive.sh tasks shared-computer-use` 封存。
