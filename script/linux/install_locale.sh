#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  elif require_cmd sudo; then
    sudo "$@"
  else
    echo "[ERROR] Need root privileges (run as root or install sudo)." >&2
    exit 1
  fi
}

if ! require_cmd apt-get; then
  echo "[ERROR] This script currently supports Debian/Ubuntu (apt-get)." >&2
  exit 1
fi

echo "[INFO] Installing locales package..."
run_as_root apt-get update -y
run_as_root apt-get install -y locales

# Ensure locale.gen exists
if [[ ! -f /etc/locale.gen ]]; then
  echo "[ERROR] /etc/locale.gen not found. locales package install may have failed." >&2
  exit 1
fi

# Enable commonly used UTF-8 locales
for loc in "zh_TW.UTF-8 UTF-8" "en_US.UTF-8 UTF-8"; do
  if grep -Eq "^[# ]*${loc//./\\.}$" /etc/locale.gen; then
    run_as_root sed -i -E "s|^[# ]*(${loc//./\\.})$|\\1|" /etc/locale.gen
  else
    echo "[INFO] Appending missing locale to /etc/locale.gen: $loc"
    echo "$loc" | run_as_root tee -a /etc/locale.gen >/dev/null
  fi
done

echo "[INFO] Generating locales..."
run_as_root locale-gen

# Set defaults (system-wide)
echo "[INFO] Setting system default locale (LANG=zh_TW.UTF-8)..."
run_as_root update-locale LANG=zh_TW.UTF-8

if [[ -f /etc/default/locale ]]; then
  run_as_root sed -i -E 's|^LANG=.*|LANG=zh_TW.UTF-8|' /etc/default/locale || true
else
  echo 'LANG=zh_TW.UTF-8' | run_as_root tee /etc/default/locale >/dev/null
fi

# Apply to current shell session (best-effort)
export LANG=zh_TW.UTF-8
unset LC_ALL || true

echo "[OK] Locale configured. You may need to re-login / restart your shell." 

echo "[INFO] Current locale summary:" 
locale || true