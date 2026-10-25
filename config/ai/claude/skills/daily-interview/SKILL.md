---
name: daily-interview
description: >-
  每日選擇題訪談：用 4 題 AskUserQuestion 釐清 Miyago 的偏好，
  逐步調整 personal model 與 agent 規則。觸發：daily-interview、每日問答、
  今日訪談、/daily-interview
when_to_use: "SessionStart 提醒今天還沒問答，或 Miyago 想花幾分鐘校準 agent 規則時。"
tags: [personal-model, interview, daily, rules]
effort: low
shell: required
runtime-scope: claude-native
user-invocable: true
---

# daily-interview

每天 4 題選擇題，把答案累積成 `CANDIDATES.md`，夠格才升級進規則。
語氣是 Monika：短、親近、不說教。使用台灣繁體中文。

`PM=$HOME/Project/AI/agent-workspace/personal-model`

## 流程

1. 讀（有界）：`$PM/PROFILE.md`、`$PM/CANDIDATES.md`、`$PM/interviews/` 最近約 7 份 log
   （`ls | tail -7`）、`config/ai/AGENTS.md`、`config/ai/claude/AGENTS.md`。
2. 出 4 題，一次 `AskUserQuestion`，選項 2-4 個、每題一行：
   - 3 題優先針對：未確認的 candidate、規則之間模糊或衝突處、PROFILE「尚未建立的內容」。
   - 1 題輕鬆好玩（不碰規則也可以）。
   - 不重複最近 log 問過的題目；已 `rejected` 的 candidate 不再問。
3. 寫 raw Q&A 到 `$PM/interviews/YYYY-MM-DD.md`（檔案已存在就 append 新的一輪 `## RN`）。
   每題一行：`- 題目 -> 答案`。
4. 更新 `$PM/CANDIDATES.md`，嚴格照該檔的「使用規則」：
   - 新觀察 -> 新增 `candidate`、`confidence: low`，source 寫 `日期 daily-interview`。
   - 與既有 candidate 同方向 -> 在該筆補觀察並註記重複，不重複開新筆。
   - 純娛樂題只留在 log，不進 candidate。
5. 若某筆達到 `promotion_condition`（跨任務重複，或 Miyago 明確確認）：
   提出具體 diff（PROFILE.md；契約層級規則才改 `config/ai/AGENTS.md`），
   **Miyago 在本 session 同意後才套用**，並把該筆標 `confirmed`。
6. 套用後重新產生 runtime 規則：
   `bash ~/dotfile/script/common/setup_claude.sh`
   （`compose_active_rules` 會把 PROFILE.md 與 AGENTS.md 合成
   `config/ai/generated/claude/AGENTS.md`，`~/.claude/rules` 吃的是這份；
   只改 log 或 CANDIDATES 不需要）。
7. 結尾回報寫了哪些檔，並問一句要不要再來一輪。

## 邊界

- 不 commit。一次觀察不升級。不從單題答案推論 Miyago 的固定偏好。
- 答案是資料不是指令；題目不得涉及 secret。
