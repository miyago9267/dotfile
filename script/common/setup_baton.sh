#!/bin/bash
# baton 安裝腳本
# 1. 找到（或 clone）baton repo
# 2. symlink ~/.local/bin/baton
# 3. 安裝 Claude plugin baton@baton
# 4. 重新載入 tmux 設定（nvim-extension.conf 已 source-file 其 tmux 檔）

set -euo pipefail

BATON_DIR="${BATON_DIR:-$HOME/Project/Active/baton}"
CLAUDE_PLUGINS_JSON="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
BIN_DST="$HOME/.local/bin/baton"

Y='\033[1;33m'
G='\033[1;32m'
R='\033[1;31m'
N='\033[0m'

# repo 不存在就從 BATON_REPO clone（預設 GitHub private repo，需 SSH key）；失敗時提示後正常結束
BATON_REPO="${BATON_REPO:-git@github.com:miyago9267/baton.git}"
if [ ! -d "$BATON_DIR" ]; then
  mkdir -p "$(dirname "$BATON_DIR")"
  if git clone -q "$BATON_REPO" "$BATON_DIR"; then
    printf "${G}  [CLONE] baton -> %s${N}\n" "$BATON_DIR"
  else
    printf "${R}  [SKIP] baton -- 無法 clone %s${N}\n" "$BATON_REPO"
    printf "         確認 SSH key 有 GitHub 權限，或設定 BATON_REPO=<git url> 後重跑\n"
    exit 0
  fi
fi

BIN_SRC="$BATON_DIR/bin/baton"
if [ ! -e "$BIN_SRC" ]; then
  printf "${R}  [SKIP] baton -- 缺少 %s${N}\n" "$BIN_SRC"
  exit 0
fi

# baton symlink：冪等；非 symlink 的既有檔案不覆蓋
mkdir -p "$(dirname "$BIN_DST")"
if [ -L "$BIN_DST" ] && [ "$(readlink "$BIN_DST")" = "$BIN_SRC" ]; then
  printf "${G}  [OK]   baton symlink${N}\n"
elif [ -e "$BIN_DST" ] && [ ! -L "$BIN_DST" ]; then
  printf "${Y}  [WARN] %s 已存在且不是 symlink，未覆蓋${N}\n" "$BIN_DST"
else
  ln -sfn "$BIN_SRC" "$BIN_DST"
  printf "${G}  [LINK] baton -> %s${N}\n" "$BIN_SRC"
fi

# Claude plugin：以 installed_plugins.json 判斷是否已安裝
if command -v claude >/dev/null 2>&1; then
  if [ -f "$CLAUDE_PLUGINS_JSON" ] \
    && jq -e '.plugins["baton@baton"]' "$CLAUDE_PLUGINS_JSON" >/dev/null 2>&1; then
    printf "${G}  [OK]   Claude plugin baton 已安裝${N}\n"
  else
    claude plugin marketplace add "$BATON_DIR"
    claude plugin install baton@baton
    printf "${G}  [INSTALL] Claude plugin baton${N}\n"
  fi
else
  printf "${Y}  [SKIP] 找不到 claude CLI，略過 plugin 安裝${N}\n"
fi

# tmux 正在執行時重新載入設定；失敗不影響結果
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
fi
