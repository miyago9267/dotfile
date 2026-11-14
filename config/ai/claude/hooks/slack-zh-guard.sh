#!/usr/bin/env bash

guard_slack_zh() {
  [[ $cmd == *security-slack* || $cmd == *hooks.slack.com* || $cmd == *SLACK_WEBHOOK* || $cmd == *chat.postMessage* ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  local verdict msg
  verdict=$(SLACK_CMD=$cmd python3 -c '
import os, re
cmd = os.environ.get("SLACK_CMD", "")
found = re.findall(r"\\?\"text\\?\"\s*:\s*\\?\"(.*?)\\?\"", cmd, re.S)
if not found:
    print("ok")
    raise SystemExit
t = " ".join(found)
t = re.sub(r"https?://\S+", " ", t)
t = re.sub(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", " ", t)
t = re.sub(r"\[[^\]]*\]", " ", t)
t = re.sub(r"`[^`]*`", " ", t)
t = re.sub(r"[A-Za-z0-9._~-]*/[A-Za-z0-9._/%-]*", " ", t)
t = re.sub(r"\b0x[0-9a-fA-F]+\b|\b[0-9a-fA-F]{8,}\b", " ", t)
t = re.sub(r"\d+(?:[.:]\d+)*", " ", t)
if any(c in "这们个说时对发过还么应将为实现问题数据无让务" for c in t):
    print("simplified")
else:
    cjk = len(re.findall(r"[\u4e00-\u9fff\u3400-\u4dbf]", t))
    words = sum(1 for w in re.findall(r"[A-Za-z0-9._/-]+", t) if re.fullmatch(r"[A-Za-z][a-z]+", w))
    print("english" if cjk == 0 or words > cjk else "ok")
' 2>/dev/null)
  case $verdict in
    simplified) msg="slack zh guard: Slack 訊息含簡體字，請改用台灣繁體中文（technical terms、IP、路徑、指令可保留英文）" ;;
    english) msg="slack zh guard: Slack 訊息主體不是台灣繁體中文，請改用台灣繁體中文（technical terms、IP、路徑、指令可保留英文）" ;;
    *) return 0 ;;
  esac

  jq -n --arg r "$msg" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $r
  }
}'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
  [ -z "$cmd" ] && exit 0
  guard_slack_zh
fi
