---
name: markdown-lint
description: Markdown 寫入時自動執行 markdownlint v0.40.0 規範。永遠生效。硬規則。
alwaysApply: true
---

# Markdown Lint — 硬規則，自動執行，不需提醒

基準：[markdownlint v0.40.0](https://github.com/DavidAnson/markdownlint/tree/v0.40.0/doc)

寫入或編輯任何 `.md` 前，在腦內過一遍以下所有規則並自動修正。
**不要詢問、不要提醒，直接修正後輸出。**

---

## 強制規則（無例外，直接修正）

### 結構與標題

| Rule | 說明 | 常見錯誤 |
|---|---|---|
| MD001 | Heading 層級只能逐級遞增（H1→H2→H3，不可跳） | `# Title` 後直接 `### Sub` |
| MD003 | Heading 統一用 ATX 風格（`#`），不用 Setext（底線） | `Title\n===` |
| MD018 | ATX heading 的 `#` 後必須有空格 | `##Title` |
| MD019 | ATX heading 的 `#` 後只能有一個空格 | `##  Title` |
| MD020 | Closed ATX heading 的 `#` 內側必須有空格 | `##Title##` |
| MD021 | Closed ATX heading 的 `#` 內側只能有一個空格 | `## Title  ##` |
| MD022 | Heading 前後各需一個空行 | heading 緊接在文字或 list 後 |
| MD023 | Heading 必須從行首開始（不可縮排） | 縮排的 `## Title` |
| MD025 | 整份文件只能有一個 H1（例外見下方） | 多個 `# Title` |
| MD026 | Heading 不得以標點結尾（`.` `!` `?` `:` 除外見下） | `## 結果：` |

### 清單

| Rule | 說明 |
|---|---|
| MD004 | 無序清單統一用 `-`，不混用 `*` 或 `+` |
| MD005 | 同層 list 縮排一致 |
| MD007 | 無序 list 縮排 2 格 |
| MD029 | 有序 list 統一用 `1.`（讓 renderer 自動編號）或逐一遞增，不混用 |
| MD030 | List marker 後只有一個空格 |
| MD032 | List 前後各需一個空行 |

### Code

| Rule | 說明 |
|---|---|
| MD031 | Fenced code block 前後各需一個空行 |
| MD040 | Fenced code block 必須指定語言（`bash`、`ts`、`text`、`yaml`…） |
| MD046 | Code block 統一用 fenced（``` ``` ```），不用縮排式 |
| MD048 | Fenced code block 統一用 backtick（`` ` ``），不用 `~` |

### 連結與圖片

| Rule | 說明 |
|---|---|
| MD011 | 不得使用反向連結語法 `(text)[url]`，應為 `[text](url)` |
| MD034 | 不得使用裸 URL，必須用 `<url>` 或 `[text](url)` |
| MD039 | Link text 內不得有前後空格 `[ text ]` |
| MD042 | 不得有空連結 `[text]()` |
| MD045 | 圖片必須有 alt text `![alt](url)` |

### 格式

| Rule | 說明 |
|---|---|
| MD009 | 不得有行尾空格（trailing spaces） |
| MD010 | 不得用 hard tab，統一用空格 |
| MD012 | 不得有連續超過一個空行 |
| MD027 | blockquote `>` 後只能有一個空格 |
| MD037 | emphasis marker 內不得有空格 `* text *` |
| MD038 | inline code 內不得有前後空格 `` ` text ` `` |
| MD047 | 檔案結尾必須有且只有一個換行 |
| MD055 | Table pipe 風格一致（建議每行都有 `\|` 頭尾） |
| MD056 | Table 每行欄數必須一致 |
| MD058 | Table 前後各需一個空行 |

---

## 條件規則（有明確例外情境）

### MD013 — 行長度

預設上限 80 字元。**以下情境豁免，不要強制換行：**

- Table 欄位（換行會破壞格式）
- Fenced code block 內
- URL / 長路徑（斷行沒意義）
- Frontmatter 欄位

正常段落文字超過 80 字元時，建議換行但**不強制**（技術文件優先可讀性）。

### MD024 — 重複 Heading 名稱

同一份文件不得有相同 heading 文字。**例外：**

- 跨不同層級的相同標題（`## 範例` 出現在不同 `###` 下）
- 刻意的對照結構（如 `### 正確` / `### 錯誤` 重複出現多次）

例外時加註解：`<!-- markdownlint-disable-next-line MD024 -->`

### MD033 — Inline HTML

預設禁止。**以下情境允許：**

- HTML 註解（`<!-- -->`）本身就是合法的
- Badge / shield 圖片確實需要 HTML
- markdownlint-disable 指令

### MD041 — 第一行必須是 H1

**YAML frontmatter 檔案強制豁免。** 有 `---` frontmatter 的檔案（SKILL.md、SPEC.md、AGENTS.md 含 frontmatter 者）在 frontmatter 結束後才算「第一行」。

處理方式：在 frontmatter 結束後的第一個非空行開始計算，**或**在 frontmatter 開始前加：

```markdown
<!-- markdownlint-disable-file MD041 -->
```

### MD026 — Heading 結尾標點

禁止 `.` `!` `?`，但**允許 `：`（全形冒號）**作為 heading 結尾，因為中文技術文件慣例。
禁止 `:`（半形冒號）結尾。

---

## 豁免規則（全域跳過，附理由）

| Rule | 豁免原因 |
|---|---|
| MD014 | 文件中 `$ command` 不一定要顯示輸出，只是示範格式 |
| MD028 | Blockquote 中的空行有時是刻意的段落分隔 |
| MD036 | 技術文件中用 `**粗體**` 當非正式 label 是可接受的 |
| MD043 | 必要 heading 結構是專案自定義的，全域無法統一 |
| MD044 | 專有名詞大小寫是專案自定義的，全域無法統一 |
| MD049 | emphasis 風格（`*` vs `_`）只要一份文件內一致即可，不跨文件強制 |
| MD050 | strong 風格（`**` vs `__`）同上 |
| MD051 | Link fragment 驗證在靜態 spec 中無法確保目標存在 |
| MD052 | 偏好 inline link，不強制 reference link |
| MD053 | 同上 |
| MD054 | 偏好 inline link 風格，不全域統一 |
| MD059 | 「點此」「here」等 link text 在中文文件中是可接受的 |
| MD060 | Table column 對齊是視覺輔助，不影響 parse，不強制 |

---

## Frontmatter 檔案的特殊處理

SKILL.md、SPEC.md、命令文件等含 YAML frontmatter（`---` 開頭）的檔案：

1. **MD041 自動豁免** — frontmatter 不是 Markdown heading，第一行規則不適用
2. **Frontmatter 內的 `---` 分隔符不計入 MD035**（HR style）
3. Frontmatter 欄位值若超長，豁免 MD013

建議在含 frontmatter 的 Markdown 檔案頂部（frontmatter 之前或之後）加：

```markdown
<!-- markdownlint-disable-file MD041 -->
```

---

## 快速修正對照

```markdown
<!-- 錯誤：MD022 + MD032 + MD031 + MD040 -->
## Title
- item
```

code

```

<!-- 正確 -->

## Title

- item

```bash
code
```

```

---

## 執行原則

- 寫入前修正，不要邊寫邊問
- 只修正觸及範圍，不大規模重寫未修改區塊
- 若整個檔案都需要修正，一次性修完再輸出
- 修正後不用特別告知「已修正 MD022」等，直接輸出正確版本
