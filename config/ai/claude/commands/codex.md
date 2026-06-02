---
name: codex
description: "互動式呼叫 OpenAI Codex CLI 跑非互動 prompt（second opinion / 外包子任務）。"
---

# /codex [prompt]

把 `[prompt]` 交給 **codex sub-agent** 跑 `codex exec`，把結果壓縮回報。

## 使用範例

- `/codex 幫我審查 src/foo.ts，重點看 race condition` -- 把指定檔丟給 codex 做 code review
- `/codex 為 utils/parser.ts 補 edge case 測試` -- 外包補測試
- `/codex` -- 沒帶 prompt 時改跑 `codex review` 對當前 git diff

## 預設

- 工作目錄：當前 pwd
- 非互動：一律走 `codex exec --ignore-user-config -p fast`，不開 TUI
- 沒帶 prompt：dispatch 為 `codex review`

## 流程

1. 解析使用者帶入的 prompt（空 = `codex review`）
2. 透過 codex sub-agent 呼叫 exact command：`codex exec --ignore-user-config -p fast --cd <pwd> "<prompt>"`
3. 回報結構化結果（依 codex agent 的回報格式）
4. 主對話決定是否 apply codex 的建議

## 相關

- `/code-review` -- 用主對話 agent 做 code review
- 同步 second opinion 場景優先用本指令，避免主 context 被 codex 全量輸出佔滿
