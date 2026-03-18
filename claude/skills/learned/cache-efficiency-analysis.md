# Prompt Cache Efficiency Analysis — A/B 測試方法論

**提取時間：** 2026-03-18
**來源專案：** Lovely Office SDK reverse engineering
**適用場景：** 分析 Anthropic API prompt caching 行為，優化 token 消耗

## 問題

Claude API 的 prompt caching 是 prefix-match 機制：request body 從第一個 byte 開始，
與 server-side cache 做 prefix match。任何 byte 不同就從該位置起全部 cache MISS。

在 Agent SDK 場景，每次 query() spawn 新 process → runtime 注入內容略有差異
→ prefix 不匹配 → 整個 conversation context 都 cache WRITE（125% 費用）。

## 分析方法

### 1. 計算 cache efficiency

```text
efficiency = cacheReadInputTokens / (inputTokens + cacheReadTokens + cacheCreationTokens)

> 80% = 良好 cache hit
50-80% = 部分 cache hit
< 50% = cache bust 嚴重
```

### 2. A/B 測試設計

- 同一 session，連續發送短訊息（"555"）
- 控制變因：一次只改一個設定
- 至少 5 組數據
- 記錄：cacheRead、cacheCreation、inputTokens、total cost
- 間隔 11-90 秒測試 cache TTL 效果

### 3. Cache bust 源分類

| 影響程度 | 類型 | 緩解方式 |
|----------|------|----------|
| 高 | 跨 process 的 runtime 注入（gitStatus、readFileState diff） | persistent session（不換 process） |
| 中 | 記憶檔案 mtime 變化、task 列表變化 | 減少更新頻率 |
| 低 | currentDate（一天變一次） | 忽略 |

### 4. 關鍵洞見

- system prompt（~15k）永遠被 cache（跨 session 的 global scope）
- messages（~45k+）才是 cache bust 的主戰場
- **消除個別 bust 源無效** — 根因是不同 process 的 runtime 注入無法 byte-for-byte 相同
- **persistent session 是唯一真正解法** — 同一 process 內 runtime 注入穩定

## 觸發條件

- 分析 Claude API token 消耗異常
- 優化 Agent SDK 的成本
- 設計 session 管理策略（resume vs persistent vs fresh）
