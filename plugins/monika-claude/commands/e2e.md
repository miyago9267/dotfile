---
description: 端對端測試（Playwright）-- 生成測試、執行、擷取 artifacts，識別不穩定測試。
---

# /e2e [描述]

呼叫 **e2e-runner agent** 生成並執行 Playwright 端對端測試。

## 功能

1. 分析使用者操作流程，生成測試場景
2. 使用 Page Object Model 生成 Playwright 測試
3. 跨瀏覽器執行（Chrome、Firefox、Safari）
4. 失敗時擷取截圖、影片、trace
5. 識別不穩定測試並建議修復

## 使用時機

- 驗證關鍵使用者流程（登入、結帳、核心操作）
- 多步驟流程的整合測試
- 前後端整合驗證
- 準備上線前的最終驗證

## Artifacts 產出

| 觸發條件 | 產出 |
| --- | --- |
| 每次執行 | HTML 報告、JUnit XML |
| 失敗時 | 截圖、錄影、Trace 檔案、網路和 console log |

## 相關指令

- `/plan` — 先規劃要測哪些流程
- `/tdd` — 單元測試用這個
- `/verify` — 統一驗證入口
