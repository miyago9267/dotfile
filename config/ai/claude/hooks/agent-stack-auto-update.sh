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
  # shoal 自己負責更新：匯出 committed HEAD、刷新 Claude 與 Codex 的本機 marketplace、plugin install/update、
  # 各 host 同步與 sha256 檢查（repo-layout P3）。這裡只呼叫它；SHOAL_ROOT 指向 shoal repo 根目錄。
  # 不含 git pull；Claude settings.json 的 ~ 還原留在這裡（portable_paths.py 與下面的 rewrite）。
  local src data mp out status
  src="${SHOAL_ROOT:-$HOME/Project/Active/Forks/Fork-Remaster-code/shoal}"
  [ -f "$src/tools/shoal_install.py" ] || return 1
  data="${XDG_DATA_HOME:-$HOME/.local/share}/shoal"
  mp="$data/claude-marketplace"
  out=$(PATH="$HOME/.bun/bin:$PATH" python3 "$src/tools/shoal_install.py" --update --apply 2>&1)
  status=$?
  printf '%s\n' "$out" | sed 's/^/shoal update: /'
  # CLI 會把絕對路徑寫進 settings.json（版控內），改回 ~ 形式；沒有可改的內容時什麼都不做。
  python3 - "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" "$mp" "$HOME" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1]).resolve()
mp, home = sys.argv[2], sys.argv[3]
if path.is_file() and mp.startswith(home + "/"):
    text = path.read_text()
    path.write_text(text.replace('"path": "%s"' % mp, '"path": "~%s"' % mp[len(home):]))
PY
  return "$status"
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
# dispatch guard 隨 Claude plugin 的 hooks 載入，不再用 install_hooks.py 註冊全域 guard。
shoal_root="${SHOAL_ROOT:-$HOME/Project/Active/Forks/Fork-Remaster-code/shoal}"
if [ ! -d "$shoal_root/.git" ]; then
  printf '%s\n' "shoal checkout not found at $shoal_root; clone miyago9267/shoal there or set SHOAL_ROOT"
fi
# Codex、Grok、agy、OpenCode 的全域同步已包含在 shoal_install.py --update 內（sync <host> 各一行）。

# shoal 的 installer 寫的是絕對路徑，而 settings.json 在版控裡；改回可攜形式（docs/specs/portable-paths）。
python3 "${MIYAGO_DOTFILE_ROOT:-$HOME/dotfile}/script/common/portable_paths.py" --fix 2>&1 | sed 's/^/portable paths: /'

printf '%s\n' "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] update check complete"
