#!/usr/bin/env bash
# SessionStart hook: 提醒 sre-inventory 是否過期或不存在
# 過期門檻 6h (SRE_INVENTORY_TTL 可覆寫，單位秒)

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
cat >/dev/null  # drain stdin (hook input not used)

INVENTORY_FILE="${SRE_INVENTORY_FILE:-$HOME/dotfile/.ai/sre-inventory.md}"
TTL="${SRE_INVENTORY_TTL:-21600}"  # 6h

if [[ ! -f "$INVENTORY_FILE" ]]; then
  jq -n --arg p "$INVENTORY_FILE" '{
    systemMessage: ("[sre-inventory] not found at " + $p + " -- run inventory-refresh.sh when convenient")
  }'
  exit 0
fi

if mtime=$(stat -f %m "$INVENTORY_FILE" 2>/dev/null); then :
elif mtime=$(stat -c %Y "$INVENTORY_FILE" 2>/dev/null); then :
else
  exit 0
fi

now=$(date +%s)
age=$((now - mtime))

if [[ $age -gt $TTL ]]; then
  hours=$((age / 3600))
  jq -n --arg h "$hours" '{
    systemMessage: ("[sre-inventory] stale (" + $h + "h old) -- run ~/dotfile/config/ai/claude/skills/sre-locate/scripts/inventory-refresh.sh when convenient")
  }'
fi

exit 0
