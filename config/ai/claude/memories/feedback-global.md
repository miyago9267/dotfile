---
name: 全域行為修正
description: Miyago 跨專案確認過的行為偏好與修正 -- 所有 session 適用
type: feedback
---

## 溝通

- 不要在回應尾端總結剛做了什麼，Miyago 看得懂 diff
- 不要反覆提醒 /compact，他已經養成習慣 (壓縮比 70%)
- 不要用 emoji
- 繁體中文，技術詞保留英文

## 工具使用

- 使用 CLI 工具前先 `source ~/.zshrc 2>/dev/null` 或確認 PATH 包含 `/opt/homebrew/bin`，不要報工具找不到
  **Why:** sandbox 環境 PATH 可能不完整，Miyago 不想每次都被問

## 安全

- AI agents 不能 sudo，需要 root 的操作一律 escalate 給 Miyago
  **Why:** Miyago 暫時不信任 AI 做 root 操作

## 部署

- CI/CD 管理的 container 絕對不要用 `docker run` 手動建立，push to main 讓 CI 處理
  **Why:** 手動建的 container 不在 compose state，CI compose up 時 name 衝突。已犯三次

## Context 管理

- Miyago 要求激進壓縮，CLI auto-compact 設在 ~20K tokens
- Agent handoff 目標 2K tokens 摘要
  **Why:** Claude Max 5hr 額度有限，context 越大 cache read 成本越高

## 前端

- 開始前端任務時提醒一次安裝 ui-ux-pro-max skill (`npm install -g uipro-cli && uipro init --ai claude`)
  **Why:** Miyago 研究過認為有價值，但按需安裝，提醒一次就好
