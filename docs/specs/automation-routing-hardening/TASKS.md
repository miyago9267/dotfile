---
spec: automation-routing-hardening
batch: 1
created: 2026-05-12
---

# Tasks: Automation Routing Hardening for Skills, Hooks, and MCP

> Spec: `docs/specs/automation-routing-hardening/SPEC.md`
> Batch: 1

## 前置條件

- [x] 檢查目前 hook 事件與類型
- [x] 盤點高頻 Claude skills frontmatter
- [x] 確認 roadmap 2A 的主要缺口

## 實作步驟

- [x] 補 shared metadata 與 routing 規則
- [x] 更新 Claude / Gemini 的 skill 建立工具模板
- [x] 為第一批高頻 skill 補齊 metadata
- [x] 擴充 Claude hooks 的高價值事件面
- [x] 驗證設定語法與代表性 hook 行為

## 驗證

- [x] 高頻 skill metadata 齊全
- [x] hook 設定可被 `jq` 與 shell syntax 驗證
- [x] routing 規則已落在 shared contract
- [x] spec 追蹤檔已更新
