---
name: issue-ops
description: "管理 Issue 到 PR 的全流程 -- 觸發：issue、PR、MR、要做什麼、找 bug、開 PR、review 回了什麼、CI 過了沒。任意階段進入，進入後往下接。平台偵測依賴 repo-status，CI 深入分析切 cicd-watch。"
alwaysApply: false
---

# Issue-to-PR 全流程

任意階段可當進入點，**每個進入點先過 Stage 0 認證 + 前置檢查**。

```text
任意進入 -> Stage 0 (認證) -> 前置檢查 -> 目標 Stage -> 往下接
                                            |
終結：Stage 4 PR merged/closed -> 是 incident? -> /post-mortem
```

## Stage 0. 認證閘門（每次進入必跑一次）

```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
```

**GitHub：** `gh auth status 2>&1`
- OK -> `PLATFORM=github`
- FAIL -> 告知「gh 未登入，執行 `! gh auth login`」+ 保留 `PLATFORM=github, REPO={from remote}`，**停止**

**GitLab：** `echo "${GITLAB_TOKEN}${GITLAB_PRIVATE_TOKEN}" | grep -q .`
- OK -> `PLATFORM=gitlab`
- FAIL -> 告知「需要設定 GITLAB_TOKEN」+ 保留 `PLATFORM=gitlab`，**停止**

**無 remote：** 使用者指定 repo 或詢問。

## 前置狀態檢查

| 進入 Stage | 需要 | 缺了怎麼辦 |
|-----------|------|-----------|
| 1. Discovery | `PLATFORM` + `REPO` | 跑 Stage 0 |
| 2. Setup | `REPO` | 跑 Stage 0。`ISSUE` 可選 |
| 3. Submit | `BRANCH`（非 main）+ 有 commit | 提醒「還沒開 branch」或「沒有新 commit」 |
| 4. Track | `PR_URL` 或 `BRANCH`（能查到 PR） | 提醒「還沒開 PR，要先開嗎？」 |
| 5. Related | `REPO` | 跑 Stage 0 |

```bash
CURRENT=$(git branch --show-current)
[[ "$CURRENT" =~ ^(main|master)$ ]] && echo "ON_DEFAULT" || echo "BRANCH=$CURRENT"
git log origin/main..HEAD --oneline | head -5
gh pr list --head $CURRENT --json number,url --jq '.[0]' 2>/dev/null
```

## Stage 1. Discovery -> 輸出 `ISSUE` + `REPO`

```bash
# GitHub
gh issue list --repo $REPO --state open --limit 20
# GitLab
glab issue list --per-page 20
```

**判定：**
- 找到目標 -> `ISSUE={number}`，進 Stage 2
- 使用者已知 issue number -> 直接設定，跳 Stage 2
- Issue 是 production 問題 -> 切 `health-check`（帶 service name -> health-check Step 1）
- 沒有 open issue -> 回報「無待處理 issue」

## Stage 2. Setup -> 輸出 `BRANCH`

### 2a. 確認 fork 狀態

```bash
gh repo view $REPO --json viewerPermission --jq '.viewerPermission'
```

- `WRITE`/`ADMIN` -> 直接開 branch
- `READ` -> `gh repo fork $REPO --clone=false` + `git remote add upstream`

### 2b. 建立 branch

```bash
git checkout -b fix/$ISSUE-{short-desc}
```

**判定：**
- OK -> `BRANCH={name}`，進開發流程（SDD/TDD）
- FAIL branch 已存在 -> `git checkout fix/$ISSUE-{desc}`（切過去繼續）
- FAIL dirty working tree -> 建議 `git stash`

## Stage 3. Submit -> 輸出 `PR_URL`

```bash
# GitHub
gh pr create --repo $REPO --head $BRANCH --title "fix: {描述}" --body "Closes #$ISSUE"
# GitLab
glab mr create --title "fix: {描述}" --description "Closes #$ISSUE" --source-branch $BRANCH
```

**判定：**
- 成功 -> `PR_URL={url}`，**主動進 Stage 4**（不等使用者問）
- push 被拒 -> `git pull --rebase origin main`（帶 `BRANCH` + `REPO` 重試）

## Stage 4. Track -> 輸出 `STATUS`

Stage 3 完成後**主動執行一次**。

### 4a. CI/CD

```bash
# GitHub
gh pr checks $PR_URL
gh run list --branch $BRANCH --limit 3 --json databaseId,status,conclusion,name
# GitLab
glab ci get
```

**判定：**
- passed -> 回報摘要
- failed -> 切 `cicd-watch`（帶 `BRANCH` + run ID -> cicd-watch 從 Step 1 進入）
- cicd-watch 3 輪修不好 -> 切 `log-analysis`（帶 `BRANCH` + run ID + failed job -> log-analysis Step 2，TIME_RANGE = CI run 時間）
- pending -> 回報等待中

### 4b. Review

```bash
# GitHub
gh pr view $PR_URL --comments
gh api repos/$REPO/pulls/{pr-number}/reviews --jq '.[].state'
# GitLab
glab mr view $MR_ID --comments
```

**判定：**
- `APPROVED` -> 回報可 merge
- `CHANGES_REQUESTED` -> 列出具體要求，帶回開發流程修改
- 無 review -> 回報等待中

### 4c. 終結判定

```bash
gh pr view $PR_URL --json state --jq '.state'
```

- `MERGED` / `CLOSED` -> **全流程結束**。若此 issue 是 production incident -> 建議 `/post-mortem`（帶 `ISSUE` + 修復 timeline）
- `OPEN` -> 使用者之後再問時重跑 4a + 4b

## Stage 5. Related（使用者指定時才跑）

```bash
git submodule status
cat package.json | jq '.dependencies, .devDependencies' 2>/dev/null
cat go.mod 2>/dev/null | grep -v "^//"
```

**判定：**
- 有關聯 repo -> 列出，使用者要查特定 repo 時用該 repo 重跑 Stage 1
- 無關聯 -> 告知「無外部依賴」

## 與其他 skill 的銜接

- `repo-status`：Stage 0 的平台偵測邏輯與 repo-status 一致（repo-status 是 alwaysApply，通常已跑過）
- `cicd-watch`：Stage 4a CI 失敗 -> 帶 `BRANCH` + run ID -> cicd-watch Step 1
- `health-check`：Stage 1 發現 production issue -> 帶 service name -> health-check Step 1
- `log-analysis`：cicd-watch 修不好 -> 帶 `BRANCH` + run ID + failed job -> log-analysis Step 2（TIME_RANGE = CI run 時間）
- `post-mortem`：Stage 4c PR merged + 是 incident -> 帶 `ISSUE` + timeline -> /post-mortem

## 規則

1. 每個 Stage 都是合法進入點，進入後往下接
2. Stage 3 -> Stage 4 是**主動**的
3. 不要在沒確認 fork/權限的情況下直接 push
4. PR/MR body 必須連結 issue（`Closes #N`）
5. GitHub 用 `gh`，GitLab 用 `glab`
