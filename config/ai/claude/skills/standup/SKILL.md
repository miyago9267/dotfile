---
name: standup
description: >-
  整理站立會議或週會報告：回溯最近幾個工作天在 ITRD 做的工作，依類別整理，
  延續既有議題產出今日待辦。觸發：站立會議、standup、站會、早會報告、週報、週會、
  上週、我昨天做了什麼、今天要報什麼、/standup
when_to_use: "Miyago 要準備站立會議或週會報告，或想回顧最近幾個工作天的 ITRD 工作並排今日待辦時。"
tags: [standup, sre, itrd, daily, report]
effort: low
shell: required
runtime-scope: shared-core
user-invocable: true
---

# standup

把最近幾個工作天的 ITRD 工作證據，整理成一份能直接念的站會或週會報告。
範圍只含 ITRD 工程事項：基建類（Infra、Security、Perf、Fixing、Billing）與專案類（PMS、NEW_PMS、DQOP、dq-line、RMS 等）。個人 side project、forks、AI 工具不算。

## 參數

- `/standup`：回溯 3 個工作天（週一自動跨週末）
- `/standup 5`：回溯 5 個工作天
- `/standup 週報`，或口頭說「週報」「週會」「上週」：週報模式，範圍是上一個週一到週五，以實際日曆計算。例如今天是週一 11/16，範圍就是 11/09(一)–11/13(五)。
- Miyago 口頭補充的事（會議、支援、口頭需求）直接併入，不必有 commit

## 流程

1. 收證據（read-only）：

   ```bash
   python3 ~/.claude/skills/standup/scripts/collect.py --days 3
   ```

   週報模式時，取足以涵蓋上週一的天數，再自行依日期過濾到上週一至週五（collect.py 只支援 `--days`）。

   同時讀 `~/Project/Active/ITRD/.ai/TODO.md`：它是待辦的唯一清單。今日待辦優先從
   「驗證中」「待做」挑，已標 `[x]` 的不再列成待辦；「等別人」直接對應阻塞欄。

   來源是 ITRD / DevOps / itrd-kb / sre-kb 的 git commits（所有 branch、author
   含 `miyago`）與 Claude session 提問。session 沒有 commit 時，代表調查、排查、
   支援類工作，一樣算進去。

2. 歸納成「類別 + 子類」清單：
   - 類別依固定順序排列：1. Infra 2. Security 3. Perf 4. Fixing 5. Billing 6. Project 7. Other。沒有項目的類別整段省略，編號依實際出現的類別連續編。
   - 類別看這件事「為了什麼」：Infra 是基建變動（退役、搬遷、IaC、DB 升級）；Security 是資安事件與因應；Perf 是系統與工具升級、效能改善（例如 Redmine、GitLab 升級）；Fixing 是修壞掉的東西；Billing 是成本；Project 是各專案或服務的需求。
   - 每條格式為 `- [子類] 描述（狀態）`。子類寫這件事的性質，例如 [退役] [升級] [IaC] [Forensics] [搬遷] [監控] [帳單]；也可以直接用另一個類別名表示性質，例如 Security 底下因資安引起的修復寫 [Fixing]、Fixing 底下的基建問題寫 [Infra]。Project 類的子類用專案或服務名，例如 [PMS]、[DQOP]、[通報機器人]。
   - 描述寫成一句完整的話，交代起因與做了什麼，例如「因應大量服務因資安關閉，services-check 需修復一直噴錯的問題」，不寫成 commit 標題。
   - 狀態用全形括號，只能是以下五種：`（MM/DD(週X)已完成）`、`（預計MM/DD(週X)）`、`（等待PM規劃）`、`（暫緩）`、`（調查中）`；跨多天完成可寫 `（MM/DD(週X)~MM/DD(週X)）`。
   - 週X 用實際日曆算，不憑印象寫。
   - 已完成與進行中、規劃中的項目放在同一個清單，不另開「今日待辦」區塊（週報格式）。
   - 有子項目時，父項目標整體狀態，子項目只在狀態不同時才標；子項目可以只列名稱（例如要升級的 DB 清單）。
   - 同一議題的多個 commit 合成一條，寫成做了什麼事，不逐條抄 commit message。
   - 只寫有證據的事。session 只有提問、看不出結果的，標「（調查中）」而不是「（MM/DD(週X)已完成）」。
   - revert、暫緩、drift 同步這類事要保留，站會上常被追問。
   - 週報模式：超出範圍的已完成項目不列；未完成項目照樣延續，並帶上「預計MM/DD(週X)」。

3. 延續出「今日待辦」3-5 條（僅日報；週報沒有此區塊）。從上一步的議題往下接，每條前面標類別，例如 `[Infra]`。常見延續方向：
   - 做到一半的 → 繼續 / 收尾（開 MR、補 review 回覆、merge 後觀察）
   - 剛上線或改設定的 → 觀察 metrics / alert / log，確認沒有副作用
   - 調查類 → 產出結論、發 issue、或提優化方案
   - IaC / 權限 / 成本 → drift 檢查、盤點、降規、補文件
   - 其他人等你的 → 同步或交接

   待辦要具體到能說出對象（哪個服務、哪個 repo、哪個 alert），不寫「持續優化系統」這種空話；
   可以合理推測，但每條都要能對回某個近期議題。

3a. 報告完成後提議更新 `TODO.md`：把證據顯示已完成的項目移到「最近完成」，新議題補進對應區塊。
   這是本 skill 唯一允許的寫入，Miyago 同意後才改。

1. 有卡住、等人、需要協作的，列在「阻塞 / 需協助」；沒有就寫「無」。

## 輸出格式

直接給能貼到群組或照念的內容，台灣繁體中文、口語但專業，不加 emoji。第一行只寫報告人姓名（沿用 Miyago 上次給的報告，沒有就寫「（姓名）」讓他自己填），不加日期標題。週報範例如下（日報格式相同，之後接「今日待辦」3-5 條）：

```markdown
（姓名）
1. Infra：
   - [退役] dq-line、n8n、chromadb、crawler3、7、8（11/02(一)已完成）
   - [升級] MySQL 資料庫升級 8.4（等待PM規劃）
     - pms-new 及 pms-new-replica
     - pms-stage、production-db3、rms-master-1 皆已完成（11/02(一)~11/05(四)）
2. Security：
   - [Forensics] 攻擊 log 分析（預計11/09(一)）
   - [Fixing] 因應大量服務因資安關閉，services-check 需修復一直噴錯的問題（11/09(一)已完成）
3. Perf：
   - [升級] GitLab 升級，17.5.3 -> 19.5.3（11/07(六)已完成）
4. Fixing：
   - [Infra] 修復 logstash 因 index 及欄位不符導致 log 無法正常儲存的問題（11/12(四)已完成）
5. Project：
   - [通報機器人] 上線新版問卷，移除所有舊 hardcode（預計11/11(三)）

**阻塞 / 需協助**
- 無
```

報告後附一行「依據：N 個 commits、M 則 session」，並列出你推測但證據薄弱的條目，
讓 Miyago 決定要不要留。預計日期若是推測，也在這裡列出，讓 Miyago 修正。

## 邊界

- 只讀：不 commit、不發訊息、不改 issue、不寫知識庫；唯一例外是 Miyago 同意後更新 `TODO.md`。
- 證據不足（腳本輸出 `not enough data`）就直接說，請 Miyago 口頭補充，不自己編完成事項。
- 待辦可以「掰」，完成事項不行。
- 不把 credential、個資、客戶資料抄進報告；人名權限類變更寫「調整 IAM 權限」即可。
