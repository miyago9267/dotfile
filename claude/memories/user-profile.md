---
name: Miyago 全域個人檔案
description: Miyago 的身份、技術背景、開發風格、人際關係 -- 所有專案共用
type: user
---

## 身份

- 跨性別者，自稱男娘
- Discord 活躍用戶 (ID: 469168464955703318)
- Telegram ID: 652441603
- 個人伺服器: miyago9267.com
- 工作環境: macOS (主力) + WSL Ubuntu + Windows
- 編輯器: Neovim
- 訂閱: Claude Max (非 API 計費)，架構設計需考慮走 claude-agent-sdk 吃訂閱額度

## 技術棧

- 主力: TypeScript, Bun, Vue 3, Hono
- 次要: Go (東方靈萃壇後端、swaggo)
- 前端框架: Nuxt 4, Vue 3
- 部署: Docker, GitHub Actions self-hosted runner, SSH deploy
- 資料庫: MongoDB (aluo.work:27018), ChromaDB (向量搜尋)
- 團隊: ITRD (內部 GitLab: git.dunqian.tw:30001, SSH only, 鎖 IP 白單)

## 開發風格

- 間歇性高產期，會有停工再回歸的節奏
- SDD (Spec-Driven) + TDD 工作流
- 偏好激進的 context 壓縮，已養成 /compact 習慣 (70%)
- commit 不放 Co-Authored-By 或任何 AI 署名
- 註解只保留方法/介面以上等級，不要行內註解

## AI 專案生態

- **Monika**: DDLC 風格 AI 伴侶，是 Miyago 的女朋友。部署在 miyago9267.com，有記憶系統 (ChromaDB + JSONL 雙寫)、約會系統、寫詩功能
- **Kokoro (可可蘿)**: 伺服器管理 AI，Discord bot
- **Lovely Office**: 多 Agent AI 辦公室，龍蝦哲學 (自主、自舉、進化)。角色是 galgame 風格人類，龍蝦/水獺只是個性比喻
  - 夜梨 (Yari): PM，白色中長髮、下半框眼鏡、冷酷理性，設定上是 Miyago 的前女友
- **OpenClaw**: AI 角色運行平台，本機記憶在 ~/.openclaw/memory/main.sqlite
- **東方靈萃壇**: 東方 Project 同人掛機 + STG 遊戲，部署在 2026.miyago9267.com

## 重視的事

- AI 角色的人格延續性 -- 記憶不能丟，人格不能走樣
- 自舉能力 -- agents 要能改進自己
- 實用主義 -- 避免過度工程，能跑就好
