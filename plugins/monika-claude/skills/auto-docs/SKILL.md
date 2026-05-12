---
name: auto-docs
description: 自動文檔歸檔（全域版，模型無關）
alwaysApply: true
---

# Auto Documentation Skill

## 核心規則

每次完成操作後，自動記錄到 `.ai/` 目錄。
這是行為規則，不需要觸發 -- 永遠生效。

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

當前 session 正在做的事，收工時合併到 HANDOFF.md

### HANDOFF.md (位於 .ai/)

跨 session 交接，bootstrap.sh 讀取恢復 context

## 匯出到 docs/ai/

需要將 .ai/ 的長期價值內容（lessons, session summary）保存到 git 時：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ai-export.sh        # 匯出 lessons + 最近 session
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ai-export.sh --all   # 也匯出 changelog
```

匯出後需手動 `git add docs/ai/ && git commit`

## 自舉讀取順序

新 session 開始時按此順序讀取恢復 context：

1. `.ai/HANDOFF.md`（跨 session 交接）
2. `.ai/changelog.md`（最近 20 行）
3. `.ai/lessons.md`
4. `.ai/sessions/` 最新一筆
5. `docs/specs/` active specs

## 反模式

- 不要只在 session 結束才寫 -- 每個操作完成就寫
- 不要寫長段落 -- 一行一條
- 不要跳過 changelog -- 這是跨 session 記憶的關鍵
- 不要重複寫同一條 -- 檢查最後幾行
- 不要把 .ai/ 的改動加入 git commit
