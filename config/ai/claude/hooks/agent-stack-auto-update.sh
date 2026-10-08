#!/usr/bin/env bash

set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/miyago-agent-stack-updater"
LOG_FILE="$STATE_DIR/update.log"
STAMP_FILE="$STATE_DIR/last-check"
LOCK_DIR="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# Claude Code CLI 每次 session 啟動都向上游檢查，不受下面的每日 gate 限制；
# 只有版本變動或失敗才寫 log。新版本在下次啟動 claude 時生效。
update_claude_cli() {
  local before after
  command -v claude >/dev/null 2>&1 || return 0
  before=$(claude --version 2>/dev/null)
  if ! timeout 300 claude update >/dev/null 2>&1; then
    printf '%s\n' "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] claude cli update failed"
    return 1
  fi
  after=$(claude --version 2>/dev/null)
  if [ "$before" != "$after" ]; then
    printf '%s\n' "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] claude cli updated: $before -> $after"
  fi
}
update_claude_cli >>"$LOG_FILE" 2>&1

# 每個本地日曆日跑一次：今天還沒跑過就跑。原本的「距上次滿 24 小時」會讓
# 觸發時間每天往後漂，晚開 session 那天就整天跳過。
now=$(date +%s)
last=$(cat "$STAMP_FILE" 2>/dev/null || printf '0')
case "$last" in
  ''|*[!0-9]*) last=0 ;;
esac
if [ "$(date -r "$last" +%F 2>/dev/null || date -d "@$last" +%F)" = "$(date +%F)" ]; then
  exit 0
fi
printf '%s\n' "$now" > "$STAMP_FILE"

exec >>"$LOG_FILE" 2>&1
printf '%s\n' "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] checking agent stack updates"

latest_remora_tag() {
  curl -fsSL -H 'Accept: application/vnd.github+json' \
    https://api.github.com/repos/Nanako0129/remora-cc/releases/latest |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
}

latest_calico_asset() {
  curl -fsSL -H 'Accept: application/vnd.github+json' \
    'https://api.github.com/repos/Nanako0129/calico-claude/releases?per_page=100' |
    python3 -c '
import json, re, sys
releases = json.load(sys.stdin)
found = []
for release in releases:
    tag = release.get("tag_name", "")
    match = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)(?:-(\d+))?-macos-arm64", tag)
    if not match or release.get("draft"):
        continue
    version = tuple(int(x or 0) for x in match.groups())
    asset = next((a for a in release.get("assets", []) if a.get("name") == "claude.native.macos.patched"), None)
    if asset:
        found.append((version, tag, asset["browser_download_url"]))
if not found:
    raise SystemExit("no macOS arm64 Calico release found")
print("\t".join(max(found)[1:]))
'
}

update_remora() {
  local tag version tmp
  tag=$(latest_remora_tag) || return 1
  version=${tag#v}
  if [ "$(remora version 2>/dev/null || true)" = "remora $version" ]; then
    return 0
  fi
  tmp=$(mktemp)
  curl -fsSL "https://raw.githubusercontent.com/Nanako0129/remora-cc/$tag/bootstrap.sh" -o "$tmp"
  REMORA_VERSION="$version" sh "$tmp"
  rm -f "$tmp"
}

update_calico() {
  local metadata tag url tmp expected actual target
  metadata=$(latest_calico_asset) || return 1
  tag=${metadata%%$'\t'*}
  metadata=${metadata#*$'\t'}
  url=${metadata%%$'\t'*}
  target="$HOME/.local/bin/calico-claude"
  tmp=$(mktemp)
  curl -fsSL "$url" -o "$tmp"
  expected=$(curl -fsSL "https://github.com/Nanako0129/calico-claude/releases/download/$tag/checksums.txt" |
    awk '$2 == "claude.native.macos.patched" {print $1}')
  actual=$(shasum -a 256 "$tmp" | awk '{print $1}')
  [ -n "$expected" ] && [ "$expected" = "$actual" ] || return 1
  if command -v gh >/dev/null 2>&1; then
    gh attestation verify "$tmp" --repo Nanako0129/calico-claude \
      --signer-workflow Nanako0129/calico-claude/.github/workflows/patch-claude.yml >/dev/null || return 1
  else
    return 1
  fi
  chmod 0755 "$tmp"
  if [ -x "$target" ] && cmp -s "$tmp" "$target"; then
    return 0
  fi
  install -m 0755 "$tmp" "$target.new"
  mv -f "$target.new" "$target"
}

update_shoal() {
  # 從本機 shoal 的 committed HEAD（hosts/claude/dist）安裝，不裝未 commit 的 WIP。
  # SHOAL_ROOT 指向 shoal repo 根目錄。
  local src tmp root cfg skill
  src="${SHOAL_ROOT:-$HOME/Project/Active/Forks/Fork-Remaster-code/shoal}"
  git -C "$src" rev-parse --verify HEAD >/dev/null 2>&1 || return 1
  tmp=$(mktemp -d)
  git -C "$src" archive HEAD hosts/claude/dist | tar -x -C "$tmp" || return 1
  root="$tmp/hosts/claude/dist"
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  skill="$cfg/skills/shoal-orchestration"
  for name in scout Explore plan-verifier security-reviewer mech-executor executor verifier security-executor; do
    [ -f "$root/agents/$name.md" ] || return 1
  done
  for name in scout Explore plan-verifier security-reviewer mech-executor executor verifier security-executor; do
    install -m 0644 "$root/agents/$name.md" "$cfg/agents/$name.md"
  done
  # 舊名 skill 目錄（rebrand 前）已由 shoal-orchestration 取代，移除避免重複載入。
  rm -rf "$cfg/skills/pilotfish-orchestration"
  mkdir -p "$skill/references"
  for ref in "$root"/skills/shoal-orchestration/references/*.md; do
    install -m 0644 "$ref" "$skill/references/$(basename "$ref")"
  done
  # 完整 orchestration 放在按需載入的 skill，不再寫回常駐的 AGENTS.md。
  # 保留 dotfiles 自己的 frontmatter，只替換 marker 之間的內容。
  python3 - "$skill/SKILL.md" \
    "$root/skills/shoal-orchestration/SKILL.md" <<'PY'
import pathlib
import sys

target = pathlib.Path(sys.argv[1])
source = pathlib.Path(sys.argv[2]).read_text()
body = source.split("---", 2)[2].strip("\n")
replacement = "<!-- shoal:begin -->\n" + body + "\n<!-- shoal:end -->"
text = target.read_text()
begin = text.count("<!-- shoal:begin -->")
end = text.count("<!-- shoal:end -->")
if begin != 1 or end != 1:
    raise SystemExit("shoal markers are not exactly one pair")
start = text.index("<!-- shoal:begin -->")
finish = text.index("<!-- shoal:end -->", start) + len("<!-- shoal:end -->")
target.write_text(text[:start] + replacement + text[finish:])
PY
}

if update_remora; then
  printf '%s\n' 'remora update check passed'
else
  printf '%s\n' 'remora update failed'
fi
if update_calico; then
  printf '%s\n' 'calico update check passed'
else
  printf '%s\n' 'calico update failed'
fi
if update_shoal; then
  printf '%s\n' 'shoal update check passed'
else
  printf '%s\n' 'shoal update failed'
fi
# dispatch guard 由 shoal 安裝與註冊（docs/specs/dispatch-enforcement R7），只從 committed HEAD 取檔。
shoal_root="${SHOAL_ROOT:-$HOME/Project/Active/Forks/Fork-Remaster-code/shoal}"
if [ ! -d "$shoal_root/.git" ]; then
  printf '%s\n' "shoal checkout not found at $shoal_root; clone miyago9267/shoal there or set SHOAL_ROOT"
fi
if python3 "$shoal_root/tools/install_hooks.py" --host claude --apply >/dev/null 2>&1; then
  printf '%s\n' 'shoal guard update check passed'
else
  printf '%s\n' 'shoal guard update failed'
fi
# Codex、Grok、agy、OpenCode 的全域安裝同樣從 shoal committed HEAD 同步；
# 每個 host 一行摘要直接寫進 update.log，單一 host 失敗不影響其他步驟。
if sync_summary=$(PATH="$HOME/.bun/bin:$PATH" python3 "$shoal_root/tools/sync_global.py" --apply 2>&1); then
  printf '%s\n' "$sync_summary" | sed 's/^/shoal sync: /'
else
  printf '%s\n' 'shoal sync failed'
  printf '%s\n' "$sync_summary" | sed 's/^/shoal sync: /'
fi

# shoal 的 installer 寫的是絕對路徑，而 settings.json 在版控裡；改回可攜形式（docs/specs/portable-paths）。
python3 "${MIYAGO_DOTFILE_ROOT:-$HOME/dotfile}/script/common/portable_paths.py" --fix 2>&1 | sed 's/^/portable paths: /'

printf '%s\n' "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] update check complete"
