#!/usr/bin/env bash
set -euo pipefail

# Only an explicit, structured user marker may create an observation. The raw
# hook payload is never forwarded to the harness and no transcript is stored.
input=$(cat)
prompt=$(jq -r '.user_prompt // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

case "$prompt" in
  '記住:'*) summary=${prompt#記住:} ;;
  '記住這個:'*) summary=${prompt#記住這個:} ;;
  '保留這個偏好:'*) summary=${prompt#保留這個偏好:} ;;
  'remember:'*) summary=${prompt#remember:} ;;
  *) exit 0 ;;
esac

summary=${summary# }
if [[ -z "$summary" || -z "$cwd" ]]; then
  exit 0
fi

MIYAGO_RUNTIME=claude \
  "${MIYAGO_CONTEXT_HARNESS_BIN:-$HOME/.local/bin/miyago-context-harness}" observe \
    --workspace-root "${MIYAGO_CONTEXT_HARNESS_ROOT:-$HOME/Project/AI/agent-workspace}" \
    --task personal-experience-autocapture \
    --cwd "$cwd" \
    --kind explicit_preference \
    --runtime claude \
    --scope "$cwd" \
    --source runtime_hook \
    --summary "$summary" \
    >/dev/null 2>&1 || true
