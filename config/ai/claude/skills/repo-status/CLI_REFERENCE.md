---
name: repo-status-cli-ref
description: "gh/glab CLI 操作參考表 -- 觸發：需要查 gh 或 glab 指令時讀取。"
alwaysApply: false
---

# CLI 操作參考

根據偵測到的平台，使用對應的 CLI。以下是常用操作的快速對照。

## PR / MR

| 操作 | GitHub (`gh`) | GitLab (`glab`) |
|------|--------------|-----------------|
| 列出 | `gh pr list` | `glab mr list` |
| 查看 | `gh pr view <num>` | `glab mr view <num>` |
| 建立 | `gh pr create --title "T" --body "B"` | `glab mr create --title "T" --description "D"` |
| 查看 diff | `gh pr diff <num>` | `glab mr diff <num>` |
| 查看 review/comments | `gh pr view <num> --comments` | `glab mr note list <num>` |
| Merge | `gh pr merge <num>` | `glab mr merge <num>` |
| 審核通過 | `gh pr review <num> --approve` | `glab mr approve <num>` |
| 當前 branch 的 PR | `gh pr view` | `glab mr view` |

## CI/CD

| 操作 | GitHub (`gh`) | GitLab (`glab`) |
|------|--------------|-----------------|
| 列出最近 runs | `gh run list -L 5` | `glab ci list` |
| 查看特定 run | `gh run view <id>` | `glab ci view <id>` |
| 查看 run log | `gh run view <id> --log-failed` | `glab ci trace <id>` |
| 當前 branch 狀態 | `gh run list -b $(git branch --show-current) -L 1` | `glab ci get` |
| 重跑失敗 | `gh run rerun <id> --failed` | `glab ci retry <id>` |
| 等待完成 | `gh run watch <id>` | `glab ci trace <id>` (串流) |

## Issues

| 操作 | GitHub (`gh`) | GitLab (`glab`) |
|------|--------------|-----------------|
| 列出 | `gh issue list` | `glab issue list` |
| 查看 | `gh issue view <num>` | `glab issue view <num>` |
| 建立 | `gh issue create --title "T" --body "B"` | `glab issue create --title "T" --description "D"` |
| 留言 | `gh issue comment <num> --body "msg"` | `glab issue note <num> --message "msg"` |
| 關閉 | `gh issue close <num>` | `glab issue close <num>` |

## Repo

| 操作 | GitHub (`gh`) | GitLab (`glab`) |
|------|--------------|-----------------|
| 基本資訊 | `gh repo view` | `glab repo view` |
| 在瀏覽器打開 | `gh browse` | `glab repo view --web` |
| Clone | `gh repo clone owner/repo` | `glab repo clone owner/repo` |

## Release

| 操作 | GitHub (`gh`) | GitLab (`glab`) |
|------|--------------|-----------------|
| 列出 | `gh release list` | `glab release list` |
| 建立 | `gh release create v1.0 --notes "N"` | `glab release create v1.0 --notes "N"` |

## JSON 輸出（適合程式化處理）

GitHub 的 `gh` 支援 `--json` flag，可以直接 parse：

```bash
gh pr list --json number,title,state,headRefName
gh run list --json databaseId,status,conclusion,name -L 3
gh issue list --json number,title,labels,assignees
```

GitLab 的 `glab` 支援 `-F json` 或 `--output json`：

```bash
glab mr list -F json
glab ci list --output json
```

## 常見組合操作

**Push 後查看 CI：**

```bash
# GitHub
git push && gh run list -b $(git branch --show-current) -L 1
# GitLab
git push && glab ci get
```

**建 PR/MR 並追蹤 CI：**

```bash
# GitHub
gh pr create --fill && gh run watch
# GitLab
glab mr create --fill && glab ci trace
```
