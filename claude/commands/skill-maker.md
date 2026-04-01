---
name: skill-maker
description: "建立新 skill -- 引導式流程，內建品質檢查，確保 frontmatter 完整、description 可觸發、內容自足。"
---

# /skill-maker [name] [description]

引導建立符合品質標準的 skill。提供 name 和 description 可跳過互動步驟。

## 建立流程

### 1. 決定 scope

```text
這個 skill 的作用範圍？
  |- 所有專案都適用 -> 全域 skill（~/dotfile/claude/skills/<name>/SKILL.md）
  +- 只在特定專案用 -> 專案 skill（<project>/.claude/skills/<name>/SKILL.md）
```

### 2. 決定觸發類型

```text
這個 skill 什麼時候生效？
  |- 任何時候都要遵守（規則、規範）    -> alwaysApply: true
  |- 使用者打 /name 才啟動（工具、流程）-> user-invocable: true
  +- 特定條件自動觸發（情境感知）      -> alwaysApply: false
       -> description 必須寫清楚觸發條件
```

### 3. 撰寫 frontmatter

必填欄位，缺一不可：

```yaml
---
name: kebab-case-name          # routing 用，只能英文 + 連字號
description: "中文描述"         # 選單顯示文字，決定 Claude 何時觸發
alwaysApply: true/false        # 或 user-invocable: true（二擇一）
---
```

### 4. 撰寫 description

description 是 skill 最重要的欄位 -- Claude 靠它決定何時載入。

**格式：** `動詞開頭 + 做什麼 -- 補充說明何時/如何`

**好的 description：**

- `"規格與進度自動追蹤 -- 背景持續運作，自動判斷任務是否需要 spec。不需手動觸發；手動啟動完整 SDD 流程請用 /sdd。"`
- `"CI/CD 監控 -- 追蹤最新 pipeline 狀態，失敗時自動修復再 push。"`

**壞的 description：**

- `"效率紀律"` -- 太短，Claude 不知道何時觸發
- `"Test-Driven Development"` -- 只有名詞，沒說做什麼
- `"分析 minified/obfuscated/closed-source 程式碼時的方法論與產出規範。觸發：..."` -- 把觸發條件塞在 description 裡，應該放在 content 的觸發條件段落

**邊界釐清：** 如果有功能相近的 skill 存在，description 必須說明分工。例如：

- auto-spec: `"...不需手動觸發；手動啟動完整 SDD 流程請用 /sdd。"`
- sdd: `"...用 /sdd 明確進入 SDD 模式；日常 spec 追蹤由 auto-spec skill 自動處理。"`

### 5. 撰寫 content

**必要段落：**

- **目的** -- 一句話說明這個 skill 解決什麼問題
- **規則/流程** -- 具體的行為指引，用編號清單
- **範例** -- 至少一個具體使用情境或指令範例

**選填段落：**

- **觸發條件** -- `alwaysApply: false` 的 skill 必填
- **反模式** -- 常見錯誤，避免重蹈覆轍
- **與其他 skill 的關係** -- 有相近 skill 時說明互動方式

### 6. 品質檢查

建立完成後，逐項確認：

```text
[ ] frontmatter 三欄位都有（name, description, alwaysApply/user-invocable）
[ ] description 以動詞開頭，夠具體讓 Claude 判斷觸發時機
[ ] 有相近 skill 時，description 已釐清邊界
[ ] content 自足 -- 不引用可能不存在的外部檔案（如 AGENTS.md）
[ ] content 無 placeholder（不出現「規則一」「步驟一」等佔位文字）
[ ] 具體的指令/範例至少一個
[ ] 繁體中文為主，技術詞保留英文
[ ] 同名 skill 不存在於其他 plugin（避免雙載浪費 token）
```

### 7. 寫入檔案

全域 skill：

```bash
mkdir -p ~/dotfile/claude/skills/<name>
# 寫入 SKILL.md
```

專案 skill：

```bash
mkdir -p .claude/skills/<name>
# 寫入 SKILL.md
```

或用 script：

```bash
bash ~/.claude/scripts/skill-create.sh <name> "<description>" [--always-apply] [--project]
```

注意：script 產出的模板需要填充實際內容，不要留 placeholder。

## 反模式

| 問題 | 原因 | 正確做法 |
|------|------|----------|
| 只寫 description 沒寫 name | routing 失敗 | name 是必填 |
| alwaysApply 和 user-invocable 同時設 | 語意矛盾 | 二擇一 |
| content 寫「請參考 AGENTS.md」 | 外部檔案可能不存在 | 內容自足 |
| description 超過 120 字 | 選單顯示截斷 | 精簡，補充放 content |
| 跟現有 skill 重名 | plugin + local 雙載 | 建立前先 grep 確認 |
| trigger-based 但沒寫觸發條件 | Claude 不知何時載入 | description 或 content 明確列出 |
