---
name: design-forge
description: "幫我設計 / 做一張圖 / 生成素材時，把需求分類派給對的後端：UI 稿→Figma、設計系統→Claude Design、向量或 code 素材→codex、行銷視覺→Canva、點陣插畫→gpt-image-1，產出統一落地成資產。triggers: 幫我設計, 做個 UI/介面, 做一張圖, 生成素材, 做個 icon/插畫/海報, 設計系統, 流程圖, design asset。邊界：寫 prompt 文案→prompt-smith；純 codex 程式外包→codex。"
when_to_use: "需要產出設計成品或圖片素材（UI / 插畫 / icon / 海報 / diagram / design system），且要決定用哪個後端並落地成可重用資產時。"
tags: [design, image-generation, assets, figma, canva, codex, illustration]
effort: medium
shell: optional
runtime-scope: claude-native
alwaysApply: false
---

# Design Forge

設計素材的路由器。把一句設計需求分類成 `ASSET_KIND`，派給最合適的後端產出，再統一落地成 `assets/` 下的資產並登錄 manifest。不重造各後端，只做「分類 → 交棒 → 標準化存放」。

## 觸發條件

- 使用者說「幫我設計 X」「做個 UI / 介面 / 登入頁」「做一張圖 / 生成素材」「做個 icon / 插畫 / 海報 / banner」「同步設計系統 / 元件庫」「畫個流程圖 / 架構圖」
- 需要產出可重用的視覺或設計成品，且要決定後端與存放位置

**邊界**：

- 要寫 prompt 文案 / 角色設定 → `prompt-smith`（但圖片類的 image prompt 可由本 skill 借它生）
- 純 codex 程式外包（非設計）→ `/codex` command / agent
- Figma 細節操作 → 必讀 `/figma-use` 後再呼叫工具；本 skill 只負責路由與交棒
- 設計系統元件庫同步 → `/design-sync`

## 路由表

| ASSET_KIND | 例子 | BACKEND | 交棒 / 工具 |
| --- | --- | --- | --- |
| `ui` | 登入頁、卡片、按鈕、整頁畫面 | Figma | `/figma-generate-design` → `download_assets` |
| `design-system` | design tokens、元件庫同步 | Claude Design | `/design-sync` + `DesignSync` 工具 |
| `code-asset` | SVG icon、HTML/CSS 片段、theme/tokens JSON | codex | `mcp__codex__codex` |
| `marketing` | 海報、social post、簡報、品牌視覺 | Canva | `generate-design` → `export-design` |
| `raster` | 插畫、貼圖、材質、背景圖、icon 美術 | gpt-image-1 | `scripts/gen-image.sh`，失敗自動退 Canva |
| `diagram` | 流程圖、架構圖、心智圖 | Figma | `generate_diagram` / FigJam |

各後端的確切 invocation、參數、fallback 鏈都在 `backends.md`，到 Step 4 才讀。

## 流程（每步：動作 → 輸出變數 → OK/FAIL 判定）

```text
Step 1 分類需求    -> ASSET_KIND + USE（拿去哪用）
   |- 看不出 kind / 多義 -> 問一句聚焦問題 -> 回 Step 1
Step 2 選後端      -> BACKEND（查路由表）
Step 3 備 brief    -> BRIEF（尺寸/風格/內容/約束；圖片類可借 prompt-smith 生 image prompt）
Step 4 生成        -> RAW（讀 backends.md 拿確切 invocation）
   |- 後端不可用 / 報錯 / 無 key -> 走 fallback 鏈，帶新 BACKEND 回 Step 4
   |- 連 fallback 都失敗 -> 回報原因並停
Step 5 落地存資產  -> ASSET_PATH（+ manifest + changelog）
   v
出口：回報 ASSET_PATH + 來源 backend + 怎麼用
   |- 要接進前端 -> 交給專案前端流程
   |- 要再生變體 -> 帶 BRIEF 回 Step 3
```

### Step 1. 分類需求 -> 輸出 `ASSET_KIND` + `USE`

讀需求，對到路由表六類之一；同時抓「拿去哪用」（README banner / app icon / 登入頁 / 簡報封面…），這會影響尺寸與後端。

判定：kind 明確 -> 帶 `ASSET_KIND`/`USE` 進 Step 2。
FAIL（看不出 kind 或多義，例如「做張圖」可能是 UI 稿、向量 icon 或點陣插畫）-> 問**一句**：「這要的是可編輯 UI 稿、向量 icon，還是點陣插畫？拿去哪用？」-> 回 Step 1。

### Step 2. 選後端 -> 輸出 `BACKEND`

查路由表把 `ASSET_KIND` 對到 `BACKEND`。判定：OK -> 帶 `BACKEND` 進 Step 3。

### Step 3. 備 brief -> 輸出 `BRIEF`

- `raster` / `marketing`：寫出強生成 prompt（主體、風格、配色、構圖、尺寸、用途、negative）。若需要更精緻的 prompt -> 借 `prompt-smith` 產 image prompt 後帶回。
- `ui` / `code-asset` / `diagram` / `design-system`：整理 spec（尺寸、風格、內容結構、約束、既有 design token）。

判定：BRIEF 無缺口 -> 進 Step 4。FAIL（缺尺寸/用途等阻塞資訊）-> 推合理預設並標註，或只問缺的那項 -> 回 Step 3。

### Step 4. 生成 -> 輸出 `RAW`

讀 `backends.md`，依 `BACKEND` 跑對應 recipe。

- `raster` 預設走 `scripts/gen-image.sh "<BRIEF>" <out> [size]`（gpt-image-1，優先）。
- 其餘依 backends.md 的 MCP 工具 / skill 交棒。

判定：產出成功 -> 帶 `RAW` 進 Step 5。
FAIL：
- `gen-image.sh` exit 3（無 `OPENAI_API_KEY`）-> **自動退 Canva** `generate-design`，帶回 Step 4。
- 其他後端報錯 / 不可用 -> 走 backends.md 的 fallback 鏈，帶新 `BACKEND` 回 Step 4。
- 連 fallback 都失敗 -> 回報具體原因並停（不留半成品）。

### Step 5. 落地存資產 -> 輸出 `ASSET_PATH`

1. 存到 `assets/<ASSET_KIND>/<slug>.<ext>`（預設 repo 根的 `assets/`，無則建；專案若已有慣例目錄如 `public/` / `src/assets/` 則沿用並標註）。
2. 更新 `assets/manifest.json`：`{ name, kind, backend, brief, size, path, date }` 一筆。
3. `bash ~/.claude/scripts/log.sh chore assets <ASSET_PATH> "<desc>"`。

出口：回報 `ASSET_PATH` + 來源 backend + 怎麼用。要接進前端 -> 交專案前端流程；要再生變體 -> 帶 `BRIEF` 回 Step 3。

## 規則

- 不預檢 CLI / key / 連線：直接跑，FAIL 才走 fallback。
- 每個產出都要落地成 asset + manifest，不把成品留在對話裡。
- `raster` 預設 gpt-image-1（使用者指名的 GPT image gen），無 `OPENAI_API_KEY` 自動退 Canva，不中斷流程。gpt-image-1 走 OpenAI Images API 按量付費，首次使用者需自行設定 key。
- Figma / Canva / DesignSync 都靠 Claude 端的 MCP 連線；codex / gemini 無法驅動，故本 skill 為 claude-native，不需跨 runtime adapter。
- 繁體中文 + 英文技術詞，無 placeholder。
