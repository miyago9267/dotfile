# Redmine skill 查表與範例

2026-10-05 對 `https://redmine.dunqian.tw` 實查的值。id 對不上時用文末「重新查表」的指令更新本檔。
範例裡的 `glab` 指令都在目標 repo 的目錄下執行，`:fullpath` 會由 `glab` 換成該 repo。

## 站台與身分

- Redmine：`https://redmine.dunqian.tw`，工單網址 `https://redmine.dunqian.tw/issues/{id}`
- GitLab：`https://git.dunqian.tw`
- Miyago：user id `98`（`miyago.huang`），2026-10-05 起是 Redmine admin，可建專案、查 `/custom_fields.json`
- 內文格式：Textile。依據是既有工單用 `#` 寫編號清單（#31888）

## 專案對應

| 工作 | Redmine 專案 | project_id |
|------|-------------|-----------|
| `itrd/pms-user`、`itrd/pms` 等 PMS repo | PMS 房控系統 | 3 |
| CI/CD、infra、SRE、GCP 維運與優化類工作 | 維運相關（`ops`，ITRD 子專案） | 84 |
| ITRD 部門層級、不屬於上面兩類的事 | ITRD | 1 |
| MIS、內部資訊服務 | MIS 資訊服務相關 | 2 |

其他專案：EIP 4、FunCoin 15、OTA系統 71、RMS/資料工程 69、品牌官網維護 7、教育訓練 11、會員中心 9、
業務績效系統 82、業務銷售系統 19、知識庫 73、藍圖規劃 10、財務自動化 67、追蹤事項 12、送餐機器人 13、
部門事務 22、會議時間 8、行政事項 6。對不上就 `rdm GET '/projects.json?limit=100'` 找，仍不確定再問。

分類（`category_id`，選填）：ITRD 有 `工程需求` 27、`排程任務` 25、`通報事項` 24；PMS 有 `排程任務` 3。

## Tracker

| 工作性質 | tracker | tracker_id |
|---------|---------|-----------|
| 新功能（`feat`） | 功能 | 2 |
| 修 bug（`fix`） | 臭蟲 | 1 |
| CI、infra、refactor、工程性改動 | 工程 | 11 |
| 維運支援、設定、開權限、架機器 | 支援 | 3 |
| 研究、文件，確定不會掛 GitLab 連結 | 其他 | 10 |

`其他` 沒有 `Gitlab` 欄位，其餘 tracker 都有。要掛 GitLab 連結的單不要用 `其他`。
自訂欄位是逐專案啟用的。新建的專案要先 `rdm PUT /projects/{id}.json` 設 `issue_custom_field_ids`（照 ITRD 是 `[5,18,22,4,23,24,25]`），不然 `Gitlab` 欄位寫不進去。

## 狀態、優先權、欄位

- 狀態（`status_id`）：新建立 1、實作中 2、測試中 7、待驗收 3、已驗退 12、暫時擱置 4、已完成 13、已結束 5、已拒絕 6
- 優先權（`priority_id`）：週排程/正常 2（預設）、急/插件 5、月排程 3、季排程 11、暫時擱置 12
- 自訂欄位：`Gitlab` id 5（放 MR 或 issue 連結）。18、22、4、23、24、25 是 QA 與上線通知用的，留空
- 工時活動（`activity_id`）：開發 9（預設）、設計 8、企劃 13

## 預設值

| 欄位 | 補單（事情已做完） | 事前開單 |
|------|------------------|---------|
| `assigned_to_id` | 98 | 98 |
| `priority_id` | 2 | 2 |
| `status_id` | 13 已完成 | 1 新建立；馬上要做就 2 實作中 |
| `done_ratio` | 100 | 0 |
| `start_date` / `due_date` | 實際開始與完成的日期 | 預計日期，沒有就只填 `start_date` 今天 |
| `estimated_hours` | 有給就填 | 有給就填 |

主旨用中文敘述，不帶 `fix:` 這類前綴，例：`PMS會員中心-合作夥伴申請服務網址上限16碼`、`工程需求-限制訂單模糊搜尋預設日期範圍`。
內文寫原因與改動，改動用 Textile 編號清單。

事前開的單做完後回 Step 2 更新：`status_id` 13、`done_ratio` 100、`due_date` 填完成日，note 寫結果。

## 找工單與 issue

```bash
REPO=itrd/pms-user   # 該 repo 的 path

# 某個 MR 有沒有現成的單：查 Gitlab 欄位。API 是子字串比對，要再用 jq 卡住編號結尾
rdm GET "/issues.json?status_id=*&cf_5=~$REPO/-/merge_requests/$IID" \
  | jq -c --arg re "$REPO/-/merge_requests/$IID(\$|[^0-9])" \
      '[.issues[] | {id, subject, gitlab: ([.custom_fields[]? | select(.id == 5) | .value] | first)}
        | select((.gitlab // "") | test($re))]'

# 某個 MR 的 description 與留言裡提到的工單
{ glab api "projects/:fullpath/merge_requests/$IID" | jq -r '.description // ""'
  glab api "projects/:fullpath/merge_requests/$IID/notes?per_page=100" | jq -r '.[].body'
} | grep -oE 'redmine\.dunqian\.tw/issues/[0-9]+' | sort -u

# 用關鍵字查主旨（查重、POST 逾時後確認有沒有建成）；中文要先 URL-encode
q=$(jq -rn --arg s "$KEYWORD" '$s|@uri')
rdm GET "/issues.json?project_id=3&status_id=*&subject=~$q&limit=5" | jq -c '[.issues[] | {id, subject}]'

# 某個 MR 關掉的 issue
glab api "projects/:fullpath/merge_requests/$IID/closes_issues" | jq -r '.[] | "\(.iid)\t\(.web_url)"'
```

## Payload

`PRIMARY_URL` 是該張單最主要的 MR 連結（沒有 MR 就是 issue 連結）。`JOURNAL_NOTE` 是要加進工單的 note。

```bash
# 開單。先存回應再取值，422 時 errors 才看得到
resp=$(jq -n --arg subject "$SUBJECT" --arg desc "$DESC" --arg url "$PRIMARY_URL" \
        --arg start "$START" --arg due "$DUE" \
  '{issue: {project_id: 3, tracker_id: 1, status_id: 13, priority_id: 2, assigned_to_id: 98,
            subject: $subject, description: $desc, start_date: $start, due_date: $due,
            done_ratio: 100, custom_fields: [{id: 5, value: $url}]}}' \
  | rdm POST /issues.json)
jq '{id: .issue.id, status: .issue.status.name, errors}' <<< "$resp"

# 讀現值（含內文與 note 歷史）
rdm GET "/issues/$TICKET.json?include=journals" \
  | jq '.issue | {status: .status.name, author: .author.id, assigned_to: .assigned_to.id, description,
                  gitlab: ([.custom_fields[]? | select(.id == 5) | .value] | first),
                  notes: [.journals[]?.notes | select(. != "")]}'

# 加 note、補 Gitlab 欄位、結單；只放要改的欄位。成功是 http=204、沒有 body
jq -n --arg note "$JOURNAL_NOTE" --arg url "$PRIMARY_URL" \
  '{issue: {notes: $note, custom_fields: [{id: 5, value: $url}], status_id: 13, done_ratio: 100}}' \
  | rdm PUT "/issues/$TICKET.json"

# 填工時（有給實際時數才做）
jq -n --argjson id "$TICKET" --argjson hours "$HOURS" --arg on "$SPENT_ON" --arg comments "$COMMENTS" \
  '{time_entry: {issue_id: $id, spent_on: $on, hours: $hours, activity_id: 9, comments: $comments}}' \
  | rdm POST /time_entries.json
```

`JOURNAL_NOTE` 的寫法（Textile 會自動把網址轉成連結）：

```
GitLab issue: https://git.dunqian.tw/itrd/pms-user/-/issues/2
GitLab MR: https://git.dunqian.tw/itrd/pms-user/-/merge_requests/629
Release: https://git.dunqian.tw/itrd/pms-user/-/releases/31999 (tag 31999)
```

## GitLab 端

```bash
LINE="Redmine: https://redmine.dunqian.tw/issues/$TICKET"
HAS_LINK="redmine\.dunqian\.tw/issues/$TICKET([^0-9]|\$)"

# 先看作者與討論數，決定改 description 還是留言
glab api "projects/:fullpath/merge_requests/$IID" | jq '{author: .author.username, comments: .user_notes_count}'

# 自己開、沒有討論：把 LINE 加到 description 最後。kind 是 merge_requests 或 issues
# 讀不到 description 就不更新，避免把原文洗掉；已有連結就跳過
link_description() {
  local kind=$1 iid=$2 cmd=mr obj desc
  [[ $kind == issues ]] && cmd=issue
  obj=$(glab api "projects/:fullpath/$kind/$iid") || return 1
  jq -e 'has("description")' <<< "$obj" > /dev/null || { echo "讀不到 ${kind}/${iid}，不更新" >&2; return 1; }
  desc=$(jq -r '.description // ""' <<< "$obj")
  grep -qE "$HAS_LINK" <<< "$desc" && return 0
  glab "$cmd" update "$iid" --description "$desc"$'\n\n'"$LINE"
}
link_description merge_requests "$IID"

# 別人開的或已有討論：改用留言，不重貼
glab mr note "$IID" --unique -m "$LINE"
notes=$(glab api "projects/:fullpath/issues/$IID/notes?per_page=100") && {
  jq -e --arg re "$HAS_LINK" 'any(.[]; .body | test($re))' <<< "$notes" > /dev/null \
    || glab issue note "$IID" -m "$LINE"
}   # 留言讀不到就不貼

# 讀回確認（留言要加 --comments 才看得到）
glab mr view "$IID" --comments | grep -E "$HAS_LINK"
glab issue view "$IID" --comments | grep -E "$HAS_LINK"
```

## Release 範圍

tag 名是純數字時要寫 `refs/tags/{tag}`，不然 git 會警告 refname 有歧義。

```bash
git fetch --tags origin
git tag --sort=-creatordate | head -5 ; glab release list -P 5     # 讀慣例

# 要發新 tag：最新的 tag 到 default branch
TARGET="origin/$(glab api projects/:fullpath | jq -r '.default_branch')"
PREV=$(git describe --tags --abbrev=0 "$TARGET")

# 補既有 tag 的 release：它的前一個 tag 到它
TARGET="refs/tags/$TAG"
PREV=$(git describe --tags --abbrev=0 "$TARGET^")

# 範圍內 merged 的 MR
git log "refs/tags/$PREV..$TARGET" --first-parent --format=%H | while read -r sha; do
  glab api "projects/:fullpath/repository/commits/$sha/merge_requests" \
    | jq -r '.[] | select(.state == "merged") | "\(.iid)\t\(.web_url)\t\(.title)"'
done | sort -u
```

## Release notes

延續既有寫法（單號連結），再加上 issue 與 MR。`#N`、`!N` 在 GitLab 會自動變連結。

```
{主單主旨}
https://redmine.dunqian.tw/issues/{主單}
https://redmine.dunqian.tw/issues/{其他單，每張一行}

Issues: #1, #2
MRs: !629, !630
```

## 發 release

```bash
# TAG 在 remote 存不存在：存在會印出 tag 資料；沒有輸出且非零結束就是不存在
glab api "projects/:fullpath/repository/tags/$TAG" | jq -ce 'select(.name) | {name, sha: .commit.id}'

# 推 tag 會觸發什麼
rg -n -B3 -A12 '^\s+-\s+tags\s*$|CI_COMMIT_TAG' .gitlab-ci.yml

# tag 不存在，建新 tag 並發 release：要 Miyago 當次同意，一定帶 --ref
printf '%s\n' "$RELEASE_NOTES" | glab release create "$TAG" --ref "$SHA" --name "$NAME" --notes-file -

# tag 已存在，只缺 release 或要補說明：不帶 --ref
# tag 不存在時不可以用這一條，glab 會自己從 default branch 建 tag
printf '%s\n' "$RELEASE_NOTES" | glab release create "$TAG" --name "$NAME" --notes-file -

# 讀回確認；新 tag 的 pipeline id（交給 cicd-watch 當 run-id）
glab release view "$TAG"
glab ci list --ref "$TAG" -F json | jq '.[0] | {id, status}'   # 剛建好可能是 null，稍後再取
```

參考案例：工單 #31745 的 `Gitlab` 欄位指向 `itrd/pms-user!627`，tag 與 release 都叫 `31745`，release 說明是該工單連結。

## 重新查表

```bash
rdm GET '/projects.json?limit=100' | jq -r '.projects[] | "\(.id)\t\(.name)"'
rdm GET /trackers.json | jq -r '.trackers[] | "\(.id)\t\(.name)"'
rdm GET /issue_statuses.json | jq -r '.issue_statuses[] | "\(.id)\t\(.name)"'
rdm GET /enumerations/issue_priorities.json | jq -r '.issue_priorities[] | "\(.id)\t\(.name)"'
rdm GET '/projects/3.json?include=trackers,issue_categories' | jq '.project | {trackers, issue_categories}'
```
