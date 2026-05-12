# AGENTS.md -- 專案開發準則

本檔案是所有 AI 開發工具（Claude Code、Codex、Gemini、Cursor、Copilot 等）在本專案中的行為準則。
任何 LLM agent 進入本專案時，必須先讀取此檔案並遵守以下規則。

---

## SDD v2（Spec-Driven Development）-- 硬規則

1. 非 trivial 任務必須先找或建 spec（`docs/specs/<slug>/SPEC.md`），再實作
2. 不得重問 spec 中已記錄的決策
3. 不得跳過 spec 直接進入中大型實作
4. 實作完必須更新 `TASKS.md` checkbox；`SPEC.md` 只在設計變更時更新
5. 中大型實作前必須等使用者確認

### 兩層分離

SDD v2 將設計產物分為兩層：

- **規格層**（`docs/specs/`）：永遠 commit，跨 session 共享
- **工作記憶層**（`.ai/`）：永遠 gitignore，僅供當前 session 使用

```text
規格層：
docs/specs/<slug>/
  SPEC.md          # What + Why + ADR + Alternatives + Rabbit Holes
  TASKS.md         # 當前 batch 的實作步驟（checkbox）
  TESTS.md         # 測試案例 + EARS 語法驗收條件
  PROGRESS.md      # Phase 級追蹤
  archive/         # 完成的 phase/batch 封存

工作記憶層：
.ai/
  CURRENT.md       # 這個 session 在幹嘛
  HANDOFF.md       # 給下一個 session 的交接
  changelog.md     # 操作紀錄
  lessons.md       # 踩坑紀錄
```

### Spec 四檔分離

| 檔案 | 職責 | 更新時機 |
|------|------|----------|
| `SPEC.md` | 設計決策、需求 (EARS)、ADR | 設計變更時 |
| `TASKS.md` | 當前 batch 的 checkbox | 每步完成時 |
| `TESTS.md` | EARS 驗收條件 + 測試案例 | 設計變更時 |
| `PROGRESS.md` | Phase 級追蹤 | Phase 完成時 |

模板位於 `docs/specs/_templates/`。

### EARS 語法驗收條件

需求和驗收條件使用 EARS (Easy Approach to Requirements Syntax)：

- **When** `<trigger>`, the system shall `<response>`
- **While** `<state>`, the system shall `<response>`
- **Where** `<feature>`, the system shall `<response>`
- **If** `<condition>`, then the system shall `<response>`

### Spec Archive 機制

完成的工作自動封存，保持 spec 目錄乾淨：

- Batch 完成 -- `spec-archive.sh tasks <slug>` 封存 TASKS + TESTS 到 `archive/`
- Phase 完成 -- `spec-archive.sh phase <slug>` 封存 PROGRESS 中已完成的 Phase blocks

### SDD 工作流程

```text
1. 搜尋 docs/specs/，找相關的 SPEC.md
2. 若找到：
   - 讀取 spec，理解需求、決策歷史
   - 讀 TASKS.md 找下一個未完成的 task
   - 報告進度，等使用者確認後開始實作
3. 若沒找到：
   - 用 docs/specs/_templates/ 建立新 spec
   - 填入已知資訊，標記待確認項目
   - 呈現給使用者確認，確認後才開始實作
4. 實作完成後：
   - 打勾 TASKS.md 對應 checkbox
   - 報告：影響範圍、測試狀態、剩餘 tasks
5. Batch 全完成 -> spec-archive.sh tasks <slug>
6. Phase 完成 -> spec-archive.sh phase <slug>
```

### 決策記錄格式（ADR）

重大技術決策記在 spec 中：

```markdown
### ADR：<決策主題>
**背景**：<為什麼需要做這個決策>
**決策**：<最終選擇>
**理由**：<選擇原因>
**替代方案**：
- 方案 A：<優缺點>
- 方案 B：<優缺點>
**後果**：<決策帶來的影響>
**狀態**：accepted | superseded | deprecated
```

---

## TDD（Test-Driven Development）-- 強烈建議

1. 新功能、修 bug、重構時優先先寫測試
2. 遵循 Red -> Green -> Refactor 循環
3. 覆蓋率目標 80%+，金融/認證/安全邏輯 100%
4. 不做 TDD 時必須說明原因
5. 回報時交代：測試是否新增、是否執行、未驗證範圍

### TDD 循環

```text
RED（寫失敗的測試）
  -> GREEN（寫最少的實作讓測試通過）
  -> REFACTOR（改善品質，保持綠燈）
  -> 重複
```

### 測試分層

| 層級 | 範圍 | 何時必要 | 覆蓋率 |
| --- | --- | --- | --- |
| Unit | 單一函式/方法 | 所有 public function | 80%+ |
| Integration | API endpoint / DB 操作 | 所有 API route | 80%+ |
| E2E | 完整使用者流程 | 關鍵業務流程 | 關鍵路徑 |

### 必須覆蓋的 Edge Case

1. Null / Undefined / 空值
2. 空集合（空陣列、空字串）
3. 邊界值（最小、最大、零）
4. 錯誤路徑（網路失敗、DB 錯誤、timeout）
5. 併發 / 競態條件
6. 特殊字元（Unicode、注入字串）

### 不適合 TDD 的情境

純 UI 樣式調整、Prototype/POC、第三方 wrapper、一次性 script -- 至少補最小有價值的測試。

---

## 效率紀律 -- 硬規則

1. **不重複讀取** -- 同一檔案在同一 session 只讀一次
2. **不做無意義 retry** -- 失敗就分析原因換方法，不要 sleep + retry
3. **不複述已知資訊** -- 讀過就直接執行，不要回吐給使用者
4. **能平行就平行** -- 獨立操作同時發出
5. **先想再做** -- 組織完整再寫，不要邊寫邊改來回修
6. **精簡回報** -- 只報結論、變更、下一步

---

## 通用原則

1. 簡潔直接，不過度工程
2. 只改被要求改的東西
3. 不為假設性未來需求設計
4. 安全優先（OWASP Top 10）
5. 每次實作交代影響範圍和測試狀態

---

## SDD + TDD 整合流程

```text
1. [SDD] 找到或建立 Spec（docs/specs/<slug>/SPEC.md）
2. [SDD] 確認需求 -> 拆 TASKS.md（當前 batch）
3. [SDD] 有測試需求 -> 寫 TESTS.md（EARS 語法）
4. [SDD] 使用者確認 -> 開始實作
5. [TDD] 寫失敗的測試（RED）
6. [TDD] 寫最少的實作（GREEN）
7. [TDD] 重構（REFACTOR）
8. [TDD] 重複 5-7 直到完成
9. [SDD] 打勾 TASKS.md / 更新 PROGRESS.md
10. [SDD] Batch 完成 -> spec-archive.sh tasks <slug>
```

---

## Workflows（任何 AI 工具都應遵循）

以下是可被觸發的工作流程。使用者可以說「跑 SDD 流程」、「開始 TDD」、「查 spec 進度」來啟動。

### Workflow: SDD（啟動或繼續 spec 驅動開發）

觸發詞：「SDD」、「spec」、「繼續」、「上次做到哪」、任何非 trivial 新任務

```text
步驟：
1. 搜尋 docs/specs/ 目錄，找相關的 SPEC.md
2. 若找到：
   - 讀取 spec，理解需求、決策歷史
   - 讀 TASKS.md 找下一個未完成的 task
   - 報告：「目前進度 X/Y，下一個 task 是...」
   - 等使用者確認後開始實作
3. 若沒找到：
   - 用 docs/specs/_templates/ 模板建立新 spec
   - 填入已知資訊，標記待確認項目
   - 呈現給使用者確認，確認後才開始實作
4. 實作完成後：
   - 打勾 TASKS.md 對應 checkbox
   - 報告：影響範圍、測試狀態、剩餘 tasks
5. Batch 全完成 -> spec-archive.sh tasks <slug>
6. Phase 完成 -> spec-archive.sh phase <slug>
```

### Workflow: TDD（啟動測試驅動開發循環）

觸發詞：「TDD」、「寫測試」、「test first」

```text
步驟：
1. 分析目前要做的功能或要修的 bug
2. RED -- 寫失敗的測試：
   - 建立 test file（若不存在）
   - 寫 test case，定義預期行為
   - 執行測試，確認因「功能未實作」而失敗
3. GREEN -- 寫最少的實作：
   - 只寫剛好讓測試通過的程式碼
   - 執行測試，確認通過
4. REFACTOR -- 改善品質：
   - 消除重複、改善命名、優化結構
   - 執行測試，確認仍全部通過
5. 重複 2-4 直到功能完成
6. 報告：
   - 新增測試數量和名稱
   - 執行結果（通過/失敗）
   - 覆蓋率
   - 未驗證範圍
```

### Workflow: Spec Status（查看所有 spec 進度）

觸發詞：「spec 進度」、「spec status」、「有哪些 spec」

```text
步驟：
1. 掃描 docs/specs/ 下所有 SPEC.md
2. 讀取每個 spec 的 frontmatter（title, status, updated）
3. 讀取 TASKS.md 計算 checkbox 完成率
4. 讀取 PROGRESS.md 計算 Phase 進度
5. 輸出摘要表格：
   | Spec | 狀態 | Tasks 進度 | Phase | 最後更新 |
6. 問使用者要繼續哪個 spec
```

### Workflow: New Spec（建立新 spec）

觸發詞：「新 spec」、「new spec」、「建 spec」

```text
步驟：
1. 問使用者 feature name（或從對話推斷）
2. 建立 docs/specs/<slug>/ 目錄
3. 從 docs/specs/_templates/ 複製四份模板：
   - SPEC.md, TASKS.md, TESTS.md, PROGRESS.md
4. 填入已知資訊
5. 呈現給使用者確認和補充
```

---

## .ai/ 工作記憶層

`.ai/` 目錄存放 session 級的工作狀態，永遠加入 `.gitignore`。

```text
.ai/
  CURRENT.md       # 這個 session 在幹嘛
  HANDOFF.md       # 給下一個 session 的交接
  PROJECT.md       # 專案地圖（技術棧、目錄結構、重要檔案）
  changelog.md     # 操作紀錄
  lessons.md       # 踩坑紀錄
```

AI 工具在 session 開始時讀取 `.ai/HANDOFF.md`（若存在），繼承前次 context。
在 session 結束時將 `CURRENT.md` 轉為 `HANDOFF.md`。

---

## Markdown 寫作規則 -- 硬規則

基準：markdownlint v0.40.0。寫入或編輯任何 `.md` 前自動修正，不需提醒，不詢問。

### 強制規則（直接修正，無例外）

| Rule | 說明 |
| --- | --- |
| MD001 | Heading 層級只能逐級遞增，不可跳級 |
| MD003 | Heading 統一用 ATX（`##`），不用 Setext |
| MD004 | 無序清單統一用 `-` |
| MD009 | 不得有行尾空格 |
| MD010 | 不得用 hard tab，改用空格 |
| MD011 | 不得用反向連結語法 `(text)[url]` |
| MD012 | 不得有連續兩個以上空行 |
| MD018 | `#` 後必須有一個空格 |
| MD022 | Heading 前後各需一個空行 |
| MD023 | Heading 不得縮排 |
| MD026 | Heading 不得以 `:` `!` `?` `.` 結尾（中文 `：` 允許） |
| MD027 | `>` 後只能有一個空格 |
| MD030 | List marker 後只有一個空格 |
| MD031 | Fenced code block 前後各需一個空行 |
| MD032 | List 前後各需一個空行 |
| MD034 | 不得用裸 URL，必須用 `<url>` 或 `[text](url)` |
| MD037 | Emphasis marker 內不得有空格 |
| MD038 | Inline code 內不得有前後空格 |
| MD039 | Link text 內不得有前後空格 |
| MD040 | Fenced code block 必須指定語言（`bash` `ts` `yaml` `text`...） |
| MD042 | 不得有空連結 `[text]()` |
| MD045 | 圖片必須有 alt text |
| MD046 | Code block 統一用 fenced（backtick），不用縮排式 |
| MD047 | 檔案結尾必須有且只有一個換行 |
| MD048 | Fenced code block 統一用 backtick，不用 `~` |
| MD055 | Table pipe 風格一致 |
| MD056 | Table 每行欄數一致 |
| MD058 | Table 前後各需一個空行 |

### 條件規則（有例外情境）

| Rule | 預設行為 | 例外 |
| --- | --- | --- |
| MD013 | 行長 ≤ 80 字元 | table、code block、URL 豁免 |
| MD024 | 不得重複 heading | 刻意對照結構時加 `<!-- markdownlint-disable-next-line MD024 -->` |
| MD025 | 只能有一個 H1 | 有 frontmatter 的檔案，frontmatter 標題不算 |
| MD033 | 禁止 inline HTML | HTML 註解（`<!-- -->`）允許 |
| MD041 | 第一行必須是 H1 | **有 YAML frontmatter 的檔案強制豁免**，加 `<!-- markdownlint-disable-file MD041 -->` |

### Frontmatter 檔案處理（SKILL.md、SPEC.md 等）

含 `---` YAML frontmatter 的檔案：

- MD041 自動豁免，frontmatter 不計為第一行
- Frontmatter 欄位值超長，豁免 MD013
- 在 frontmatter 結束後第一行前可加：`<!-- markdownlint-disable-file MD041 -->`

### 豁免規則（全域跳過）

MD014、MD028、MD036、MD043、MD044、MD049、MD050、MD051、MD052、MD053、MD054、MD059、MD060
（原因：太專案特定、或與中文技術文件慣例衝突）

只修正觸及範圍，不大規模重寫未修改的區塊。

---

## 目錄結構（Project Map）

每個 session 開始時，依序嘗試讀取：

1. `.ai/PROJECT.md`
2. `.claude/PROJECT.md`
3. `docs/ai/PROJECT.md`

找到就讀，讀完才開始工作。找不到就繼續，不詢問。

---

## Commit 規則 -- 硬規則

1. 格式：`<type>(<scope>): <description>`（feat / fix / refactor / docs / test / chore）
2. 若 commit 包含有 spec 的功能 -> spec checkbox 必須已更新，spec 加入同一個 commit
3. 若新功能沒有 spec -> 先建 spec -> spec 和程式碼同一個 commit
4. 禁止 AI 署名（Co-Authored-By 等任何形式）
5. `.ai/` 的改動永遠不進 commit

不允許「先 commit 程式碼，之後再更新 spec」。

---

## 跨 Session 交接（Handoff）

### 離開當前目錄前（Handoff）

建立 `.ai/HANDOFF.md`，必須包含：

```markdown
# Handoff: {專案名稱}

**From:** {絕對路徑}
**Date:** {YYYY-MM-DD HH:MM}

## 任務背景（30 字內）

## 完成的（帶檔案路徑）

## 未完成的（帶預計要動的檔案）

## 接手後第一件事

> 一句話，具體

## 需要先讀的檔案

1. {路徑} -- {原因}

## 決策記錄（不要重問）

## Git 狀態快照
```

### 進入新目錄後（Pickup）

1. 讀 `.ai/HANDOFF.md`
2. 依「需要先讀的檔案」順序讀取
3. 讀當前目錄 `.ai/PROJECT.md`
4. 輸出繼承摘要，執行「接手後第一件事」

---

## 專案覆寫（Project Overrides）

<!-- 以下區塊由各專案自行填寫，覆蓋上方預設值 -->
<!-- 例如：
- Spec 路徑改為 specs/ 而非 docs/specs/
- 覆蓋率要求調整為 90%
- 額外的 coding convention
-->
