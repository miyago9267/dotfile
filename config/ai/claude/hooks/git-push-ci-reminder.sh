#!/usr/bin/env bash
# PostToolUse hook: git push 偵測後提醒 cicd-watch
# 排除 dry-run / --help

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# 必須是 git push（含前後 boundary），排除 dry-run 與 help
if ! printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+push([[:space:];&|]|$)'; then
  exit 0
fi
if printf '%s' "$cmd" | grep -qE '(\-\-dry-run|\-\-help|\-n[[:space:]]|\-h[[:space:]])'; then
  exit 0
fi

# 取 exit code（PostToolUse 帶 tool_response，但 tool_response 結構各 hook 環境略異；保守做法：不依賴 exit code，只看命令）

jq -n '{ systemMessage: "[git-push-ci-reminder] git push detected -- consider /cicd-watch to track pipeline." }'
