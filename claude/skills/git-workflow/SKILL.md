---
name: git-workflow
description: Git 操作安全規範與 commit 格式統一。永遠生效。
alwaysApply: true
---

# Git 工作流規範

## Commit Message 格式

```text
<type>(<scope>): <簡短描述>

[可選] 詳細說明
```

### Type 列表

| Type | 用途 |
| --- | --- |
| `feat` | 新功能 |
| `fix` | 修 bug |
| `refactor` | 重構（不改功能、不修 bug） |
| `docs` | 文件變更 |
| `test` | 測試相關 |
| `chore` | 建置流程、工具變更 |
| `style` | 格式調整（不影響邏輯） |
| `perf` | 效能優化 |
| `ci` | CI/CD 設定 |

### Scope 建議

用受影響的模組或功能名稱，例如 `auth`、`api`、`ui`、`db`。

## 安全操作規則

- **禁止** `git push --force` 到 `main`/`master`/`develop` 分支
- **禁止** `git reset --hard` 在有未 commit 修改時直接執行
- `git add` 必須指定明確路徑，禁止 `git add .` 或 `git add -A`
- commit 前先 `git diff --staged` 確認內容
- 大量修改分多次 commit，每次 commit 有明確主題
- **commit 後禁止再修改或新增檔案**，所有文件更新必須在 commit 前完成
- **`.ai/` 不納入版控**，若 repo 尚未排除，主動加入 `.gitignore`

## Branch 命名

```text
feat/<slug>      -- 新功能
fix/<slug>       -- 修 bug
refactor/<slug>  -- 重構
docs/<slug>      -- 文件
chore/<slug>     -- 雜務
```

## 常用操作

- 查看歷史：`git log --oneline -20`
- 暫存修改：`git stash push -m "描述"`
- 建立分支：`git checkout -b feat/<name>`
- 互動式 rebase：`git rebase -i HEAD~N`
