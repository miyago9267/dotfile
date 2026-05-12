---
name: strategic-compact
description: 在邏輯斷點建議手動 /compact，避免 auto-compaction 在任務中段丟失 context。
---

# Strategic Compact Skill

在工作流程的邏輯斷點建議手動 `/compact`，而非依賴任意觸發的 auto-compaction。

## 為什麼要策略性 compact

Auto-compaction 的問題：

- 常在任務中段觸發，丟失重要 context
- 不感知邏輯邊界
- 可能打斷多步驟操作

策略性 compact 的時機：

- **探索完成、開始實作前** -- compact 研究 context，保留實作計畫
- **里程碑完成後** -- 為下一階段清出空間
- **重大 context 切換前** -- 清除前一個任務的探索 context

## Hook 設定

`suggest-compact.sh` 在 PreToolUse（Edit/Write）時執行：

1. 追蹤 tool call 次數
2. 到達閾值（預設 50）時建議 compact
3. 之後每 25 次提醒一次

安裝此 plugin 後，hook 會自動透過 `hooks/hooks.json` 註冊。

## 環境變數

- `COMPACT_THRESHOLD` -- 首次建議前的 tool call 數（預設 50）

## 最佳實踐

1. **規劃完成後 compact** -- 計畫定案後清出空間開始實作
2. **除錯完成後 compact** -- 清除錯誤排查的 context
3. **實作中途不要 compact** -- 保留相關變更的 context
4. **讀建議再決定** -- hook 告訴你「何時」，你決定「是否」
