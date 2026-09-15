---
name: search-discipline
description: "需要搜尋 codebase 或 logs 時，限制輸出並優先使用精確的 grep、glob、read。"
when_to_use: "只在 research、diagnostics 或可能拉入大量 context 的搜尋前觸發。"
tags: [search, grep, glob, context, tokens]
effort: low
shell: optional
runtime-scope: gemini-native
alwaysApply: false
---

# search-discipline -- 搜索效率紀律

控管搜索行為的 token 消耗與回合數。`codebase_investigator` 是重量級的架構分析工具，
大多數日常搜尋任務應優先使用精確、快速的工具組合。

## 搜索工具選擇順序

```text
搜索需求
  ├─ 知道檔名或路徑 Pattern → glob (1 call, 並行)
  ├─ 知道關鍵字或符號 → grep_search (1 call) + 善用 context/before/after 參數
  ├─ 探索目錄結構 → list_directory
  ├─ 批次處理/跨多檔重複修改 → generalist (委派子代理，主歷史只留摘要)
  └─ 複雜架構分析、Root Cause 追查、模糊需求 → codebase_investigator (最後手段)
```

## 規則

1. **grep_search 優先**：找關鍵字、函數、class 名、import 路徑。利用 `context`、
   `before`、`after` 參數一次取得足夠資訊，減少後續 `read_file` 的依賴。必須指定
   `include_pattern`（例如 `*.ts`）或 `dir_path`。
2. **glob 優先**：尋找特定副檔名或路徑結構（`**/*.ts`、`src/**/index.*`）。
3. **read_file 外科手術**：已知路徑時，強制使用 `start_line` 和 `end_line` 讀取特定片段，嚴禁無差別載入完整大檔案。
4. **平行化搜索**：不相依的搜尋可在同一回合平行呼叫；避免為了形式拆回合。
5. **限制 generalist 與 codebase_investigator**：這兩個工具會啟動獨立的 session
   進行運算，雖然能保護主 session 的 context，但本身執行成本較高。只在單純工具
   無法勝任時才使用。

## 反模式與正確做法

| 錯誤行為 | 正確做法 |
|----------|----------|
| 用 codebase_investigator 找已知路徑的 code | 直接 glob 配合 read_file |
| 讀取完整大型檔案 (>200行) | 先 grep_search 定位，再 read_file 區間 |
| 不帶 include_pattern 的 grep | 明確指定 include_pattern 減少雜訊 |
| 循序發出多個獨立的 search/read 請求 | 在同一個 Turn 並行發出所有不相依的工具請求 |
