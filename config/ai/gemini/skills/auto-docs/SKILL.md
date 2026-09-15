---
name: auto-docs
description: "明確要求 session、handoff、lesson、changelog 或 durable summary 時，整理最小必要文件。"
when_to_use: "只有需要留下跨 session 或可重用紀錄時觸發；一般修改不觸發。"
tags: [docs, handoff, changelog, lessons]
effort: low
shell: optional
runtime-scope: shared-core
alwaysApply: false
---

# Auto Documentation Skill（自動文件歸檔）

## 核心規則

只有任務需要 durable context，或使用者明確要求記錄時，才寫 `.ai/`。
一次只寫與目前決策或交接直接相關的檔案；不掃描或補齊整套文件。

## 目錄結構

```text
.ai/                    # 工作記憶（gitignore）
  CURRENT.md            # 當前 session 狀態
  HANDOFF.md            # 跨 session 交接
  changelog.md          # 變更記錄（壓縮格式）
  lessons.md            # 經驗教訓（分類）
  sessions/             # 每日 session 摘要
    YYYY-MM-DD.md
  snapshots/            # mid-session checkpoint

docs/ai/                # 匯出層（手動 commit）
  lessons.md            # 從 .ai/ 匯出的精選
  sessions/             # 從 .ai/ 匯出的 session
```

## AI 文檔格式

### changelog.md (位於 .ai/)

```text
## YYYY-MM-DD
- {type}:{scope} | {path} | {一行描述}
```

type: feat/fix/refactor/docs/test/chore
每行 < 120 字元

### lessons.md (位於 .ai/)

```text
## {類別}
- {日期} | {教訓一行}
```

### sessions/YYYY-MM-DD.md (位於 .ai/)

```text
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

### CURRENT.md (位於 .ai/)

當前 session 的簡短狀態；只有跨 session 工作需要時才更新。

### HANDOFF.md (位於 .ai/)

跨 session 交接；只記錄下一次真正需要的 context。

## 匯出到 docs/ai/

需要將 .ai/ 的長期價值內容（lessons, session summary）保存到 git 時：

```bash
bash ~/.claude/scripts/ai-export.sh        # 匯出 lessons + 最近 session
bash ~/.claude/scripts/ai-export.sh --all   # 也匯出 changelog
```

匯出後需手動 `git add docs/ai/ && git commit`

## 反模式

- 不要把每個小操作都寫成 session record
- 不要寫長段落 -- 一行一條
- 不要重複寫同一條 -- 檢查最後幾行
- 不要把 .ai/ 的改動加入 git commit
