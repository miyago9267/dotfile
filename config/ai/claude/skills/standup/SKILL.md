---
name: standup
description: >-
  整理每日站立會議報告：回溯最近幾個工作天在 ITRD 做的基建與專案工作，
  延續既有議題產出今日待辦。觸發：站立會議、standup、站會、早會報告、
  我昨天做了什麼、今天要報什麼、/standup
when_to_use: "Miyago 要準備站立會議報告，或想回顧最近幾個工作天的 ITRD 工作並排今日待辦時。"
tags: [standup, sre, itrd, daily, report]
effort: low
shell: required
runtime-scope: shared-core
user-invocable: true
---

# standup

把最近幾個工作天的 ITRD 工作證據，整理成一份能直接念的站會報告。
範圍只含 ITRD 工程事項：基建（infra / IaC / CI/CD / 監控 / 權限 / 成本）與專案
（PMS、NEW_PMS、DQOP、dq-line、RMS 等）。個人 side project、forks、AI 工具不算。

## 參數

- `/standup`：回溯 3 個工作天（週一自動跨週末）
- `/standup 5`：回溯 5 個工作天
- Miyago 口頭補充的事（會議、支援、口頭需求）直接併入，不必有 commit

## 流程

1. 收證據（read-only）：

   ```bash
   python3 ~/.claude/skills/standup/scripts/collect.py --days 3
   ```

   來源是 ITRD / DevOps / itrd-kb / sre-kb 的 git commits（所有 branch、author
   含 `miyago`）與 Claude session 提問。session 沒有 commit 時，代表調查、排查、
   支援類工作，一樣算進去。

2. 歸納「近期完成 / 進行中」：
   - 同一議題的多個 commit 合成一條，寫成做了什麼事，不逐條抄 commit message。
   - 分「基建」與「專案」兩組；每條前面標主題，例如 `[infra]`、`[PMS]`、`[DQOP]`。
   - 只寫有證據的事。session 只有提問、看不出結果的，標「調查中」而不是「完成」。
   - revert、暫緩、drift 同步這類事要保留，站會上常被追問。

3. 延續出「今日待辦」3-5 條，從上一步的議題往下接，常見延續方向：
   - 做到一半的 → 繼續 / 收尾（開 MR、補 review 回覆、merge 後觀察）
   - 剛上線或改設定的 → 觀察 metrics / alert / log，確認沒有副作用
   - 調查類 → 產出結論、發 issue、或提優化方案
   - IaC / 權限 / 成本 → drift 檢查、盤點、降規、補文件
   - 其他人等你的 → 同步或交接

   待辦要具體到能說出對象（哪個服務、哪個 repo、哪個 alert），不寫「持續優化系統」這種空話；
   可以合理推測，但每條都要能對回某個近期議題。

4. 有卡住、等人、需要協作的，列在「阻塞 / 需協助」；沒有就寫「無」。

## 輸出格式

直接給能貼到群組或照念的內容，台灣繁體中文、口語但專業，不加 emoji：

```markdown
**站會 YYYY-MM-DD（週X）**

**近期進度**（MM/DD - MM/DD）
- 基建
  - [infra] ...
  - [CI/CD] ...
- 專案
  - [PMS] ...

**今日待辦**
1. ...
2. ...

**阻塞 / 需協助**
- 無
```

報告後附一行「依據：N 個 commits、M 則 session」，並列出你推測但證據薄弱的條目，
讓 Miyago 決定要不要留。

## 邊界

- 只讀：不 commit、不發訊息、不改 issue、不寫知識庫。
- 證據不足（腳本輸出 `not enough data`）就直接說，請 Miyago 口頭補充，不自己編完成事項。
- 待辦可以「掰」，完成事項不行。
- 不把 credential、個資、客戶資料抄進報告；人名權限類變更寫「調整 IAM 權限」即可。
