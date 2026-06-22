#!/usr/bin/env bash
# UserPromptSubmit hook -- think-first router
# Heavy-task prompts -> inject a goal->step->verify + deep-reasoning directive.
# Adds context only via additionalContext; never rewrites the prompt. Fail-open.

set +e
INPUT=$(cat)

if command -v jq >/dev/null 2>&1 && printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
  PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty')
else
  PROMPT="$INPUT"
fi

[ -z "$PROMPT" ] && exit 0

HEAVY='implement|refactor|debug|architect|architecture|migrat|rewrite|overhaul|integrat|build (a|the|out)|實作|實現|重構|重寫|除錯|修.{0,3}bug|設計|架構|遷移|整合|改造|重新設計|全面'
TRIVIAL='typo|rename|錯字|拼字|改個|改一下|微調|小修|換行|格式|formatting|lint|註解|comment'

if printf '%s' "$PROMPT" | grep -iqE "$HEAVY"; then
  if printf '%s' "$PROMPT" | grep -iqE "$TRIVIAL" && [ "${#PROMPT}" -lt 80 ]; then
    exit 0
  fi
  CTX='Think-first protocol (heavy task detected): before acting, (1) restate this task as a verifiable success condition; (2) lay out a short plan as goal -> step -> verify; (3) raise reasoning depth now (ultrathink-level) and proceed carefully. For large multi-file / migration / audit scope, recommend /effort xhigh or ultracode to Miyago before starting -- his call, do not switch silently.'
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
  else
    printf '%s\n' "$CTX"
  fi
fi
exit 0
