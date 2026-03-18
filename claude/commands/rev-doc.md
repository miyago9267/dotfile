---
description: 逆向工程文檔產生器 -- 分析 minified/closed-source 程式碼，輸出結構化的技術調查報告。
---

# /rev-doc — 逆向工程技術文檔

根據目標程式碼或系統，產生結構化的逆向工程文檔。支援四種文檔類型。

## 使用方式

```text
/rev-doc <type> <target>
```

- `type`: report | anchor | notes | investigation
- `target`: 要分析的檔案路徑、套件名稱、或功能描述

## 文檔類型

### 1. `report` — 逆向工程報告（主報告）

最完整的格式。適合記錄一整個系統/模組的逆向結果。

結構：

```text
# {Target} Reverse Engineering v{version} — {Subtitle}

**調查日期：** YYYY-MM-DD ~ YYYY-MM-DD
**版本：** `package@version`（對應 {product} v{version}）
**前置研究：** `file1.md`, `file2.md`
**錨點索引：** `anchor-index.md`

---

## 一、問題陳述
  表格：場景 | 觀察 | 行為
  用數據說話，不用形容詞

## 二、完整流程全貌
  按階段拆解（A → B → C → D → E）
  每個階段：
    標題用 ### 階段 X：{名稱}
    偽代碼 block 展示流程
    ⚠️ 標記陷阱
    📍 標記關鍵位置
    ✅ 標記已解決項目

## 三、{問題根因分析}
  表格分類：高影響 | 中影響 | 低影響
  每項標明：觸發函數 | 變化原因 | 已解決？

## 四、{內部架構}
  ASCII 架構圖
  層級 cache/prefix match 等機制說明

## 五、{方案對比}
  表格：V1 vs V2 / 方案 A vs 方案 B
  優劣維度：工作量、風險、複用、維護成本

## 六、緩解方案
  ### Phase 1：Quick Wins（已實作）
  ### Phase 2：推薦路線
  ### Phase 3：未來展望

## 七、社群 Issues / 相關資源
  表格：Issue | 標題 | 相關性
  社群文章連結

## 八、符號索引
  表格：minified 名稱 | 功能描述

## 九、結論
  編號列表，每條一個 key finding
  粗體標註最重要的結論

## 十、實測數據（選填）
  A/B 測試表格
  欄位：場景 | metric1 | metric2 | efficiency | cost
  配對比結論

## 十一、實作清單
  表格：檔案 | 類型(新建/改) | 說明
  Patch 清單表格
```

### 2. `anchor` — 錨點索引（升級維護用）

minified code 的 grep 參考卡，版本升級後用來重新定位函數。

結構：

```text
# {Target} Minified Code 錨點索引 + Patch 指南（v{version}）

**用途：** 每次版本升級後，用不會變的字串常量重新定位被 minify 的關鍵函數。
**版本基線：** `package@version`
**更新日期：** YYYY-MM-DD
**主報告：** `report.md`

---

## 使用方式
  grep 範例（在目標檔案中定位函數）

## {file1} 錨點
  ### {功能區域}
  表格：功能 | 目前名稱 | 錨點字串 | 備註

## {file2} 錨點
  同上格式

## 目前 Patch 清單
  表格：# | id | 目標 | find → replace

### Patch 定位指南
  升級後的步驟說明
```

### 3. `notes` — 工程筆記（精簡版）

問題導向，快速記錄機制和解法。

結構：

```text
# {問題} — 工程筆記

> 逆向版本：`package@version`
> 完整調查報告見 `report.md`

---

## 問題
  bullet list，每項一行

## 核心機制
  ### {Component}
  偽代碼或表格展示邏輯
  表格：來源 | 條件 | 結果

## 為什麼 {root cause}
  流程步驟 + 註解

## 解法
  ### 原理
  ### 核心邏輯（TypeScript/code）
  ### 整合方式
  ### 副作用
```

### 4. `investigation` — 調查報告（社群調研）

大規模調研格式，彙整 GitHub issues、社群文章、多方案評估。

結構：

```text
# {Topic} 調查報告

**調查日期：** YYYY-MM-DD
**涵蓋來源：** GitHub Issues / 社群 / 原始碼
**結論：** 一句話

---

## 一、背景
## 二、GitHub Issues 彙整
  表格：Issue | 標題 | 狀態 | 關鍵資訊
## 三、原始碼分析
  decompiled/beautified 程式碼 + 行內註解
## 四、問題分類
## 五、方案評估
  每個方案：描述、優點、缺點、工作量
## 六、推薦方案
## 七、參考資料
```

## 寫作規則

### 語言

- 繁體中文（台灣），技術名詞保留英文
- 章節用中文數字：一、二、三...十一
- 行內程式碼用 backtick：`functionName()`

### 標記系統

```text
⚠️  陷阱、注意事項（code block 內行尾）
📍  關鍵位置、重要節點
✅  已解決、已驗證
←   行內標註（code block 內行尾）
→   流程箭頭
```

### 程式碼區塊

- minified code 用偽代碼 block 解釋，不貼原始 minified
- 行尾標註用 `← 說明` 或 `// 說明`
- 標記已解決的行用 `← ✅ sanitizer`
- 標記危險的行用 `← ⚠️ 可能不同`

### ASCII 架構圖

```text
┌──────────┐      ┌──────────────────┐
│ 元件 A    │      │  元件 B           │
│           │      │                  │
│ step 1   │      │  step 1          │
│   ↓      │      │  step 2          │
│ step 2 ──┼──→   │  step 3 ← ⚠️    │
│           │      │  step 4 ← ✅    │
└──────────┘      └──────────────────┘
```

### 數據表格

- 數字必須具體（不要「很多」，要「45,724 tokens」）
- 效率用百分比 + 粗體：**84%**
- 成本用 $USD
- A/B 測試至少 3 組數據

### Cross-reference

- 文件間用 `見 filename.md` 互相引用
- GitHub Issue 用 `[#1234](url)` 格式
- 函數名用 `code` + 說明：`Ml()` — cache_control 建構

## 流程

1. 確認目標和文檔類型
2. 閱讀/分析目標程式碼
3. 按照對應模板結構輸出
4. 數據填入實際數字（不要 placeholder）
5. 交叉驗證所有函數名和行號
6. 確認後存檔

## 存檔位置

- 專案內：`docs/leaarning/` 或 `docs/research/`
- 命名：`{target}-{type}-v{version}.md`
- 錨點索引和主報告放同目錄，互相引用
