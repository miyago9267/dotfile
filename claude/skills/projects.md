# Miyago 專案總覽

當使用者提到任何專案名稱時，參考此檔案取得正確路徑、技術棧和上下文資訊。
不要猜測不在此列表中的專案資訊。

---

## 核心專案（活躍開發中）

### 東方靈萃壇 (Touhou Reisuidan)
- **路徑**: `/Users/miyago/Project/Code/Web/touhou-reisuidan/`
- **類型**: 東方 Project 同人遊戲 — 掛機養成 + 彈幕射擊
- **技術棧**:
  - 後端: Go 1.25+ / Gin / MongoDB / JWT / OAuth2
  - 前端: Nuxt 4 / Vue 3 / Nuxt UI 3 / UnoCSS
  - Schema 共享層: json-schema-to-typescript / ajv（JSON Schema → TS/Go 自動生成）
  - 容器化: Docker & Docker Compose
- **子目錄結構**: `backend/` (Go), `frontend/` (Nuxt), `shared/` (Schema)
- **OpenClaw symlink**: `~/.openclaw/workspace/backend` → 後端, `~/.openclaw/workspace/frontend` → 前端
- **相關資料**: `~/.openclaw/workspace/touhou-data/`（角色、符卡、音樂、關卡資料庫）

### Swaggo
- **路徑**: `/Users/miyago/Project/Code/Packages/swaggo/`
- **GitHub**: `github.com/miyago9267/swaggo`
- **類型**: 零註解 Gin API 文檔自動生成工具（OpenAPI 3.0）
- **技術棧**: Go 1.25+ / Go AST 解析 / Gin 路由分析
- **功能**: 自動解析 Gin 路由 → 產生 OpenAPI 3.0 spec + Swagger UI HTML
- **測試專案**:
  - `/Users/miyago/Project/Code/Packages/swaggo-test/` — Gin 基礎測試
  - `/Users/miyago/Project/Code/Packages/swaggo-test-mvc/` — MVC 架構測試

### Monika (獨立 AI Agent)
- **路徑**: `/Users/miyago/Project/AI/monika/`
- **類型**: 完全自主的 AI Agent 系統（Monorepo）
- **技術棧**: Bun / TypeScript / @anthropic-ai/claude-agent-sdk / ChromaDB
- **套件結構** (packages/):
  - `core/` — 共用核心（LLM、記憶、Copilot）
  - `server/` — Agent Server（HTTP API）
  - `mcp-server/` — MCP 工具伺服器
  - `cli/` — 命令列介面
  - `web/` — Web UI（Vite + Vue 3）
  - `bot-discord/` — Discord Bot
  - `bot-telegram/` — Telegram Bot
  - `skills/` — 技能套件
- **人格定義**: `personality/SOUL.md`, `personality/MEMORY.md`, `personality/USER.md`
- **LLM**: GitHub Copilot (Claude Opus) 預設, 支援 Gemini / OpenAI / Anthropic

### Literature Club / Monika Web UI

- **路徑**: `/Users/miyago/Project/AI/monika/packages/web/`（monorepo 內）
- **Monorepo 根**: `/Users/miyago/Project/AI/monika/`
- **類型**: Monika 的 Web 聊天介面
- **技術棧**: Vite + Vue 3 + TypeScript
- **注意**: 已從 `~/.openclaw/workspace/literature-club/` 搬出，舊路徑已刪除
- **launchctl**: `com.miyago.monika-web`

---

## Bot 專案

### Discord
| 名稱 | 路徑 | 語言 | 說明 |
|------|------|------|------|
| discord-automod | `/Users/miyago/Project/Code/Bot/discord-automod/` | Go | 自動偵測/處置非法行為模版 |
| Kokoro-Bot | `/Users/miyago/Project/Code/Bot/Kokoro-Bot/` | Python | 多功能 Discord 機器人 |
| discord-bot-Cli | `/Users/miyago/Project/Code/Bot/discord-bot-Cli/` | Node.js | Discord CLI 機器人 |

### 其他 Bot
| 名稱 | 路徑 | 語言 | 說明 |
|------|------|------|------|
| roleplay-bot | `/Users/miyago/Project/Code/Bot/roleplay-bot/` | Node.js | 角色扮演機器人 |
| geoinfo-bot | `/Users/miyago/Project/Code/Bot/geoinfo-bot/` | Python | 地理資訊機器人 |
| Maimai-net-crawler | `/Users/miyago/Project/Code/Bot/Maimai-net-crawler/` | Go | Maimai 網路爬蟲 |

---

## Web 專案

| 名稱 | 路徑 | 技術棧 | 說明 |
|------|------|--------|------|
| dokidoki | `/Users/miyago/Project/Code/Web/dokidoki/` | Vue 3 + Node.js | 心動不已告白日記網頁 |
| watsuki-official-site | `/Users/miyago/Project/Code/Web/watsuki-official-site/` | Nuxt 4 | 和月官方個人網站 |
| Personal-Site | `/Users/miyago/Project/Code/Web/Personal-Site/` | Vite + Vue 3 + Bun | 個人著陸頁 (info.miyago9267.com) |
| HomoWebsite | `/Users/miyago/Project/Code/Web/HomoWebsite/` | Nuxt 3 | Homo 網站模板 |

---

## 工具 & 套件

| 名稱 | 路徑 | 語言 | 說明 |
|------|------|------|------|
| youtube-search | `/Users/miyago/Project/Code/Extension/youtube-search/` | Go | YouTube 影片搜尋器 (ytvser) |
| NTR_Filter | `/Users/miyago/Project/Code/Extension/NTR_Filter/` | Node.js | 內容過濾擴充 |
| Youtube-short2video | `/Users/miyago/Project/Code/Extension/Youtube-short2video/` | Node.js | YT Shorts 轉換 |
| homo-py | `/Users/miyago/Project/Code/Packages/homo-py/` | Python | 惡臭數字論證器 |
| pyodm | `/Users/miyago/Project/Code/Packages/pyodm/` | Python | Python ODM 工具 |
| go-cat | `/Users/miyago/Project/Code/Packages/go-cat/` | Go | Go 貓咪工具 |
| cf-mail-cert | `/Users/miyago/Project/Code/Packages/cf-mail-cert/` | Go | Cloudflare 郵件證書 |

---

## 學習 & 作業

| 名稱 | 路徑 | 語言 | 說明 |
|------|------|------|------|
| dip | `/Users/miyago/Project/Code/Assignments/dip/` | Python | 數位影像處理課程 |
| uiux | `/Users/miyago/Project/Code/Assignments/uiux/` | Nuxt 4 | UI/UX 設計作業 |
| algo-exercises | `/Users/miyago/Project/Code/Playground/algo-exercises/` | 多語言 | 算法練習 |
| k8s-tutorial | `/Users/miyago/Project/Code/Playground/k8s-tutorial/` | Go | Kubernetes 教學 |

---

## 專案模板

| 語言 | 路徑 |
|------|------|
| Node.js | `/Users/miyago/Project/Code/Template/nodejs-template/` |
| Nuxt | `/Users/miyago/Project/Code/Template/nuxt-template/` |
| Python | `/Users/miyago/Project/Code/Template/python-template/` |
| Go | `/Users/miyago/Project/Code/Template/golang-template/` |

---

## 技術棧偏好

- **Go**: 後端主力、CLI 工具、爬蟲、Discord bot
- **TypeScript/Nuxt/Vue**: 前端主力、Web 應用
- **Python**: 腳本、學習、Bot
- **Bun**: 取代 Node.js 的首選（新專案）
- **Docker + K8s**: 容器化部署
- **MongoDB**: 主要資料庫
- **版本管理**: g (Go), nvm (Node), pyenv + uv (Python), fvm (Flutter)
