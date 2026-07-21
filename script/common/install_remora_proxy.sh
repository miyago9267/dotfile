#!/bin/bash
set -euo pipefail
. "$(dirname "$0")/_platform.sh"

# Remora + Calico + CLIProxyAPI(native, launchd) + aluo 官方轉發後端。
# 冪等；重跑安全。--force 只會重新產生 config.native.yaml。
#
# 為什麼 native + aluo：Docker Desktop VM 太吃資源；逆向 codex 來源 prefill 只有
# ~530 tok/s（40K context 冷啟 83s）。aluo 是 OpenAI-compatible 中轉、轉發官方
# gpt-5.6-sol/terra/luna，同樣 40K prefill 2.5s（~32x），且無 codex 的 cooldown /
# active-turn 問題。remora 的 role→model 調度完全不動，只換 CLIProxyAPI 上游來源。

platform_guard "Remora Proxy (CLIProxyAPI native + aluo)" darwin

export PATH="$HOME/.local/bin:$PATH"

DOTFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TPL="$DOTFILE_DIR/config/ai/claude/remora-proxy"

# --- 可用環境變數覆寫 ---
PROXY_DIR="${CLIPROXY_DIR:-$HOME/containers/cliproxyapi}"
CPA_VERSION="${CPA_VERSION:-7.2.71}"
REMORA_VERSION="${REMORA_VERSION:-0.1.13}"
REMORA_CFG="$HOME/.config/remora-cc/config.toml"
CALICO_BIN="$HOME/.local/bin/calico-claude"
PLIST="$HOME/Library/LaunchAgents/com.miyago.cliproxyapi.plist"
BIN="$PROXY_DIR/bin/cli-proxy-api"
CONFIG="$PROXY_DIR/config.native.yaml"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

mkdir -p "$PROXY_DIR/bin" "$PROXY_DIR/auths" "$PROXY_DIR/logs" \
         "$HOME/Library/LaunchAgents" "$HOME/.config/remora-cc" "$HOME/.local/bin"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] 缺少必要指令：$1" >&2
    exit 1
  }
}

verify_checksum() {
  local checksum_file="$1" artifact="$2" artifact_name="$3" expected actual
  expected="$(awk -v name="$artifact_name" '$2 == name { print $1 }' "$checksum_file")"
  [ -n "$expected" ] || {
    echo "[ERROR] checksum 找不到：$artifact_name" >&2
    exit 1
  }
  actual="$(shasum -a 256 "$artifact" | awk '{ print $1 }')"
  [ "$expected" = "$actual" ] || {
    echo "[ERROR] checksum 驗證失敗：$artifact_name" >&2
    exit 1
  }
}

install_remora_and_calico() {
  local claude_version calico_arch calico_tag tmp remora_archive calico_archive

  require_command claude
  require_command curl
  require_command gh
  require_command shasum
  require_command tar

  claude_version="$(claude --version | awk 'NR == 1 { print $1 }')"
  [ -n "$claude_version" ] || {
    echo "[ERROR] 無法取得 Claude Code 版本" >&2
    exit 1
  }
  case "$(uname -m)" in
    arm64|aarch64) calico_arch="arm64" ;;
    x86_64|amd64) calico_arch="x64" ;;
    *) echo "[ERROR] 不支援的 Calico 架構: $(uname -m)" >&2; exit 1 ;;
  esac
  calico_tag="v${claude_version}-macos-${calico_arch}"

  if is_installed remora && [ "$(remora version 2>/dev/null || true)" = "remora $REMORA_VERSION" ]; then
    echo "[SKIP] remora-cc: v$REMORA_VERSION 已就位"
  else
    tmp="$(mktemp -d)"
    remora_archive="$tmp/remora-cc-$REMORA_VERSION.tar.gz"
    download_installer "https://github.com/Nanako0129/remora-cc/releases/download/v${REMORA_VERSION}/remora-cc-${REMORA_VERSION}.tar.gz" "$remora_archive"
    download_installer "https://github.com/Nanako0129/remora-cc/releases/download/v${REMORA_VERSION}/checksums.txt" "$tmp/remora-checksums.txt"
    verify_checksum "$tmp/remora-checksums.txt" "$remora_archive" "remora-cc-${REMORA_VERSION}.tar.gz"
    gh attestation verify "$remora_archive" --repo Nanako0129/remora-cc >/dev/null
    tar xzf "$remora_archive" -C "$tmp"
    "$tmp/remora-cc-$REMORA_VERSION/install.sh"
    rm -rf "$tmp"
  fi

  if [ -x "$CALICO_BIN" ] && "$CALICO_BIN" --version 2>/dev/null | head -1 | grep -qx "$claude_version (Claude Code)"; then
    echo "[SKIP] Calico Claude: $claude_version 已就位"
  else
    tmp="$(mktemp -d)"
    calico_archive="$tmp/claude.native.macos.patched"
    download_installer "https://github.com/Nanako0129/calico-claude/releases/download/$calico_tag/claude.native.macos.patched" "$calico_archive"
    download_installer "https://github.com/Nanako0129/calico-claude/releases/download/$calico_tag/checksums.txt" "$tmp/calico-checksums.txt"
    verify_checksum "$tmp/calico-checksums.txt" "$calico_archive" "claude.native.macos.patched"
    gh attestation verify "$calico_archive" --repo Nanako0129/calico-claude >/dev/null
    install -m 0755 "$calico_archive" "$CALICO_BIN"
    xattr -dr com.apple.quarantine "$CALICO_BIN" 2>/dev/null || true
    rm -rf "$tmp"
    echo "[OK] Calico Claude: $claude_version"
  fi
}

install_remora_and_calico

# --- 1. CLIProxyAPI binary ---
if [ -x "$BIN" ] && ("$BIN" --help 2>&1 || true) | grep -q "Version: $CPA_VERSION"; then
  echo "[SKIP] CLIProxyAPI binary: v$CPA_VERSION 已就位"
else
  case "$(uname -m)" in
    arm64|aarch64) cpa_arch="aarch64" ;;
    x86_64|amd64)  cpa_arch="amd64" ;;
    *) echo "[ERROR] 不支援的架構: $(uname -m)"; exit 1 ;;
  esac
  url="https://github.com/router-for-me/CLIProxyAPI/releases/download/v${CPA_VERSION}/CLIProxyAPI_${CPA_VERSION}_darwin_${cpa_arch}.tar.gz"
  echo "下載 CLIProxyAPI v$CPA_VERSION ($cpa_arch)..."
  tmp="$(mktemp -d)"
  curl -fL -o "$tmp/cpa.tgz" "$url"
  tar xzf "$tmp/cpa.tgz" -C "$tmp" cli-proxy-api
  mv -f "$tmp/cli-proxy-api" "$BIN"
  chmod +x "$BIN"
  xattr -dr com.apple.quarantine "$BIN" 2>/dev/null || true
  rm -rf "$tmp"
  echo "binary → $BIN"
fi

# --- 2. secrets ---
# 2a. CLIProxyAPI client auth key（remora 透過 keychain remora-proxy-key 對應）
proxy_key="$(security find-generic-password -s remora-proxy-key -w 2>/dev/null || true)"
if [ -z "$proxy_key" ]; then
  proxy_key="$(openssl rand -base64 32)"
  security add-generic-password -U -s remora-proxy-key -a "$USER" -w "$proxy_key"
  echo "生成新的 remora-proxy-key 並寫入 keychain"
fi

# 2b. mgmt secret-key：沿用現有 config，否則生成
mgmt_key=""
if [ -f "$CONFIG" ]; then
  mgmt_key="$(grep -E 'secret-key:' "$CONFIG" | head -1 | sed -E 's/.*secret-key:[[:space:]]*"?([^"]*)"?.*/\1/')"
fi
[ -z "$mgmt_key" ] && mgmt_key="$(openssl rand -hex 24)"

# 2c. aluo api-key：env > opencode secrets > sops
resolve_aluo() {
  [ -n "${ALUO_API_KEY:-}" ] && { printf '%s' "$ALUO_API_KEY"; return 0; }
  local f="$HOME/.config/opencode/secrets/aluo-api-key"
  [ -f "$f" ] && { tr -d '\n' < "$f"; return 0; }
  if [ -f "$DOTFILE_DIR/secrets/tokens.enc.yaml" ] && command -v sops >/dev/null; then
    local v; v="$(sops -d --extract '["aluo_api_key"]' "$DOTFILE_DIR/secrets/tokens.enc.yaml" 2>/dev/null || true)"
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  fi
  return 1
}
if ! aluo_key="$(resolve_aluo)"; then
  echo "[ERROR] 找不到 aluo API key。請擇一設定："
  echo "  - export ALUO_API_KEY=..."
  echo "  - 寫入 ~/.config/opencode/secrets/aluo-api-key"
  echo "  - 加進 sops：secrets/tokens.enc.yaml 的 aluo_api_key"
  exit 1
fi

# --- 3. config.native.yaml（含 secret，不進 git；已存在則保留） ---
if [ -f "$CONFIG" ] && [ "$FORCE" = 0 ]; then
  echo "[SKIP] config.native.yaml 已存在（--force 可重新產生）"
else
  python3 - "$TPL/config.native.yaml.tmpl" "$CONFIG" "$PROXY_DIR" "$proxy_key" "$mgmt_key" "$aluo_key" <<'PY'
import sys
tpl, out, proxy_dir, pk, mk, ak = sys.argv[1:7]
s = open(tpl).read()
for a, b in [("__PROXY_DIR__", proxy_dir), ("__PROXY_API_KEY__", pk),
             ("__MGMT_SECRET_KEY__", mk), ("__ALUO_API_KEY__", ak)]:
    s = s.replace(a, b)
open(out, "w").write(s)
PY
  chmod 600 "$CONFIG"
  echo "config → $CONFIG"
fi

# --- 4. launchd plist（路徑注入） ---
python3 - "$TPL/com.miyago.cliproxyapi.plist.tmpl" "$PLIST" "$PROXY_DIR" <<'PY'
import sys
tpl, out, proxy_dir = sys.argv[1:4]
open(out, "w").write(open(tpl).read().replace("__PROXY_DIR__", proxy_dir))
PY
echo "plist → $PLIST"

# --- 5. remora config.toml（無 secret；dotfile 為唯一來源） ---
install -m 600 "$TPL/remora.config.toml" "$REMORA_CFG"
echo "remora config → $REMORA_CFG"

# --- 6. 啟動 launchd ---
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"
if curl -s -o /dev/null --retry-connrefused --retry 25 --retry-delay 1 --max-time 45 http://127.0.0.1:8317; then
  echo "[OK] proxy 已啟動 (127.0.0.1:8317)"
else
  echo "[ERROR] proxy 未就緒，檢查 $PROXY_DIR/logs/launchd.err.log"
  exit 1
fi

# --- 7. 驗證 ---
remora doctor --online 2>&1 | grep -E 'PASS|FAIL|WARN|proxy endpoint|context policy' | tail -24 || true

echo "[DONE] Remora proxy (aluo backend) 就緒"
