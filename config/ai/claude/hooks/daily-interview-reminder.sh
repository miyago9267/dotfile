#!/usr/bin/env bash
# SessionStart hook: 今天還沒做 daily-interview 就提醒一次（每天最多一次）
# 狀態檔只存最後提醒日期；personal-model 目錄不存在則靜默略過

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
cat >/dev/null  # drain stdin (hook input not used)

PM_DIR="${PERSONAL_MODEL_DIR:-$HOME/Project/AI/agent-workspace/personal-model}"
STATE="${DAILY_INTERVIEW_STATE:-$HOME/.claude/state/daily-interview-last-reminded}"

[[ -d "$PM_DIR" ]] || exit 0

today=$(date +%F)
[[ -f "$PM_DIR/interviews/$today.md" ]] && exit 0
[[ "$(cat "$STATE" 2>/dev/null)" == "$today" ]] && exit 0

mkdir -p "$(dirname "$STATE")" 2>/dev/null && printf '%s\n' "$today" >"$STATE" 2>/dev/null
jq -n '{systemMessage: "[daily-interview] 今天還沒問答，想做就打 /daily-interview"}'
exit 0
