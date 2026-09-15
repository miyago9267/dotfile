---
name: ask-tty
description: "Bash command 確實需要互動輸入（sudo、ssh、y/N）時，透過 ask-tty 取得。"
when_to_use: "只有 non-interactive flag 無法消除 stdin 需求時使用。"
tags: [stdin, tty, sudo, interactive, proxy]
effort: low
shell: required
runtime-scope: claude-native
alwaysApply: false
---

# ask-tty -- stdin proxy

## 觸發邊界

只在 command 確實需要一行 stdin、password、passphrase 或 confirmation 時使用。
普通 local command 不因為「可能會卡」就包上 ask-tty。

## 執行規則

1. 先用 `-y`、`--non-interactive` 或其他 flag 消除可預期的 prompt。
2. 仍需要輸入時，在 Claude Bash 使用 background mode 執行，讓 prompt 可見。
3. password、token、passphrase 一律使用 `ask-tty --sensitive`；不要把值寫入 log、file、
   command argument 或回覆。
4. 一般 confirmation 或短值使用非 sensitive input；輸入只服務目前這一個 command。
5. ask-tty timeout 或不存在時，回報實際原因一次，不重試、不改用猜測值。
6. `vim`、`nano`、`less`、`top`、interactive rebase 等需要完整 TTY 的工具，交給 visible
   terminal，不用 file-backed proxy。

## Claude 流程

先用 `command -v ask-tty` 確認 command；需要密碼時，以本機 ask-tty bridge 取得輸入：

```bash
echo "$(ask-tty 'sudo password' --sensitive)" | sudo -S <command>
```

需要一般輸入時，使用同樣的 background flow，但不要加 `--sensitive`。只在 command 真的需要
stdin 時通知 Miyago；普通 local edit、test、build 與 Git read 不需要通知。
