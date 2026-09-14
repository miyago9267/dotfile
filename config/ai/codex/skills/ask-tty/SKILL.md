---
name: ask-tty
description: "在 Codex 中處理需要一行使用者輸入的 shell commands，不使用 Claude-specific stdin bridges。"
metadata:
  short-description: "Codex-native 的互動式 command input"
  when_to_use: "local command 確實需要簡短 non-secret response、confirmation 或 visible terminal interaction 時使用。"
  tags: [codex, stdin, interactive, tty, input]
  effort: low
  shell: preferred
  runtime-scope: codex-native
---

# Codex ask-tty

簡短、非 secret 的 responses 使用 Codex native user-input flow。不要使用
Claude-specific `tty:` prefixes、`tty-respond` hooks、file polling，或等待
response 的 background process。

## 判斷順序（Decision order）

1. Command 支援時，用 non-interactive flag 移除 prompt。
2. 短的 non-secret value 或 confirmation 使用 native user-input tool，再把該值
   經 stdin 傳給 command。
3. Passwords、tokens、passphrases 或其他 credentials 使用 `~/bin/agent-secret`；
   絕不在 chat 或 logs 中要求或 echo secret。
4. TUI 或需要 real terminal 的 command 使用 visible terminal session。不要用
   file-backed response channel 偽造 TTY。

## 執行限制（Execution constraints）

- 將 input 限定為目前 command 的單一用途與 bounded value。
- 不要把 secret values 放進 command arguments、environment snapshots、temporary
  files 或 captured output。
- 一般 values 優先使用 `stdin` piping；安全引用 user input。
- Command 能改成 non-interactive 時，使用該形式，不要提問。
- Input channel unavailable 時，停止並回報 exact command 與 missing interaction；
  不要無限 polling。

## 邊界（Boundary）

這個 skill 只提供 Codex-side input handling，不提供 permissions、credential
storage、SSH automation 或 general background job runner。
