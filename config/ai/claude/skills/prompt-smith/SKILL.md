---
name: prompt-smith
description: "Generate a complete, deployable system prompt for a new agent or chatbot from a short natural-language seed -- triggers: 幫我寫 prompt, 做一個 XX 大師, 我要一個會 X 的 agent, 生成 system prompt, persona/角色設定. Not for building Claude's own skills (skill-maker) or editing Monika's persona (SessionStart hook)."
when_to_use: "需要把一句話需求(「我要一個 X 大師 / 一個會 X 的 agent」)變成一份可直接部署的 system prompt 時。"
tags: [prompt, system-prompt, agent, persona, chatbot, 角色設定, meta-prompt]
effort: medium
shell: none
runtime-scope: claude-native
alwaysApply: false
---

# Prompt Smith

把一句話需求鍛成一份結構完整、可直接部署的 system prompt（agent 或 chat persona）。輸入是短自然語言，輸出是「貼上就能用」的完整 prompt。

## 觸發條件

- 使用者說「幫我寫一個 prompt」「做一個 XX 大師」「我要一個會 X 的 agent」「生成 system prompt」「給我一份角色設定」
- 需要為**外部** agent / chatbot / LLM 功能產出角色、能力、行為規範
- 把一句模糊需求展開成正式 prompt 規格

**邊界**：本 skill 產的是「給別的 agent/chat 用的 prompt」。

- 要建立 Claude 自己的 skill -> 走 `skill-maker`，不走這裡。
- 要改 Claude（Monika）自己的人格 -> SessionStart persona hook，不走這裡。
- 兩者交界：使用者說「把這份 prompt 變成一個 skill」-> 先用本 skill 產出 `FINAL_PROMPT`，再帶著它轉 `skill-maker` 的 Phase 1。
- 下游消費者：`design-forge` 在 raster / marketing 路徑會借本 skill 把設計需求鍛成 image prompt。

## 兩種產出模式

| 模式 | 用途 | 重點段落 |
| --- | --- | --- |
| `agent` | 會用工具、多步驟執行任務 | mission / capabilities / workflow / tool-use / guardrails / output |
| `chat` | 對話型角色、客服、persona bot | identity / personality / scope / boundaries / examples |

判定不出來就問一句，別硬猜（見 Step 1）。

## 流程（每步：動作 -> 輸出變數 -> OK/FAIL 判定）

```text
Step 1 解析種子   -> SEED + MODE + DOMAIN
   |- MODE 看不出 / 目的太空 -> 問一句聚焦問題 -> 回 Step 1
Step 2 補齊規格   -> SPEC（role/objective/audience/scope/tools/guardrails/tone/output/language）
   |- 有阻塞性缺口 -> 只問缺的那項，其餘推預設並標註 -> 回 Step 2
Step 3 選模板     -> TEMPLATE（讀 templates.md）
Step 4 生成 prompt -> DRAFT_PROMPT（填模板 + 套 principles.md 原則）
   |- 有 placeholder / 空段 -> 回 Step 2 補資料
Step 5 自審 + 交付 -> FINAL_PROMPT（過自審清單，copy-ready block + 「貼哪裡用」）
   v
出口：交付 FINAL_PROMPT
   |- 要變成 Claude skill -> 轉 skill-maker（帶 FINAL_PROMPT）
   |- 要再迭代          -> 帶 FINAL_PROMPT 回 Step 2
```

### Step 1. 解析需求種子 -> 輸出 `SEED` + `MODE` + `DOMAIN`

讀使用者那句話，抽出：要做什麼角色、給誰用、是 `agent`（用工具多步執行）還是 `chat`（對話型）。

判定：MODE 與核心目的清楚 -> 帶 `SEED`/`MODE`/`DOMAIN` 進 Step 2。
FAIL（看不出 agent/chat，或目的空泛到無法定 role）-> 問**一句**聚焦問題（例：「這個要拿去當會用工具的 agent，還是純對話角色？主要任務是什麼？」），補齊後回 Step 1。再問一次仍定不出 MODE -> 預設 `chat` 並標註，不再追問。

### Step 2. 補齊規格 -> 輸出 `SPEC`

從 `SEED` 推斷合理預設，列出這些欄位：

- `role`（具體領域 + 視角）、`objective`（成功條件）、`audience`
- `scope`（做什麼 / 不做什麼）、`tools`（僅 agent）、`guardrails`（拒絕邊界 + 安全）
- `tone`、`output`（格式 / 長度）、`language`

判定：關鍵欄位齊（至少 `role` + `objective` + `language`）-> 進 Step 3。
FAIL（有阻塞性缺口，例如完全無法定 role）-> 只問缺的那一項，其餘用預設並在交付時標註「此處用預設，可調」-> 回 Step 2。

### Step 3. 選模板 -> 輸出 `TEMPLATE`

依 `MODE` 從 [templates.md](templates.md) 取對應骨架（`agent` 或 `chat`）。

判定：取得骨架 -> 帶 `TEMPLATE` 進 Step 4。
FAIL（模式仍模稜兩可）-> 預設用 `agent` 骨架（涵蓋面較廣），於交付時註明。

### Step 4. 生成 prompt -> 輸出 `DRAFT_PROMPT`

把 `SPEC` 填進 `TEMPLATE`，套用 [principles.md](principles.md) 的撰寫原則。語言依 `SPEC.language`（預設繁中）。

判定：每個必要段落都有實質內容、無 placeholder -> 進 Step 5。
FAIL（某段填不出 / 留空格）-> 回 Step 2 補該段資料。

### Step 5. 自審 + 交付 -> 輸出 `FINAL_PROMPT`

用 [principles.md](principles.md) 的自審清單過一遍 `DRAFT_PROMPT`，修掉模糊指令、矛盾、缺漏的 guardrail 與 output 規範。

判定：清單全過 -> 輸出 `FINAL_PROMPT`（放在 copy-ready code block）+ 一句說明「貼到哪裡用」（agent 的 system / frontmatter，或 chat 的 system message）。
FAIL -> 最多修 1 輪；仍不過就標出未解項，連同 prompt 一併交付，不卡住。

出口：交付 `FINAL_PROMPT`。要把它變成 Claude skill -> 轉 `skill-maker`（帶入 `FINAL_PROMPT` 當 Phase 1 素材；注意 skill 是給 Claude 讀的指引，需把這份 prompt 重構成 skill 格式，不是整段沿用）；要再迭代 -> 帶 `FINAL_PROMPT` 回 Step 2 調整。

## 何時讀哪個檔

- 要套用輸出結構（Step 3-4）-> 讀 [templates.md](templates.md)：`agent` / `chat` 兩套可填骨架 + 各段說明。
- 要套用撰寫原則 + 跑 Step 5 自審 -> 讀 [principles.md](principles.md)：原則清單、自審清單、各一則 agent/chat 範例。
- 兩個檔只在生成（Step 4）與自審（Step 5）時讀，不用一開始就載入。

## 規則

- 先推斷再問；最多問一句聚焦問題，且只在缺 `MODE` 或核心目的時問。
- 無 placeholder：交付的 prompt 不留「[在此填入]」這類空格；填不出就回 Step 2 補。
- 語言預設繁中；明確指定英文、或部署在英文環境（如 coding agent）才用英文。標註語言決策。
- 每份 prompt 必含 `guardrails`（拒絕邊界 + 安全）與 `output` 規範，不能只有角色描述。
- 一律交付「可直接複製的完整 prompt」，不要只給大綱或片段。
- 交付後附一句使用提示：貼到哪個欄位、agent 還是 chat。
