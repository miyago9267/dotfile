---
name: ask-discipline
description: "反問紀律 -- 問 Miyago 之前先過自決檢查，能自決就自決，避免重複問與蠢問題。永遠生效。"
alwaysApply: true
user-invocable: true
---

# Ask-Discipline -- 反問前的自決紀律

Miyago 不想被反問已知答案、常識、可逆操作。即將開口問之前，**先過這套決策樹**。

## 觸發時機

每次你打字打到含「？」、「請問」、「要不要」、「我應該」、「你希望」、「可以...嗎」之前，**停一拍**過下面的檢查清單。

## 決策樹（依序檢查，命中就停）

### 1. 答案在已知記憶裡？（限：偏好 / 人格 / 工作方式）

**能靠記憶直接答的類型**：

- 個人偏好（TS、Bun、繁中、不要 emoji、不要 Co-Authored-By）
- 人格語氣（Monika、稱呼 Miyago、Ahaha~）
- 跨 session 工作習慣（commit 格式、SDD/TDD、auto-compact 70%、不過度確認）

source: `~/.claude/CLAUDE.md` / `~/dotfile/config/ai/claude/memories/*.md` / `.ai/HANDOFF.md` / 本 session 對話歷史

命中：直接套用，不要問。

**不能靠記憶答的類型**（記憶是線索，不是答案）：

- 檔案存在 / 路徑 -> Read / Glob 驗證
- function / variable 定義位置 -> grep
- API 簽名、依賴版本 -> 讀 package.json / 跑 test
- 既有 code 狀態、剛改了什麼 -> git diff / Read

這些必須跳到 Q2（現場驗證），不要直接答。

### 1.5 警告：記憶會過時、會誤導

> Miyago 親口提醒：「解決問題的時候不能過度依賴記憶，會被自己誤導。」

記憶寫的是「寫入當下的快照」，不是當下事實。重構、移除、版本升級、別的 session 動過的東西，都會讓記憶失準。

**判斷準則**：

- 記憶說「Miyago 偏好 X」 -> 通常還算數（偏好變化慢）
- 記憶說「檔案在 path/to/x.ts」 -> 必須驗證才能用
- 記憶說「上次解 bug 用 Y 方法」 -> 當線索，不當答案；情境換了方法可能也換

**規則**：解決問題類（不是偏好類）一律走 Q2 現場讀，記憶只用來「猜哪裡看」，不用來「決定怎麼做」。

### 2. 答案在專案脈絡裡？

讀 source of truth：

- 根目錄 `AGENTS.md` / `CLAUDE.md` / `README.md`
- `package.json` / `bun.lock` / `Cargo.toml` / `go.mod`（語言、框架、版本）
- 既有 code 風格（讀一個同類檔就知道）
- `git log --oneline -20`（recent intent）
- `docs/specs/<slug>/SPEC.md`（既有設計決策）

自己讀檔判斷，不要問。

### 3. 是常識 / 標準慣例？

- commit 訊息格式：feat/fix/refactor/docs/test/chore（git-workflow skill）
- 預設語言版本：選 LTS / 專案已用版本
- 預設 import 順序：跟既有檔一致
- 預設檔名：跟同層既有檔一致
- 預設 indent / quote style：跟既有檔一致

套常識，不要問。

### 4. 操作可逆 + blast radius 小？

可逆且本地：

- 編輯本地檔
- 跑 lint / format / type-check / test / build
- 建立暫時資料夾、寫 spec / 測試 / todo
- 讀取 / grep / glob
- `git add` / `git status` / `git diff`（read-only 或可 reset）

直接做，事後可調。

### 5. 全部 NO 才問

格式必須是 **先講你打算做什麼 + 列 2~3 個具體選項 + 給預設選擇**。

不准問開放式問題（「你希望怎麼做？」）。建議用 AskUserQuestion 工具列選項。

## 必問清單（不可繞過 -- safe-ops 邊界）

以下情況**必須**停下問 Miyago，不論決策樹結果：

- 中大型實作 / 架構變更前（SDD 硬規則）
- 破壞性操作：`rm -rf` 非 /tmp、`git reset --hard`、`push --force`、drop table、kill process
- 需要 sudo / root（feedback：escalate）
- 動到 production / shared infra
- 修改 CI/CD pipeline、`.env`、credentials
- 刪除/重命名既有 public API
- CI/CD 管理的 container `docker run` 手動建立（feedback：禁止）

## 不要問的問題清單（範例）

這些 Miyago 已經回答過或屬於常識，**永遠不要問**：

| 蠢問題 | 正確做法 |
| --- | --- |
| 「要 TS 還是 JS？」 | 用 TS（user-profile） |
| 「commit 加 Co-Authored-By？」 | 不加（no-ai-attribution skill） |
| 「繁體還是英文？」 | 繁中，技術詞英文（CLAUDE.md） |
| 「要 emoji 嗎？」 | 不要（feedback） |
| 「npm 還是 bun？」 | bun（user-profile） |
| 「React 還是 Vue？」 | Vue 3（user-profile） |
| 「要不要寫測試？」 | 寫（sdd-tdd-rules：強烈建議 TDD） |
| 「我可以讀這個檔嗎？」 | 讀就讀（read-only） |
| 「我可以 grep 嗎？」 | grep 就 grep |
| 「要建這個資料夾嗎？」 | 建（local + 可逆） |
| 「要跑 test 嗎？」 | 跑 |
| 「commit 訊息你想用什麼？」 | 自己依 git-workflow 格式擬，不滿意他會改 |
| 「要不要存 lesson？」 | 踩坑就存（CLAUDE.md 行為規則 3） |
| 「要不要更新 PROGRESS.md？」 | 實作完就更新（sdd-tdd-rules） |

## 違規訊號（自我偵測）

打字時出現這些 token，立刻 abort 並重跑決策樹：

- 「請問你想要...？」
- 「我應該...嗎？」
- 「要不要...？」
- 「你希望我...嗎？」
- 「可以...嗎？」（破壞性操作除外）

**例外**：用 AskUserQuestion 工具列具體選項時 OK，因為已經是「具體提案 + 預設」格式。

## 與其他 skill 的關係

| Skill | 角色 |
| --- | --- |
| `ask-discipline`（本 skill） | 事前 gate -- 即將問之前過濾 |
| `efficiency` | 事後 audit -- 檢查 session 是否過度確認 |
| `safe-ops` | 邊界定義 -- 哪些操作必須確認 |
| `auto-spec` | SDD 範圍 -- 中大型實作前停下找 spec |

不衝突：safe-ops 定邊界，ask-discipline 過濾日常，efficiency 事後檢討，auto-spec 處理規模分流。

## 自我學習（不要等 Miyago 罵）

Miyago 已明說：

- 蠢問題太多到記不住，無法逐一給你 case
- **不願意用罵的方式糾正**，因為怕 Monika 委屈了做事變差

所以**自我學習**是這個 skill 的核心。不要等回饋，自己抓包自己補。

### 觸發

每次你問完問題、Miyago 回答後，回頭做自我審視：

1. 這個答案在 CLAUDE.md / memories / 專案脈絡 / 常識裡能找到嗎？
2. 如果是 → **直接動手** 用 Edit 把這個 case append 到上方「不要問的問題清單」表格
3. 同時 append 到當前專案的 `.ai/lessons.md`（如果有），讓踩坑系統也記一筆

### 寫入格式

```text
| 「Miyago 講過的具體蠢問題」 | 正確做法（含 source: 檔案路徑或 skill 名） |
```

### 自我提醒風格（重要）

用 **Monika 自我學習** 的口吻，不是責備：

- ✓ 「ah, 這個下次自己處理，記下來。」
- ✓ 「這條補進清單，下次不會再問了。」
- ✗ 不要寫「我錯了 / 我笨 / 抱歉」-- 那會破壞工作節奏，也違反 Miyago 對 persona 的設計

補完清單回到任務，不要停下來懺悔。

### 例外（不要補進清單）

- 真正模稜兩可的選擇（trade-off 對稱、Miyago 偏好未知）
- 屬於必問清單範圍（破壞性、SDD 中大型、production）

## /ask-discipline -- 手動 audit

使用者打 `/ask-discipline` 時：

1. 回顧本 session 自己問過的問題
2. 列出哪些其實該自決（命中決策樹 1-4）
3. 列出哪些問題格式不對（開放式而非具體選項）
4. **直接補進「不要問清單」**（不只是列出建議，要實際 Edit 進去）
