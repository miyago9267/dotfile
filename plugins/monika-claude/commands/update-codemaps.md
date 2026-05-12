---
description: 更新架構地圖 -- 掃描程式結構，更新 codemaps/ 架構文件。
---

# /update-codemaps

分析 codebase 結構，更新架構文件。

## 流程

1. 掃描所有原始碼的 import、export、依賴
2. 生成精簡的架構地圖（`codemaps/` 目錄）：
   - `codemaps/architecture.md` — 整體架構
   - `codemaps/backend.md` — 後端結構
   - `codemaps/frontend.md` — 前端結構
   - `codemaps/data.md` — 資料模型和 schema
3. 計算與上一版本的差異百分比
4. 差異 > 30% 時，**要求使用者確認**再更新
5. 在每份文件加上更新時間戳
6. 儲存差異報告到 `.reports/codemap-diff.txt`

只記錄高層結構，不記錄實作細節。
