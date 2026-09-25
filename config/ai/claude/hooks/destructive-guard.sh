#!/bin/bash
# PreToolUse(Bash)：擋下不可逆的 local/git/DB 操作。
# 用 ask 和 ops-write-guard 一致：一般模式會跳確認，bypassPermissions 模式下不擋（Miyago 的選擇）。
# 取代原本的 safe-ops skill；kubectl/gcloud 由 ops-write-guard.sh 處理，git add 由 git-add-guard.sh 處理。
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

reason=""
sep='(^|[[:space:];&|`(])'
# 拿掉 git 全域參數（-C path、-c k=v、--git-dir= 等），讓 git -C x reset --hard 也比對得到
cmd=$(printf '%s' "$cmd" | sed -E ':a
s/(git)[[:space:]]+(-C|-c)[[:space:]]+[^[:space:];&|]+/\1/g
s/(git)[[:space:]]+(--git-dir|--work-tree|--namespace)=[^[:space:];&|]+/\1/g
s/(git)[[:space:]]+(--no-pager|--bare|-P)([[:space:]])/\1\3/g
ta')

# rm -rf / -fr，目標全部在 /tmp、/private/tmp 或 scratchpad 底下才放行
if printf '%s' "$cmd" | grep -qE "${sep}rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|-r[[:space:]]+-f|-f[[:space:]]+-r)"; then
  targets=$(printf '%s' "$cmd" | grep -oE "${sep}rm[[:space:]]+[^;&|]*" | sed -E 's/^[^r]*rm[[:space:]]+//' | tr ' ' '\n' | grep -vE '^-|^$' || true)
  bad=$(printf '%s\n' "$targets" | grep -vE '^("|'"'"')?(/tmp/|/private/tmp/|\$TMPDIR|/var/folders/)' | grep -v '^$' || true)
  [ -n "$bad" ] && reason="rm -rf 目標不在 temp 目錄：$(printf '%s' "$bad" | head -3 | tr '\n' ' ')"
fi

if [ -z "$reason" ]; then
  if printf '%s' "$cmd" | grep -qE "${sep}git[[:space:]]+reset[[:space:]]+[^;&|]*--hard"; then
    reason="git reset --hard 會丟掉未 commit 的變更"
  elif printf '%s' "$cmd" | grep -qE "${sep}git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f"; then
    reason="git clean -f 會刪掉 untracked 檔案"
  elif printf '%s' "$cmd" | grep -qE "${sep}git[[:space:]]+push([[:space:]][^;&|]*)?[[:space:]](--force([[:space:]]|=|$)|--force-with-lease|-f([[:space:]]|$)|\+[^[:space:]]+)"; then
    reason="force push 會改寫遠端歷史"
  elif printf '%s' "$cmd" | grep -qE "${sep}git[[:space:]]+push([[:space:]][^;&|]*)?[[:space:]](--delete|-d([[:space:]]|$)|:[^[:space:]]+)"; then
    reason="會刪除遠端分支或 tag"
  elif printf '%s' "$cmd" | grep -qiE '(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+table)'; then
    reason="DROP / TRUNCATE 會永久刪資料"
  elif printf '%s' "$cmd" | grep -qE "${sep}sudo([[:space:]]|$)"; then
    reason="規則禁止 sudo/root"
  fi
fi

[ -z "$reason" ] && exit 0
jq -n --arg r "destructive-guard: ${reason}。先向 Miyago 說明 target、影響範圍與 rollback。" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
