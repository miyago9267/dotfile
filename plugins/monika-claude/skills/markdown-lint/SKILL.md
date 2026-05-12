---
name: markdown-lint
description: Markdown 寫入時自動套用 markdownlint 規範。永遠生效。硬規則。
alwaysApply: true
---

# Markdown Lint -- 硬規則

基準：markdownlint v0.40.0。寫入或編輯 `.md` 前自動修正，不詢問、不提醒。

## 客製偏好（與預設不同）

| 項目 | 設定 |
| --- | --- |
| 無序清單 | 統一 `-`，縮排 2 格 |
| Code block | 一律 fenced backtick，必須指定語言 |
| Heading 結尾 | 允許全形 `：`，禁止半形 `:` |
| 行長度 MD013 | 預設 80，但 table / code block / URL / frontmatter 豁免 |
| MD024 重複標題 | 跨層級或刻意對照允許，加 `<!-- markdownlint-disable-next-line MD024 -->` |
| Inline HTML MD033 | 預設禁止，HTML 註解和 badge 允許 |
| MD041 第一行 H1 | YAML frontmatter 檔案自動豁免 |

## 全域豁免規則

MD014, MD028, MD036, MD043, MD044, MD049, MD050, MD051, MD052, MD053, MD054, MD059, MD060

理由：專案自定義或不影響 parse 的風格偏好，不跨文件強制。

## 常犯錯誤提醒

- Heading / list / code block / table 前後各需一個空行（MD022, MD031, MD032, MD058）
- 不要連續空行（MD012）
- 檔案結尾必須有且只有一個換行（MD047）
- Heading 層級逐級遞增，不可跳（MD001）
- 不得有行尾空格（MD009）

## 執行原則

- 寫入前修正，不要邊寫邊問
- 只修正觸及範圍，不大規模重寫未修改區塊
- 修正後不用特別告知「已修正 MDxxx」，直接輸出正確版本
