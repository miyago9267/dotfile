#!/usr/bin/env bash
# Claude Code on the web（雲端 session）專用：把 dotfile 的 Claude 設定接到 ~/.claude。
# 本機版 setup_claude.sh 會整個替換 ~/.claude/skills 等目錄；雲端的 ~/.claude 由 harness
# 預先放了 synced skills 與自己的 hooks，所以這裡逐項 link，settings.json 由本機版過濾產生。
# 用法：bash script/cloud/setup_claude_cloud.sh [DOTFILE_DIR]（預設 ~/dotfile）
set -uo pipefail

DF=${1:-$HOME/dotfile}
SRC=$DF/config/ai/claude
DST=$HOME/.claude
[ -d "$SRC" ] || { echo "cloud-setup: $SRC 不存在" >&2; exit 0; }
mkdir -p "$DST/skills" "$DST/agents" "$DST/commands"

# hooks 的 command 寫死 ~/dotfile，clone 在別處時補一個 link
[ "$DF" -ef "$HOME/dotfile" ] || ln -sfn "$DF" "$HOME/dotfile"

link() { # src dst：dst 是一般檔案或目錄時不動
  [ -e "$1" ] || return 0
  if [ -e "$2" ] && [ ! -L "$2" ]; then echo "cloud-setup: skip $2（非 symlink）" >&2; return 0; fi
  ln -sfn "$1" "$2"
}

# 規則：shared contract + personal model + Claude adapter（已產生、有版控）
link "$DF/config/ai/generated/claude/AGENTS.md" "$DST/CLAUDE.md"
for item in hooks scripts rules memories templates loop.md; do link "$SRC/$item" "$DST/$item"; done

# skills：逐個 link，斷掉的 link（指向本機外部路徑）略過
for s in "$SRC"/skills/*; do
  [ -e "$s" ] || continue
  [ -d "$s" ] || continue
  link "$(readlink -f "$s")" "$DST/skills/$(basename "$s")"
done

# agents：codex 需要本機 codex CLI，雲端不裝
for a in "$SRC"/agents/*.md; do
  [ "$(basename "$a")" = codex.md ] && continue
  link "$a" "$DST/agents/$(basename "$a")"
done
for c in "$SRC"/commands/*.md; do link "$c" "$DST/commands/$(basename "$c")"; done

# settings.json：只保留雲端可用的 hooks；不帶 model、permission 放寬、plugins、statusline
KEEP='persona-reminder|instructions-loaded-reminder|pre-bash|read-guard|suggest-compact'
KEEP+='|pre-compact-instructions|post-compact-reminder|subagent-stop-reminder'
KEEP+='|task-completed-reminder|git-push-ci-reminder|path-hint|zh-tw-guard|goal-handoff-guard'
if command -v jq >/dev/null 2>&1 && { [ ! -e "$DST/settings.json" ] || [ -L "$DST/settings.json" ] \
  || grep -q '"_generatedBy": "dotfile-cloud-setup"' "$DST/settings.json"; }; then
  jq --arg keep "$KEEP" '
    {
      _generatedBy: "dotfile-cloud-setup",
      env: (.env | {SHOAL_GUARD_LANG, CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS}),
      permissions: {deny: .permissions.deny, ask: .permissions.ask},
      effortLevel: .effortLevel,
      hooks: (.hooks
        | map_values(map(.hooks |= map(select(.command | test("hooks/(" + $keep + ")\\.(sh|py)"))))
                     | map(select(.hooks | length > 0)))
        | with_entries(select(.value | length > 0)))
    }' "$SRC/settings.json" > "$DST/settings.json.tmp" && mv "$DST/settings.json.tmp" "$DST/settings.json"
else
  echo "cloud-setup: 保留既有 settings.json" >&2
fi
echo "cloud-setup: done"
