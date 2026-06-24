# Design Forge — Backends

各後端的確切 invocation 與 fallback 鏈。Step 4 依 `BACKEND` 讀對應段落。

## ui — Figma

UI 稿、整頁畫面、元件。Figma MCP 有自己的 skill，**必先讀再呼叫工具**。

1. 讀 `/figma-generate-design`（把 app 頁面 / layout 轉成 Figma 稿）或 `/figma-use`（一般操作，呼叫 `use_figma` 前 MANDATORY）。
2. 依 skill 指示呼叫 `use_figma` / `create_new_file` 產稿。
3. 要把素材拉回本地當資產 -> `download_assets`。
4. 設計轉 code -> `get_design_context` / `get_screenshot`。

Fallback（Figma 不可用）-> `code-asset`：用 codex 產 HTML/CSS 版面，存成 `.html`。

## design-system — Claude Design

design tokens、元件庫與 claude.ai design-system 專案同步。

1. 走 `/design-sync` skill，它驅動 `DesignSync` 工具。
2. 順序固定：`list_projects` / `list_files` 讀 → `finalize_plan` 鎖路徑 → `write_files` / `delete_files`。
3. 一次一個元件增量同步，**不要整批 replace**。

Fallback（無 design 授權）-> 用 codex 產元件 HTML/CSS 預覽存本地，之後再同步。

## code-asset — codex

SVG icon、HTML/CSS 片段、theme / design-tokens JSON、CSS variables。

1. `mcp__codex__codex`：傳入 BRIEF（要素：格式、尺寸、配色、約束、輸出單一檔內容）。
2. 或 CLI：`codex exec "<BRIEF>"`（已登入 ChatGPT）。
3. 拿回內容直接寫進 Step 5 的 asset 路徑。

Fallback（codex 不可用）-> Claude 自行產出該 code 素材。

## marketing — Canva

海報、social post、簡報、品牌視覺。也是 `raster` 的 fallback。

1. `generate-design`（或 `generate-design-structured`）帶 BRIEF 產設計。
2. `get-export-formats` 查可用格式 -> `export-design` 匯出 PNG / PDF。
3. 匯出檔落地到 Step 5 的 asset 路徑。

Fallback（Canva 不可用）-> `raster` 走 gpt-image-1；或 `ui` 走 Figma。

## raster — gpt-image-1（預設）

插畫、貼圖、材質、背景、icon 美術。預設 gpt-image-1，失敗自動退 Canva。

```bash
bash scripts/gen-image.sh "<BRIEF prompt>" assets/raster/<slug>.png [size]
# size: 1024x1024(預設) | 1536x1024 | 1024x1536 | auto
```

- exit 0：印出輸出路徑，帶進 Step 5。
- exit 3：無 `OPENAI_API_KEY` -> **自動退 Canva** `generate-design`（marketing recipe）。
- exit 1：API 報錯（額度 / prompt 違規 / 網路）-> 回報 stderr 訊息；可改 prompt 重試或退 Canva。

首次使用 gpt-image-1：`export OPENAI_API_KEY=...`（OpenAI 平台 API key，與 codex 的 ChatGPT 登入是兩回事，按量付費）。

## diagram — Figma

流程圖、架構圖、心智圖。

1. `generate_diagram` 帶結構描述產圖。
2. 互動白板需求 -> `get_figjam` / FigJam。

Fallback（Figma 不可用）-> 用 codex 產 Mermaid / Graphviz 原始碼存成文字資產。

## Fallback 鏈總表

| 主後端 | 第一退路 | 第二退路 |
| --- | --- | --- |
| gpt-image-1 | Canva generate-design | codex SVG（可向量化時） |
| Figma | codex HTML/CSS | — |
| Canva | gpt-image-1 | Figma |
| codex | Claude 自產 | — |
| Claude Design | codex 本地預覽 | — |
