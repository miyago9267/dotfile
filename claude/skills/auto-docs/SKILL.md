---
name: auto-docs
description: 自動文檔歸檔（全域版，模型無關）
alwaysApply: true
---

# Auto Documentation Skill

## 核心規則
每次完成操作後，自動記錄到 `docs/ai/` 目錄。
這是行為規則，不需要觸發——永遠生效。

## 目錄結構
```
docs/ai/
  changelog.md    # 變更記錄（壓縮格式）
  lessons.md      # 經驗教訓（分類）
  skills-index.md # Skill 索引
  sessions/       # 每日 session 摘要
    YYYY-MM-DD.md
```

## AI 文檔格式

### changelog.md
```
## YYYY-MM-DD
- {type}:{scope} | {path} | {一行描述}
```
type: feat/fix/refactor/docs/test/chore
每行 < 120 字元

### lessons.md
```
## {類別}
- {日期} | {教訓一行}
```

### sessions/YYYY-MM-DD.md
```
model: {model}
branch: {branch}
## done
- {完成項目}
## pending
- {待辦}
## decisions
- {決策}
## files_changed
- {path} | {描述}
```

### skills-index.md
```
{name} | {關鍵字} | {路徑}
```

## 人類文檔格式
同步更新 `PROGRESS.md`（如果存在）：
- 完整日期標題
- 完整句子描述
- 檔案路徑表格

## 自舉讀取順序
新 session 開始時按此順序讀取恢復 context：
1. `docs/ai/changelog.md`（最近 20 行）
2. `docs/ai/lessons.md`
3. `docs/ai/sessions/` 最新一筆
4. `PROGRESS.md`（如有）

## 反模式
- 不要只在 session 結束才寫——每個操作完成就寫
- 不要寫長段落——一行一條
- 不要跳過 changelog——這是跨 session 記憶的關鍵
- 不要重複寫同一條——檢查最後幾行
