---
name: ask-tty
description: "Bash command 確實需要互動輸入（sudo、ssh、y/N）時，使用 Gemini native input flow。"
when_to_use: "只有 non-interactive flag 無法消除 stdin 需求時使用。"
tags: [stdin, tty, sudo, interactive]
effort: low
shell: required
runtime-scope: gemini-native
alwaysApply: false
---

# ask-tty -- stdin proxy

## 觸發邊界

只在 command 確實需要一行 stdin、password、passphrase 或 confirmation 時使用。
普通 local command 不因為「可能會卡」就包上 proxy。

## 執行規則

1. 先用 `-y`、`--non-interactive` 或其他 flag 消除可預期的 prompt。
2. 仍需要短的 non-secret input 時，使用 Gemini CLI 的 native input flow，再以 stdin 傳給
   command。
3. password、token、passphrase 或其他 credential 使用 `~/bin/agent-secret`；不要在 chat、
   log、file、argument 或 captured output 中暴露 secret。
4. TUI 或需要 real terminal 的 command 使用 visible terminal；不要使用 file-backed response
   channel 或 idle background process。
5. input channel 不可用時，回報實際 command 與缺少的互動；不無限 polling、不重試。

## 邊界

這個 skill 只處理 Gemini-side input handling，不提供 permissions、credential storage、SSH
automation 或 general background job runner。
