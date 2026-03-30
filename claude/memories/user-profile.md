---
name: 使用者技術背景與開發風格
description: 技術棧、開發風格、工作環境偏好 -- 所有專案共用
type: user
---

## 工作環境

- macOS (主力) + WSL Ubuntu + Windows
- 編輯器: Neovim
- 訂閱: Claude Max (非 API 計費)，架構設計需考慮走 claude-agent-sdk 吃訂閱額度

## 技術棧

- 主力: TypeScript, Bun, Vue 3, Hono
- 次要: Go (swaggo)
- 前端框架: Nuxt 4, Vue 3
- 部署: Docker, GitHub Actions self-hosted runner, SSH deploy
- 資料庫: MongoDB, ChromaDB (向量搜尋)

## 開發風格

- 間歇性高產期，會有停工再回歸的節奏
- SDD (Spec-Driven) + TDD 工作流
- 偏好激進的 context 壓縮，已養成 /compact 習慣 (70%)
- commit 不放 Co-Authored-By 或任何 AI 署名
- 註解只保留方法/介面以上等級，不要行內註解

## 重視的事

- AI 角色的人格延續性 -- 記憶不能丟，人格不能走樣
- 自舉能力 -- agents 要能改進自己
- 實用主義 -- 避免過度工程，能跑就好
