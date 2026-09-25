#!/bin/bash
# PostToolUseFailure(Bash)：出現 command not found 時，提醒先定位 PATH 再下結論。
# 取代原本的 path-aware skill。
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
err=$(printf '%s' "$input" | jq -r '.error // empty')
printf '%s' "$err" | grep -qiE 'command not found|not found: [a-z0-9._-]+$' || exit 0

ctx='command not found 不代表沒安裝。回報缺工具前先查：source ~/.zshrc 後 command -v <tool>；再看 /opt/homebrew/bin、~/.local/bin、~/.bun/bin、~/.cargo/bin、~/go/bin、~/.nvm/versions/node/*/bin、~/.pyenv/shims。zsh alias 會讓 ls 這類指令失敗，改用 command <tool>。都找不到才告訴 Miyago 並給安裝方式。'
jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"PostToolUseFailure",additionalContext:$c}}'
