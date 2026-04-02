---
name: usage
description: "用量儀表板 -- 視覺化顯示 5h/7d rate limit、context window、重置時間。"
---

# /usage

讀取 `~/.claude/quota/current.json` 並格式化顯示。

## 執行步驟

### 1. 讀取 cache

```bash
cat ~/.claude/quota/current.json 2>/dev/null
```

若檔案不存在，告知使用者：「尚無用量資料。statusLine wrapper 需要先設定，執行一次對話後才會有資料。」

### 2. 格式化輸出

用以下格式回報，全部用 code block 確保對齊：

```text
=== Claude Usage Dashboard ===

  5h Rate Limit
  [████████████░░░░░░░░] 60% used
  Resets in: 2h 15m

  7d Rate Limit
  [████░░░░░░░░░░░░░░░░] 20% used
  Resets in: 4d 8h

  Context Window
  [██████░░░░░░░░░░░░░░] 32% used
  Size: 200K tokens

  Model: Claude Opus 4.6

===============================
```

### 3. 進度條規則

- 寬度固定 20 格
- 填充字元：`#`（已用）、`-`（剩餘）
- 顏色提示（用文字標注）：
  - 0-50%: 正常
  - 51-80%: 注意
  - 81-100%: 警告

### 4. 重置時間計算

`resets_at` 是 Unix timestamp（秒），換算成相對時間：

```text
差值 < 60 min    -> "Xm"
差值 < 24 hours  -> "Xh Ym"
差值 >= 24 hours -> "Xd Yh"
```

### 5. 歷史摘要（選填）

若使用者加 `--history`，額外讀取 `~/.claude/quota/history.jsonl` 最近 10 筆，計算：

- 過去 1 小時的用量變化
- 平均每次刷新的 context 增長
- 預估剩餘可用對話數

```bash
tail -10 ~/.claude/quota/history.jsonl 2>/dev/null
```
