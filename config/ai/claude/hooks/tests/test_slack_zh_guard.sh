#!/usr/bin/env bash
# slack-zh-guard.sh 的回歸測試：Slack 送出的訊息非台灣繁體中文回 deny，其餘無輸出。
# 指令只以 JSON 字串餵給 hook，不會被執行。HOOK 可用環境變數覆寫（teeth check 用）。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/slack-zh-guard.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
fail=0; n=0
run() { # name expect(deny|none) command
  n=$((n + 1))
  out=$(printf '%s' "$3" | jq -Rs '{tool_input:{command:.}}' | bash "$HOOK" 2>/dev/null); rc=$?
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  text=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
  ok=0
  if [ "$2" = none ]; then [ -z "$out" ] && ok=1; else [ "$dec" = "$2" ] && printf '%s' "$text" | grep -q '^slack zh guard:' && ok=1; fi
  [ $rc = 0 ] || ok=0
  [ $ok = 1 ] || { echo "FAIL $1 expect=$2 rc=$rc dec=$dec out=$out"; fail=1; }
}

# --- 被攔：英文或簡體 Slack 訊息 ---
run vigil_english deny 'agent-secret run security-slack -- sh -c '\''curl -s -X POST -H "Content-Type: application/json" --data "{\"text\":\"[vigil] GCP auth failed (first failure): no rules have run\"}" "$SECURITY_SLACK_WEBHOOK"'\'''
run simplified deny 'agent-secret run security-slack -- sh -c '\''curl -s --data "{\"text\":\"部署这个服务时出现问题\"}" "$SECURITY_SLACK_WEBHOOK"'\'''
run hooks_slack_english deny 'curl -X POST --data "{\"text\":\"deploy finished\"}" https://hooks.slack.com/services/T000/B000/XXXX'
run vigil_mixed_words deny 'agent-secret run security-slack -- sh -c '\''curl -s --data "{\"text\":\"[vigil] GCP 認證過期（first failure）：no rules have run since 01:13\"}" "$SECURITY_SLACK_WEBHOOK"'\'''

# --- 放行：中文為主，夾雜 IP、路徑與英文術語 ---
run pms_zh_allow none 'agent-secret run security-slack -- sh -c '\''curl -s --data "{\"text\":\"[PMS 監看] 23:16 PUSH：125.231.137.124（HiNet）用 python-httpx 打 chat-ari.mastripms.com，GET /api/hotels 122\"}" "$SECURITY_SLACK_WEBHOOK"'\'''
run vigil_triage_allow none 'agent-secret run security-slack -- sh -c '\''curl -s --data "{\"text\":\"[vigil] triage 失敗，改推原始列：lb-chat-ari-heavy count=218\"}" "$SECURITY_SLACK_WEBHOOK"'\'''

# --- 無關指令：無輸出（含 alias 字樣但沒有送出訊息 text） ---
run ls_none none 'ls'
run curl_example none 'curl https://example.com'
run grep_alias_none none 'grep -n security-slack ~/x.jsonl'
run agent_secret_script_none none 'agent-secret run security-slack -- python3 /path/send.py'

# --- stdin 不是預期格式：無輸出、exit 0 ---
for raw in '{"tool_input":{}}' 'not json'; do
  n=$((n + 1))
  out=$(printf '%s' "$raw" | bash "$HOOK" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ $rc = 0 ]; } || { echo "FAIL raw_input '$raw' rc=$rc out=$out"; fail=1; }
done

[ $fail = 0 ] && echo "all passed ($n cases)"; exit $fail
