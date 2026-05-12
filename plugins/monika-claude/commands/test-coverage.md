---
description: 分析並補足測試覆蓋率 -- 找出低覆蓋率的檔案，自動補齊測試到 80%+。
---

# /test-coverage

分析測試覆蓋率，補足不足的測試。

## 流程

1. 執行帶覆蓋率的測試
   - `npm test --coverage` / `pnpm test --coverage` / `go test ./... -cover`
2. 解析覆蓋率報告（`coverage/coverage-summary.json`）
3. 找出低於 80% 的檔案
4. 對每個覆蓋不足的檔案：
   - 分析未測試的程式碼路徑
   - 生成 unit test（函式層級）
   - 生成 integration test（API 層級）
   - 生成 E2E test（關鍵流程）
5. 驗證新測試通過
6. 回報前後覆蓋率比較

## 覆蓋率標準

| 類型 | 目標 |
| --- | --- |
| 一般程式碼 | 80%+ |
| 金融計算 | 100% |
| 認證邏輯 | 100% |
| 安全相關 | 100% |
| 核心商業邏輯 | 100% |

## 測試重點

- Happy path
- 錯誤處理
- Edge case（null、undefined、空值）
- 邊界條件
