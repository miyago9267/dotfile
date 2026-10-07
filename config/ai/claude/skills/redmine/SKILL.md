---
name: redmine
description: "Redmine 開單、補單，並與 GitLab issue、MR、release 互貼連結；觸發詞：開單、補單、工單、填工時、發 tag、release 掛哪張單。issue 到 MR 的開發流程走 issue-ops。"
alwaysApply: false
when_to_use: "要在 Redmine 開單或補單、把工單與 GitLab issue/MR 互連，或發 tag release 前後要同步兩邊連結時。"
tags: [redmine, ticket, gitlab, release, tag, 工單]
effort: medium
shell: required
runtime-scope: claude-native
---

# Redmine 工單與 GitLab 互連

目的：一句話就能在 Redmine 開單或補單，並讓工單、GitLab issue、MR、release 四邊都找得到彼此。

## 觸發條件

- Miyago 說開單、補單、工單、填工時，或給了一個 Redmine 單號要更新
- 做完一段要留紀錄的操作（infra 變更、hotfix、上線），他要求留工單
- 準備發 tag / release，要決定掛哪張單、release 說明寫什麼

不觸發：只有 GitLab issue 到 MR 的開發流程走 `issue-ops`；只追 pipeline 走 `cicd-watch`。

## 工具

- `rdm <GET|POST|PUT> <path>`：Redmine REST API。body 從 stdin 給，HTTP 狀態印在 stderr（`http=NNN`），非 2xx 以非零結束。
- `glab`：GitLab 端的 issue、MR、release。
- `reference.md`：專案與 tracker 對照、欄位 id、預設值、payload 與指令範例。組 payload 或下 `glab` 指令前讀它。

## 變數

- `MR_URLS`、`ISSUE_URLS`：要掛的 GitLab MR 與 issue 網址
- `DRAFTS`：待開的工單草稿，每張帶自己的 `MR_URLS`、`ISSUE_URLS`
- `TICKETS`：工單對照表，每列是一個單號加它對應的 `MR_URLS`、`ISSUE_URLS`。後面每一步都以它為準
- `MAIN_TICKET`、`TAG`、`RELEASE_NOTES`、`RELEASE_URL`：release 用

## 入口

| 情境 | 從哪一步開始 | 需要 |
|------|-------------|------|
| 開單、補單 | Step 1 | 無 |
| 已有單，要結單、加 note、填工時 | Step 2 | 單號（先放進 `TICKETS`） |
| 已有單，只要補兩邊連結 | Step 3 | 單號 + `MR_URLS` 或 `ISSUE_URLS`（先放進 `TICKETS`） |
| 要發新的 tag / release | Step 4 | 目標 repo |
| tag 已存在，只缺 release 與連結 | Step 4 | 目標 repo + `TAG` |

## 流程

### Step 1. 收集內容 -> 輸出 `DRAFTS`、`TICKETS`

1. 內容來源依序：Miyago 明講的、本 session 做過的事、`glab mr view` / `glab issue view` / `git log`。
2. `ISSUE_URLS` 來自 Miyago 指定的 issue，加上每個 MR 關掉的 issue（`reference.md` 的「找工單與 issue」）。沒有 issue 就只掛 MR，不為了掛單去開 issue。
3. 分組：一個 MR 一張單；處理同一個 GitLab issue 的多個 MR 併成一張。Miyago 指定分法就照他的。
4. 每個 MR 先查有沒有現成的單（`reference.md` 的「找工單與 issue」）：用 MR 連結查 `Gitlab` 欄位，再用關鍵字查主旨（同事手動開的單常常沒填欄位）。查到的直接記進 `TICKETS`。
5. 還沒有單的各組一份草稿放進 `DRAFTS`，欄位與預設值照 `reference.md` 的「預設值」，專案照「專案對應」。MR 還沒 merged 用「事前開單」那一欄。

判定：
- `DRAFTS` 有草稿 -> 帶 `DRAFTS`、`TICKETS` 進 Step 2
- `DRAFTS` 是空的（全部都有單）-> 帶 `TICKETS` 進 Step 3
- 專案或主旨推不出來 -> 問 Miyago 一次，補齊後進 Step 2

### Step 2. 寫入 Redmine -> 輸出 `TICKETS`

送出前的確認：
- Miyago 明講要開的那一張，內容是他給的 -> 直接送
- 一次多張，或內容是我從 session、git 推出來的 -> 先把 `DRAFTS` 列成一張表，他同意一次後全部送出

新單：`jq -n` 組 payload，`rdm POST /issues.json`，已知的 GitLab 連結直接放進 `Gitlab` 欄位與內文。從回應讀單號與實際狀態，記進 `TICKETS`。
既有單：先 `rdm GET` 看現值，再 `rdm PUT` 只送要改的欄位。
有給實際時數才 `rdm POST /time_entries.json`；沒給就只填預估工時。

判定：
- `http=201`（新單）或 `http=204`（更新）-> 回報 `https://redmine.dunqian.tw/issues/{id}`。`TICKETS` 裡有 GitLab 連結就進 Step 3，沒有就結束
- `http=201` 但回應的狀態和送出的不同 -> 單已建立，workflow 不允許直接設成那個狀態；回報實際狀態後照上一條繼續
- `http=422` -> 讀 `errors`，修欄位後重送一次，同一批其餘草稿套用同樣的修正。仍失敗的那張跳過；已建好的照樣進 Step 3，最後回報缺哪幾張
- `http=401` / `http=403` -> 停，回報 key 或權限問題，不重試
- 其他狀態碼或 timeout -> 停。POST 逾時要先用主旨查重，確認沒建成才重送

### Step 3. 兩邊互貼連結 -> 輸出 `LINKED`

對 `TICKETS` 的每一列各做一次。

Redmine 端（`rdm PUT`）：
- `Gitlab` 欄位填該列最主要的 MR 連結，沒有 MR 就填 issue 連結。欄位已有別的值就不覆寫
- 加一則 note 列出該列全部的 GitLab issue 與 MR 連結；工單內文、欄位或既有 note 已出現過的不重貼

GitLab 端（該列的每個 issue、每個 MR）：
- description 最後加一行 `Redmine: https://redmine.dunqian.tw/issues/{單號}`；已有就跳過
- Miyago 自己開、還沒有人討論的，直接改 description；別人開的或已有討論的，改用留言

驗證：`rdm GET "/issues/{單號}.json?include=journals"` 讀得到每個 GitLab 連結；`glab mr view --comments` / `glab issue view --comments` 讀得到 Redmine 連結。

判定：
- 每一列兩邊都讀得到對方 -> `LINKED=yes`。從 Step 4 過來的就帶 `TICKETS` 回 Step 4 第 4 點；否則結束，回報工單與各連結
- `Gitlab` 欄位寫完讀回是空的 -> 該 tracker 沒有這個欄位（`其他`），連結留在 note，仍算連上
- 有對象寫不進去 -> `LINKED=no`，回報是哪一個與錯誤訊息，不宣告完成；從 Step 4 過來的也停在這裡，不發 release
- 從 Step 4 過來，而 Step 2 有草稿建不成 -> 已建好的照樣連完，然後停在這裡回報缺哪幾張，不回 Step 4、不發 release

### Step 4. Release 準備 -> 輸出 `MAIN_TICKET`、`TAG`、`RELEASE_NOTES`

1. 讀該 repo 的慣例：最近 5 個 tag 與 release。ITRD 的 repo 是 tag 名等於 Redmine 單號，同一張單再發用 `{單號}-N`，release 名稱等於工單主旨。慣例不同的 repo 照它自己的。
2. 定範圍：入口給了既有的 `TAG`，範圍是它的前一個 tag 到它；要發新 tag，範圍是最新的 tag 到 default branch。
3. 列出範圍內 merged 的 MR 與它們關掉的 issue（`reference.md` 的「Release 範圍」）。
4. 幫每個 MR 找工單：先看 `TICKETS`，再查 `Gitlab` 欄位、MR 的 description 與留言。找到的補進 `TICKETS`。

第 4 點之後先判定：
- 範圍內沒有任何 MR -> 停，回報「這個範圍沒有合併」
- 有 MR 沒有單 -> 帶那些 `MR_URLS` 與現有的 `TICKETS` 回 Step 1 補單；補完從第 4 點接著做
- 每個 MR 都有單 -> 繼續第 5 點

5. 定 `MAIN_TICKET`：`TICKETS` 只有一張就是它；多張就問 Miyago 哪一張當主單。
6. 定 `TAG`：入口已給就沿用。要發新 tag 就用 `MAIN_TICKET` 的單號，同名 tag 已存在就取下一個 `-N`。
7. 組 `RELEASE_NOTES`（`reference.md` 的「Release notes」）：主單主旨、`TICKETS` 每張單的連結、issue 與 MR 清單。

判定：
- `MAIN_TICKET`、`TAG`、`RELEASE_NOTES` 都有 -> 進 Step 5

### Step 5. 發 release -> 輸出 `RELEASE_URL`

先查 `TAG` 在 remote 存不存在（`reference.md` 的「發 release」）。

- 不存在，要建新 tag：推 tag 可能直接觸發 production build 與 deploy，先讀該 repo `.gitlab-ci.yml` 的 tag 規則。把 `TAG`、目標 commit、內含的 MR、會觸發的 pipeline 列給 Miyago，取得這一次的明確同意才執行，指令一定帶 `--ref {sha}`。開單或補單的授權不算
- 已存在，只缺 release 或要補說明：指令不帶 `--ref`。這不會推新 tag、不觸發 pipeline，Miyago 要求同步時直接做

判定：
- 成功 -> `RELEASE_URL={url}`，進 Step 6。建了新 tag 就取該 tag 的 pipeline id（剛建好可能還沒出現，稍後再取一次），交給 `cicd-watch` 當 run-id，並交代只追蹤與回報、失敗不自動修復
- 入口說 tag 已存在，查出來卻不存在 -> 停，回報，不建 tag
- Miyago 沒有同意建 tag -> 停，回報 `TAG` 與 `RELEASE_NOTES` 草稿
- 指令失敗 -> 停，回報錯誤原文，不重推 tag

### Step 6. 回寫工單 -> 輸出 `SYNCED`

對 `TICKETS` 的每一張 `rdm PUT`：
- note 寫 `RELEASE_URL` 與 `TAG`；已貼過的不重貼
- Miyago 自己的單（作者或被指派人是他）且還沒結 -> 狀態改 `已完成`、完成度 100
- 別人的單只加 note，不動狀態

驗證：每張單的 journals 讀得到 `RELEASE_URL`；`glab release view "$TAG"` 讀得到每張單的連結。

判定：
- 兩邊都對得上 -> `SYNCED=yes`，結束，回報 release 與工單連結
- 有缺 -> `SYNCED=no`，回報缺哪一張、哪一邊，不宣告完成

## 與其他 skill 的銜接

- `issue-ops`：`PLATFORM` 是 GitLab，Stage 3 產出 `PR_URL` 後或 Stage 4c merged 後，Miyago 要掛工單 -> 把 `PR_URL` 放進 `MR_URLS`，`ISSUE`（編號，可能沒有）轉成網址放進 `ISSUE_URLS`，進本 skill Step 1。
- `cicd-watch`：Step 5 建了新 tag -> 帶該 tag 的 pipeline id 當 run-id 交給它。tag pipeline 失敗時只回報原因就停，修復要另開 MR，不在這裡自動修復或重推 tag。

## 規則

1. key 只經 `rdm`。不直接下 `curl`，不讓 key 出現在指令、檔案或輸出。
2. payload 一律用 `jq -n --arg` 組好從 stdin 餵給 `rdm`，不手寫 JSON 字串。
3. 工單內文與 note 用 Textile（`#` 是編號清單、`*` 是項目），不用 Markdown。
4. 寫入前先讀現值。已有值的欄位不覆寫，同一個連結不重貼。GitLab 的 description 讀不到就不更新。
5. 別人的單只加 note、只填空的 `Gitlab` 欄位；不改狀態、內文、指派，不刪單。
6. 建新 tag 一律要當次的明確同意，而且指令帶 `--ref`。tag 不存在時不執行不帶 `--ref` 的 release 指令。
7. 兩邊都讀回對方的連結才算完成；只寫了一邊要回報缺口。
