---
name: repo-status
description: "當使用者詢問 GitHub/GitLab repo、PR/MR、pipeline/CI status，或剛完成需要確認的 remote action 時，取得 remote 狀態。"
when_to_use: "明確的 remote、PR/MR、pipeline/CI 查詢或 push 後驗證；local git work 不觸發。"
tags: [git, github, gitlab, ci, pr, mr]
effort: low
shell: required
runtime-scope: claude-native
alwaysApply: false
---

# Repo Status

只在 remote 狀態會影響目前 task 時執行。Local repo、branch、diff 或 commit 查詢直接用 Git，不啟動
platform detection。

- 先讀 remote URL，再選對應的 `gh`、`glab` 或 API。
- 只有需要 remote API 時才檢查 auth；auth failure 提醒一次，不重試、不阻塞 local work。
- 只回報目前 branch、PR/MR、pipeline/CI 的相關摘要；不要在每個 session start 自動查 remote。
- API 失敗回報原因，不把缺少 remote evidence 當成 local task 完成。

CLI 詳細參數只在實際 remote task 需要時讀 `CLI_REFERENCE.md`。
