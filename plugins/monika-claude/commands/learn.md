---
description: 提取可重用模式 -- 分析當前 session，將值得保留的解法存成 skill。
---

# /learn

分析當前 session，提取值得重用的模式並存為 skill 檔案。

## 適合提取的內容

1. **錯誤解法模式** — 根因是什麼、怎麼修的、下次能套用嗎
2. **除錯技巧** — 非顯而易見的排查步驟、工具組合
3. **Workaround** — 套件 quirk、API 限制、版本特定修法
4. **專案特定模式** — 發現的慣例、架構決策、整合模式

## 輸出格式

存到專案的 `.ai/learned/<pattern-name>.md`：

```markdown
# <描述性模式名稱>

**提取時間：** YYYY-MM-DD
**適用場景：** 說明什麼情況會用到這個

## 問題
<具體描述解決了什麼問題>

## 解法
<模式/技巧/workaround 的具體內容>

## 範例
<程式碼範例（如適用）>

## 觸發條件
<什麼情況應該套用這個 skill>
```

## 流程

1. 回顧 session 找出可提取的模式
2. 找出最有價值/最常重用的洞見
3. 草擬 skill 檔
4. 確認後再儲存

不提取：typo 修正、單次性問題（API 中斷等）、顯而易見的修法。

## Instinct 模式

除了完整的 skill 檔案，也可以提取更小粒度的「instinct」-- 一個 trigger 對應一個 action。

### Instinct 格式

存到 `.ai/learned/<instinct-name>.md`：

```markdown
---
id: <kebab-case 名稱>
trigger: "<什麼情況觸發>"
confidence: <0.3-0.9>
domain: "<分類>"
source: "<觀察來源>"
---

# <描述性名稱>

## Action

<具體的行為指引，一句話>

## Evidence

- <觀察 1：什麼時候發現的、怎麼發現的>
- <觀察 2>
```

### 屬性說明

- **Atomic** -- 一個 trigger + 一個 action，不要塞多個行為
- **Confidence** -- 0.3 = 初步觀察，0.5 = 多次觀察，0.7 = 強烈建議，0.9 = 幾乎確定
- **Domain** -- code-style / testing / git / debugging / workflow / performance / security
- **Source** -- session-observation / user-correction / error-resolution

### Confidence 調整規則

- 重複觀察到相同模式 -> +0.1
- 使用者未糾正建議的行為 -> +0.05
- 使用者明確糾正 -> -0.2
- 長期未觀察到 -> -0.1

### 什麼時候用 instinct vs skill

| 情境 | 用 instinct | 用 skill |
| --- | --- | --- |
| 單一行為偏好 | v | |
| 多步驟流程 | | v |
| 初次觀察（confidence < 0.5） | v | |
| 多次驗證的成熟模式 | | v |
| 跨 domain 的整合模式 | | v |

### 範例

```markdown
---
id: prefer-functional-style
trigger: "when writing new utility functions"
confidence: 0.7
domain: "code-style"
source: "session-observation"
---

# Prefer Functional Style

## Action

Use functional patterns (pure functions, composition) over classes for utility code.

## Evidence

- 2025-01-15: User corrected class-based utility to functional approach
- 2025-01-20: Same preference observed in 3 different PRs
```
