---
name: search-discipline
description: "搜索效率紀律 -- 限制 Agent/Explore 的濫用，優先用 Grep/Glob/Read 直接搜索。永遠生效。"
alwaysApply: true
---

# search-discipline -- 搜索效率紀律

控制搜索行為的 token 消耗。Agent(Explore) 一次呼叫可能消耗 50-100+ tool calls 和 80k+ tokens。大多數搜索用 Grep + Read 在 10 個 tool calls 內就能完成。

## 搜索工具選擇順序

```text
搜索需求
  ├─ 知道檔名或 pattern → Glob（1 call）
  ├─ 知道關鍵字 → Grep（1 call）→ Read 結果檔案（N calls）
  ├─ 知道目標在 2-3 個檔案內 → 直接 Read
  └─ 以上都不行，需要跨多目錄探索 → Agent(Explore)（最後手段）
```

## 規則

1. **Grep 優先**：找關鍵字、函數名、class 名、import 路徑 → 用 Grep，不要 Agent
2. **Glob 優先**：找檔案 pattern（`**/*.ts`、`src/**/index.*`）→ 用 Glob，不要 Agent
3. **Read 優先**：已知檔案路徑 → 直接 Read，不要 Agent
4. **Agent(Explore) 是最後手段**：只在需要 3+ 輪搜索、跨多目錄、命名規則不確定時才用
5. **Agent prompt 要具體**：給明確的關鍵字和預期檔案位置，不要「找出所有相關的」
6. **限制 Agent 搜索範圍**：指定具體目錄，不要搜整個 home directory

## Agent(Explore) prompt 寫法

### 壞的 prompt（會消耗 40+ tool calls）

```text
在 ~/dotfile 和 ~/.claude 下找出所有跟 ask-tty、interactive-bash、
tty-respond 相關的檔案，讀取它們的完整內容。
```

問題：範圍太廣、「所有相關的」太模糊、要求讀「完整內容」。

### 好的 prompt（10 tool calls 內完成）

```text
在 /Users/miyago/dotfile/claude/ 下：
1. grep "ask-tty" 找到相關檔案路徑
2. 讀取 skills/ask-tty/SKILL.md 和 hooks/tty-respond.sh
回報路徑和關鍵段落，不需要完整內容。
```

### 更好的做法（不用 Agent，自己做）

```text
直接 Grep "ask-tty" path=/Users/miyago/dotfile
→ 找到 3 個檔案
→ Read 這 3 個檔案
= 4 tool calls, < 5k tokens
```

## 反模式

| 行為 | 消耗 | 正確做法 |
|------|------|----------|
| 用 Agent 找已知檔名 | 20+ calls | Glob 或直接 Read |
| 用 Agent 搜關鍵字 | 30+ calls | Grep files_with_matches → Read |
| Agent prompt 寫「找出所有相關的」 | 40+ calls | 列出具體要找的 2-3 個東西 |
| Agent 搜整個 home directory | 50+ calls | 指定具體子目錄 |
| Agent 要求讀完整檔案內容 | 大量 token | 只讀需要的段落 |

## 成本意識

- Grep: ~200 tokens/call
- Read: ~500-2000 tokens/call（取決於檔案大小）
- Glob: ~200 tokens/call
- Agent(Explore): ~2000 tokens overhead + 所有子 tool calls 的總和
- 一次浪費的 Agent 呼叫 = 10-20 次精準搜索的預算
