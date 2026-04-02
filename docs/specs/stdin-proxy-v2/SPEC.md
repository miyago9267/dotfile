---
id: spec-stdin-proxy-v2
title: stdin proxy v2 -- 分層消除互動式命令痛點
status: draft
created: 2026-04-02
updated: 2026-04-02
author: Miyago
tags: [claude-code, hooks, ask-tty, dx]
priority: high
---

# stdin proxy v2 -- 分層消除互動式命令痛點

## Background

Claude Code 的 Bash tool 不支援 stdin。遇到需要互動的命令（sudo 密碼、y/N 確認、ssh passphrase）會直接卡住直到 timeout。

現有方案：

- **interactive-bash MCP**: 用 MCP 包裝 pty，但需要切視窗回覆
- **ask-tty + tty-respond**: file IPC 機制，使用者用 `tty:` prefix 在同視窗回覆。但 Bash tool 同步 block 期間使用者看不到任何提示，不知道何時該輸入

核心矛盾：Bash tool 是同步的 -- ask-tty poll 期間整個 tool call 掛住，使用者完全不知道要做什麼。

## Requirements (EARS)

- **R1**: When Bash tool 收到包含 `apt install`/`apt upgrade`/`apt-get` 且缺少 `-y` 的命令, the hook shall 自動附加 `-y` flag
- **R2**: When Bash tool 收到包含 `npm init` 且缺少 `-y` 的命令, the hook shall 自動附加 `-y` flag
- **R3**: When Bash tool 收到常見的 non-interactive flag 缺失的命令, the hook shall 自動補上對應 flag
- **R4**: When Claude 需要執行含 `sudo` 的命令, the skill shall 指導 Claude 先通知使用者再以 background 模式執行
- **R5**: While ask-tty 等待回覆中, 使用者可在同一個 Claude Code 視窗用 `tty:` prefix 回覆，密碼不進 Claude context
- **R6**: When 命令需要複雜互動（vim、interactive rebase）, the skill shall 建議使用者用 `!` prefix 自行執行

## Non-goals

- 不做 pty 模擬 -- 那是 interactive-bash MCP 的職責
- 不做 sudoers NOPASSWD 配置 -- 那是系統層級決策，不由 hook 處理
- 不取代 interactive-bash MCP -- 它仍作為遠端/複雜場景的 fallback

## Alternatives Considered

### 方案 A: AskUserQuestion 兩步驟

Claude 偵測到需要 stdin → 先用 AskUserQuestion 問使用者輸入 → 注入命令。

不選原因：密碼會進入 Claude context，違反安全原則。

### 方案 B: 全部用 `!` prefix

遇到互動式命令就建議使用者自己跑。

不選原因：退化成手動操作，失去自動化的意義。

### 方案 C: 分層處理（採用）

- 層級 1: PreToolUse hook 自動加 flag，零互動消除 80% 場景
- 層級 2: ask-tty background 模式 + Claude 主動通知，同視窗完成
- 層級 3: `!` fallback 處理無法自動化的場景

## Rabbit Holes

1. 不要嘗試讓 hook 改變 Bash tool 的 `run_in_background` parameter -- hook 只能改 `command` 字串
2. 不要在 hook 裡處理所有可能的 y/N 命令 -- 先覆蓋高頻的，用 allowlist 而非 heuristic
3. 不要把 ask-tty timeout 設太長 -- Bash tool 自身有 120s timeout，ask-tty 要在裡面完成

## Architecture

```text
Claude Code 發出 Bash 命令
        │
        ▼
┌─ PreToolUse Hook (auto-yes.sh) ─┐
│                                  │
│  偵測 pattern → 自動加 flag      │  ← 層級 1: 零互動
│  apt install X → apt install -yX │
│  npm init → npm init -y          │
│                                  │
│  不匹配 → 原樣放行               │
└──────────────────────────────────┘
        │
        ▼
┌─ ask-tty Skill 指引 ─────────────┐
│                                   │
│  Claude 偵測到 sudo/ssh:          │  ← 層級 2: 同視窗
│  1. 先輸出文字通知使用者           │
│  2. Bash(run_in_background=true)  │
│     執行 ask-tty 包裝的命令       │
│  3. 使用者用 tty: 回覆            │
│  4. tty-respond hook → file IPC   │
│  5. ask-tty 收到 → 命令繼續       │
│                                   │
└───────────────────────────────────┘
        │
        ▼
┌─ Fallback ────────────────────────┐
│  複雜互動 → 建議 ! prefix         │  ← 層級 3: 手動
└───────────────────────────────────┘
```

## ADR

### ADR-1: Hook 用 allowlist 而非 regex heuristic

- 決策：只改寫明確列出的命令 pattern，不用通用 regex 猜測
- 原因：誤判風險高。`-y` 在某些命令代表完全不同的意義。寧可漏掉少數場景，也不能改壞命令

### ADR-2: 密碼類走 file IPC 而非 Claude context

- 決策：維持 ask-tty 的 file IPC 架構，密碼不進 Claude context
- 原因：即使是 local CLI，context 會被 log、compact、memory 等機制持久化。密碼不該出現在任何非即時的儲存中

### ADR-3: 層級 2 用 Bash background 而非 hook 改寫

- 決策：由 skill 指引 Claude 主動用 `run_in_background`，而非 hook 強制改寫
- 原因：hook 無法可靠地改變 tool 的 `run_in_background` parameter，且 Claude 需要先輸出通知文字

## Phase 計畫

### Phase 1: PreToolUse auto-yes hook

- 建立 `auto-yes.sh` hook
- 註冊到 settings.json PreToolUse
- 覆蓋高頻命令：apt, npm init, pip, yarn

### Phase 2: ask-tty skill 流程優化

- 更新 SKILL.md，加入 background 執行 + 先通知的流程
- 確保 tty-respond hook 與 background Bash 的時序正確

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| hook 誤判命令，錯加 `-y` | 跳過重要確認，執行破壞性操作 | 用 allowlist + 排除 `sudo apt remove` 等危險命令 |
| Bash background timeout 先於 ask-tty | 命令失敗 | ask-tty timeout < Bash timeout (600s max) |
| tty-respond hook 與其他 UserPromptSubmit hook 衝突 | 回覆被錯誤攔截 | tty-respond 只攔截 `tty:`/`res:` prefix，其餘放行 |
