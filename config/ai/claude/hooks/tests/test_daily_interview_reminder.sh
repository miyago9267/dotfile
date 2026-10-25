#!/usr/bin/env bash
# daily-interview-reminder.sh 的回歸測試：當天只提醒一次；今天已有 log 或目錄不存在則靜默。
set -u
HOOK=${HOOK:-"$(cd "$(dirname "$0")/.." && pwd)/daily-interview-reminder.sh"}
command -v jq >/dev/null 2>&1 || { echo "FAIL 需要 jq"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/pm/interviews"
export PERSONAL_MODEL_DIR="$T/pm" DAILY_INTERVIEW_STATE="$T/state/last"
fail=0
run() { echo '{}' | bash "$HOOK" 2>/dev/null; }
chk() { # name expect(msg|none) out
  if [ "$2" = msg ]; then printf '%s' "$3" | jq -e '.systemMessage|test("daily-interview")' >/dev/null 2>&1; else [ -z "$3" ]; fi || { echo "FAIL $1 out=$3"; fail=1; }
}
chk first msg "$(run)"
chk second none "$(run)"
rm -f "$T/state/last"; touch "$T/pm/interviews/$(date +%F).md"
chk has-log none "$(run)"
rm -f "$T/pm/interviews/"*; rm -f "$T/state/last"; export PERSONAL_MODEL_DIR="$T/missing"
chk no-dir none "$(run)"
[ $fail = 0 ] && echo "ok"; exit $fail
