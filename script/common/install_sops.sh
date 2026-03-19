#!/bin/bash
# 安裝 age 和 sops -- Secret 管理工具
set -e

Y="\033[1;33m"
G="\033[1;32m"
N="\033[0m"

# -- OS 檢查 --
OS_NAME="$(uname -s)"
case "$OS_NAME" in
  Darwin) echo "Detected: macOS" ;;
  Linux)
    if [ -f /etc/arch-release ]; then echo "Detected: Arch Linux"
    elif [ -f /etc/debian_version ]; then echo "Detected: Ubuntu/Debian"
    else echo "Detected: Linux (generic)"
    fi ;;
  *) echo "[WARN] sops 不支援當前 OS ($OS_NAME)，跳過"; exit 0 ;;
esac

# -- 已安裝檢查 --
if command -v age >/dev/null 2>&1 && command -v sops >/dev/null 2>&1; then
  exit 0
fi

echo "${Y}Installing age + sops...${N}"

if [ "$(uname)" = "Darwin" ]; then
  # macOS
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Please install Homebrew first."
    exit 1
  fi
  command -v age  >/dev/null 2>&1 || brew install age
  command -v sops >/dev/null 2>&1 || brew install sops

elif command -v pacman >/dev/null 2>&1; then
  # Arch Linux
  pkgs=""
  command -v age  >/dev/null 2>&1 || pkgs="$pkgs age"
  command -v sops >/dev/null 2>&1 || pkgs="$pkgs sops"
  if [ -n "$pkgs" ]; then
    sudo pacman -S --noconfirm $pkgs
  fi

elif command -v apt >/dev/null 2>&1; then
  # Ubuntu / Debian -- 從 GitHub release 下載 binary
  ARCH="$(dpkg --print-architecture)"

  if ! command -v age >/dev/null 2>&1; then
    AGE_VERSION="v1.2.1"
    AGE_URL="https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-${ARCH}.tar.gz"
    echo "下載 age ${AGE_VERSION}..."
    TMP="$(mktemp -d)"
    wget -qO "$TMP/age.tar.gz" "$AGE_URL"
    tar -xzf "$TMP/age.tar.gz" -C "$TMP"
    sudo install -m 755 "$TMP/age/age" /usr/local/bin/age
    sudo install -m 755 "$TMP/age/age-keygen" /usr/local/bin/age-keygen
    rm -rf "$TMP"
  fi

  if ! command -v sops >/dev/null 2>&1; then
    SOPS_VERSION="v3.9.4"
    SOPS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}"
    echo "下載 sops ${SOPS_VERSION}..."
    TMP="$(mktemp -d)"
    wget -qO "$TMP/sops" "$SOPS_URL"
    sudo install -m 755 "$TMP/sops" /usr/local/bin/sops
    rm -rf "$TMP"
  fi

else
  echo "${Y}警告: 不支援的作業系統，請手動安裝 age 和 sops${N}"
  echo "  age:  https://github.com/FiloSottile/age"
  echo "  sops: https://github.com/getsops/sops"
  exit 0
fi

echo "${G}age + sops 安裝完成${N}"
