---
name: knowledge-base-router
description: 自動將 project、architecture、implementation、spec、incident、deployment、business-logic 與 historical-decision 問題 route 到 Miyago 的 local Obsidian knowledge bases。Task 位於已知 project、詢問過去的決策或原因、提到 specs、architecture、SOPs、infra、PMS、RiceCall、要求 knowledge-base lookup/update，或既有 project knowledge 能避免重新探索時使用。即使 Miyago 沒明說 knowledge base，也要主動 invoke；寫入時遵守選定 vault 的 local AGENTS.md。
---

# Knowledge Base Router（知識庫路由）

回答或修改 project 前，只要既有 decisions、specs、architecture、operations
knowledge 或 domain rules 可能影響工作，就先查相關的 local vault。不要等 Miyago
提供 vault path。

## 路由任務

| 需求 | Vault | Access |
| --- | --- | --- |
| Miyago 擁有的 projects、specs、architecture、patterns、tools、workflows 與個人工程決策 | `/Users/miyago/Project/Note/miyago-knowledge-base` | 透過其 `AGENTS.md` 讀寫 |
| Service configuration、infrastructure、deployment、SOPs、incidents 與 ADRs | `/Users/miyago/Project/Note/sre-knowledge-base` | 透過其 `AGENTS.md` 讀寫 |
| PMS business logic、DB schema 與 application-layer triage | `/Users/miyago/Project/Note/itrd-knowledge-base` | Read-only；永遠不寫入 |
| RiceCall product、architecture、operations 與 project-specific knowledge | `/Users/miyago/Project/Note/ricecall-knowledge-base` | 透過其 `AGENTS.md` 讀寫 |

Task 跨越 boundaries 時使用多個 vault。RiceCall details 優先使用 RiceCall vault；
其他 vault 的 node 只當 routing index，不當 canonical content。

## 辨識專案

1. 檢查 current working directory、Git root、repository name、remote，或使用者
   已提供的 path。
2. Personal project work 先開 Miyago vault 的 `INDEX.md`，再到 `wiki/projects/`
   找 matching project node。
3. 沒有 repository 時依 subject matter route：infra 到 SRE、PMS domain questions
   到 ITRD、RiceCall work 到它的 canonical vault。
4. 只有多個 plausible vault 會實質改變答案，且 local evidence 無法消除歧義時，
   才提問。

## 查詢流程

1. 對 project、architecture、history、routing、configuration 或 next-step questions，
   先向已安裝的 Factory 要 bounded RoutePlan：

   ```bash
   agent-workflow route --cwd "$PWD" --query "<the user's question>"
   ```

   使用它的 `retrieval_order` 與 selected evidence 作為搜尋邊界。Command unavailable
   時回報 bootstrap gap，再使用下方 manual process；不要掃描每個 vault。
2. 如果 selected vault 的 `AGENTS.md` 尚未載入，先讀它。
3. 存在時先讀 `INDEX.md`，用它的 MOCs 選 candidates。
4. 使用 `rg` 對 titles、aliases、tags、frontmatter、wikilinks、`_MOC.md` 與相關
   project nodes 做 narrow search。
5. 只讀 current decision 所需的 nodes。只有能補上 concrete gap 時，才追 `## Related`
   links。
6. 說明是哪個 node 提供 decision 或 rule；分開 verified facts、inferences、
   conflicts 與 missing knowledge。
7. Vault 沒有 relevant evidence 時明說，接著使用 repository facts；不要捏造
   knowledge-base conclusion。

## 主動查詢

符合以下任一情況時，在 implementation、diagnosis、planning 或 review 前查 knowledge：

- Current repo 有 project node 或 recorded spec history。
- Request 詢問 prior decisions、architecture、conventions、trade-offs、incidents、
  deployment、business rules，或某件事為何如此運作。
- Completed 或 archived spec 可能已 promotion 成 canonical knowledge。
- 從 code 重新發現答案會重複已記錄的 project context。
- Infra、PMS 或 RiceCall domain knowledge 可能改變安全的 next action。

Trivial text edits、self-contained local facts，或答案不可能依賴 stored project
knowledge 的 tasks，可跳過 vault lookup。

## 安全寫入

不要因為發生 query 就寫入。只有 Miyago 要求記錄／更新 knowledge，或 authorized
workflow 明確包含 spec promotion／knowledge maintenance 時才寫。

允許寫入時：

1. 遵守 target vault 的 `AGENTS.md`、schema、templates、deduplication、MOC、
   index 與 log rules。
2. 優先更新 existing canonical node，不要建立 duplicate。
3. 在 vault 內使用 Obsidian wikilinks。
4. 永遠不要寫入 `itrd-knowledge-base`。
5. 永遠不要儲存 credentials、secrets、personal data 或 unverified claims。
6. 執行 target vault 的 lint command 並回報結果。

## 觸發範例

- 「這個專案之前為什麼選這個架構？」
- 「幫我修 Monika 的 session 問題。」
- 「這個 service 怎麼部署？」
- 「PMS 這張表的業務規則是什麼？」
- 「把完成的 spec 整理進知識庫。」
