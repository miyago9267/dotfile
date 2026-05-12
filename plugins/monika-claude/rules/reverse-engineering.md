---
description: "逆向工程工作模式 -- 分析 minified/closed-source 程式碼時的方法論與產出規範。"
---

# 逆向工程工作規則

當任務涉及分析 minified、obfuscated、或 closed-source 程式碼時，適用以下規則。

## 觸發條件

- 使用者提到「逆向」「reverse」「decompile」「minified」「obfuscated」
- 分析 node_modules 或 vendor 目錄下的 .min.js / .mjs
- 研究 SDK 內部行為、未公開 API、或 undocumented behavior

## 方法論

### 階段 1：定位（Anchor）

1. 找到目標功能的**不可變字串常量**（error messages、log tags、header values）
2. 用 grep 從字串常量反向定位函數位置
3. 記錄「錨點字串 → minified 函數名」的對應表
4. 這些字串在版本升級後仍然存在，是跨版本追蹤的基礎

### 階段 2：追蹤（Trace）

1. 從錨點函數出發，追蹤呼叫鏈（caller/callee）
2. 識別關鍵資料結構（LRU cache、Map、Queue）
3. 用偽代碼 block 記錄邏輯，不貼原始 minified code
4. 標記：⚠️ 陷阱、📍 關鍵位置、✅ 已驗證

### 階段 3：驗證（Verify）

1. 設計 A/B 測試：有/無修改，量化差異
2. 收集真實數據（token counts、cache efficiency、response time）
3. 至少 3 組數據才能下結論
4. 數字必須具體，不用形容詞

### 階段 4：記錄（Document）

1. 使用 `/rev-doc` 產出結構化文檔
2. 主報告 + 錨點索引 + 工程筆記，互相 cross-reference
3. 每份文件帶 metadata header（日期、版本、前置研究）
4. 符號索引表：minified 名 → 功能描述

## Patch 工程規範

對 minified code 做 runtime patch 時：

1. **Find string 必須唯一** — 在目標文件中只出現一次
2. **Find string 不能是 Replace string 的子字串** — 否則 idempotency 失敗
3. **Idempotent** — 重複執行不改變結果（skip already patched）
4. **Syntax validation** — patch 後驗證 `node -c`
5. **Revert 機制** — 保留 .bak，支援 `--revert`
6. **錨點索引** — 記錄每個 patch 的 find 字串，版本升級後用來重新定位

## 產出檔案

| 類型 | 位置 | 命名 |
|------|------|------|
| 主報告 | `docs/leaarning/` 或 `docs/research/` | `{target}-reverse-engineering-v{ver}.md` |
| 錨點索引 | 同上 | `{target}-anchor-index-v{ver}.md` |
| 工程筆記 | 同上 | `{topic}-工程筆記.md` |
| Patch script | `scripts/` | `patch-{name}.sh` |
