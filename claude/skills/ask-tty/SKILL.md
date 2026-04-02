---
name: ask-tty
description: "stdin proxy -- Bash tool 需要使用者輸入時（sudo、ssh、y/N），用 ask-tty 取得。永遠生效。"
alwaysApply: true
---

# ask-tty -- stdin proxy (v2)

Bash tool 不支援互動式 stdin。當指令需要使用者輸入（密碼、確認、passphrase），使用 ask-tty + background 模式完成。

## 位置

先用 `which ask-tty` 確認。常見路徑：

- macOS: `~/bin/ask-tty`
- Linux: `~/bin/ask-tty`

找不到就告知使用者 ask-tty 未安裝。

## 核心流程：background + 通知

ask-tty 會 poll `~/.cache/ask-tty/response`，使用者在 Claude Code prompt 輸入 `tty:<值>` 即可回覆（由 tty-respond hook 攔截寫入）。

**關鍵：必須用 `run_in_background: true` 執行，否則 Bash tool 同步 block，使用者看不到提示。**

### 三步流程

1. **先通知使用者**（純文字，不呼叫任何 tool）：

```text
接下來的命令需要 sudo 密碼。
命令會在背景執行，請在 prompt 輸入 tty:<你的密碼> 回覆。
```

2. **用 background 模式執行命令**：

```bash
# Bash tool: run_in_background = true, timeout = 300000
echo "$(ask-tty 'sudo password' --sensitive)" | sudo -S <command>
```

3. **等待 background 完成通知**，回報結果。

## 用法範例

### sudo

```bash
# run_in_background: true
echo "$(ask-tty 'sudo password' --sensitive)" | sudo -S apt install -y nginx
```

### ssh 密碼

```bash
# run_in_background: true
sshpass -p "$(ask-tty 'SSH password for user@host' --sensitive)" ssh user@host <command>
```

### 一般輸入

```bash
# run_in_background: true
VALUE=$(ask-tty "Enter the new hostname")
hostnamectl set-hostname "$VALUE"
```

## Flags

- `--sensitive` / `-s`: 標記為密碼類，本地 IPC 檔案讀取後立即刪除
- `--timeout N` / `-t N`: 超時秒數（預設 120 秒）

## 使用者回覆方式

在 Claude Code prompt 輸入：

```text
tty:mypassword
```

或：

```text
res:y
```

`tty:` / `res:` 前綴會被 tty-respond hook 攔截，密碼不進 Claude context。

## 寫命令時主動避免互動

Claude Code 環境裡 `!` command 也不支援 stdin。唯一的 stdin 通道是 ask-tty + tty:。
所以寫命令時應主動加 non-interactive flag，從源頭消除互動需求。

| 命令 | 互動原因 | 避免方式 |
|------|----------|----------|
| `cp` | alias `cp -i` 或明確 `-i` | 用 `cp -f` 或 `\cp`（bypass alias） |
| `mv` | alias `mv -i` 或明確 `-i` | 用 `mv -f` 或 `\mv` |
| `rm` | alias `rm -i` 或明確 `-i` | 用 `\rm`（不要加 -f，走 permission ask） |
| `apt install` | 確認安裝 | auto-yes hook 自動加 `-y` |
| `npm init` | 互動式問答 | auto-yes hook 自動加 `-y` |
| `ssh-keygen` | passphrase prompt | 加 `-N ""` 跳過 |
| `git commit` | editor | 加 `-m "message"` |
| `git rebase` | interactive mode | 不要用 `-i` |
| `pip install` | 通常不問 | 需要時加 `--yes` |
| `curl` | progress bar 干擾 | 加 `-s`（silent） |

## 規則

1. 密碼類一定加 `--sensitive`
2. 不要把 ask-tty 的輸出存到檔案或 log
3. 不要在 prompt 中洩漏現有密碼
4. ask-tty 回傳的值透過 stdout 取得，不帶換行
5. 如果 ask-tty 失敗（timeout、未安裝），告知使用者原因，不要重試
6. 寫命令時優先用 flag 避免互動（見上表），而非事後處理 stdin
7. 只有需要 TUI 的命令（vim, nano, less, top, htop, git rebase -i）才建議另一個 terminal
8. **不確定會不會卡？用 ask-tty background 試。** 不要保守退回「另一個 terminal」

## 判斷順序

```text
需要 stdin 的命令?
  ├─ 能用 flag 避免？ → 直接加 flag（-y, -f, --force, -N ""）
  ├─ auto-yes hook 已覆蓋？ → 不需介入（apt, npm init, cp -i）
  ├─ 需要密碼/passphrase → ask-tty background + tty: 回覆
  ├─ 不確定是否互動？ → ask-tty background 試（見下方防禦模式）
  └─ 需要 TUI 控制（vim, less, top, rebase -i）→ 另一個 terminal
```

## 防禦模式：不確定時的策略

當無法確定命令是否需要 stdin 時，用 background + ask-tty 包裝：

1. 通知使用者：

```text
這個命令可能需要輸入。如果看到卡住，請用 tty:<你的回覆> 回應。
如果命令自行完成就不用理。
```

2. 用 background 執行，加 ask-tty 作為 stdin 來源：

```bash
# run_in_background: true, timeout: 300000
# 用 pipeline 讓 ask-tty 作為可選的 stdin
(ask-tty "input needed?" --timeout 60 2>/dev/null || true) | <command>
```

如果命令不需要 stdin，ask-tty 會 timeout 但不影響結果（`|| true` + pipe 自動 close）。
如果需要，使用者用 tty: 回覆即可。
