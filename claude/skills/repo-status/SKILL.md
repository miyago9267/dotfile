---
name: repo-status
description: 主動偵測 Git remote 平台（GitHub/GitLab），檢查 repo 與 pipeline 狀態，缺少認證時提醒使用者。永遠生效。
alwaysApply: true
---

# repo-status -- Git Remote 感知與 CI/CD 狀態偵測

進入有 git remote 的專案時，主動偵測平台並檢查可用性。

## 觸發時機

- Session 開始時（bootstrap 後）
- `git push` 後
- 使用者問到 repo / PR / pipeline / CI 相關問題時

## 偵測流程

### 1. 判斷平台

```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
```

- 包含 `github.com` → GitHub
- 包含 `gitlab` → GitLab
- 其他 → 未知平台，跳過自動偵測，告知使用者

### 2. 驗證認證

**GitHub:**

```bash
gh auth status 2>&1
```

- 成功 → 繼續
- 失敗 → 告知使用者：「gh 未登入，執行 `! gh auth login` 或設定 `GH_TOKEN` 環境變數」

**GitLab:**

```bash
# 檢查有無 token
echo "$GITLAB_TOKEN$GITLAB_PRIVATE_TOKEN" | grep -q . && echo "ok" || echo "no-token"
```

- 有 token → 用 `curl` 呼叫 GitLab API
- 沒有 → 告知使用者：「需要設定 `GITLAB_TOKEN` 或 `GITLAB_PRIVATE_TOKEN` 環境變數」

### 3. 取得狀態

**GitHub（用 gh CLI）:**

```bash
# Repo 基本資訊
gh repo view --json name,defaultBranchRef,isPrivate,url 2>/dev/null

# 當前 branch 的 PR
gh pr list --head "$(git branch --show-current)" --json number,title,state,checks 2>/dev/null

# 最新 CI run
gh run list --branch "$(git branch --show-current)" --limit 3 --json databaseId,status,conclusion,name,headBranch 2>/dev/null
```

**GitLab（用 API）:**

```bash
# 從 remote URL 解析 project path
PROJECT_PATH=$(echo "$REMOTE_URL" | sed -E 's|.*gitlab\.[^/]+[:/]||;s|\.git$||')
ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's|/|%2F|g')
GITLAB_HOST=$(echo "$REMOTE_URL" | sed -E 's|.*@([^:/]+).*|\1|;s|https?://([^/]+).*|\1|')

# Pipeline 狀態
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://$GITLAB_HOST/api/v4/projects/$ENCODED_PATH/pipelines?ref=$(git branch --show-current)&per_page=3"

# MR 狀態
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://$GITLAB_HOST/api/v4/projects/$ENCODED_PATH/merge_requests?source_branch=$(git branch --show-current)&state=opened"
```

## 回報格式

偵測完畢後，用一行摘要回報：

```
[repo-status] GitHub miyago/project | branch: feat/xxx | CI: passed | PR: #42 (open, checks passing)
```

```
[repo-status] GitLab team/project | branch: main | Pipeline: #1234 failed (stage: test) | MR: !15 (open)
```

```
[repo-status] gh 未登入 -- 執行 `! gh auth login` 設定認證
```

## 規則

1. 認證失敗時**只提醒一次**，不要每次操作都重複提醒
2. 不要在沒有 git remote 的 repo 嘗試偵測
3. API 呼叫失敗（網路、權限）時簡短回報原因，不要 retry
4. GitLab self-hosted 的 host 從 remote URL 自動解析，不要硬編碼
5. 偵測是**非阻塞**的 -- 失敗不影響其他工作
