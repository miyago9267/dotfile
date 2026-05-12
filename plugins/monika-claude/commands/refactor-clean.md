---
description: 安全清除 dead code -- 分析未使用的程式碼和依賴，在測試保護下安全刪除。
---

# /refactor-clean

識別並安全移除 dead code，每一步都由測試驗證。

## 分析工具

- `knip` — 找未使用的 export 和檔案
- `depcheck` — 找未使用的依賴
- `ts-prune` — 找未使用的 TypeScript export

## 流程

1. 執行分析工具，產出報告到 `.reports/dead-code-analysis.md`
2. 依嚴重度分類：
   - **SAFE**：測試檔、未使用的 util
   - **CAUTION**：API route、元件
   - **DANGER**：設定檔、主要進入點
3. 只提出 SAFE 等級的刪除建議
4. 每次刪除前：
   - 執行完整測試
   - 確認通過後才刪除
   - 重新執行測試
   - 測試失敗則回退
5. 回報清除摘要

**沒有測試通過不刪除任何程式碼。**
