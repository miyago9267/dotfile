#!/bin/bash
# _platform.sh -- 共用平台偵測與防呆
# Usage: . "$(dirname "$0")/_platform.sh"

_PLATFORM_OS="$(uname -s)"
_PLATFORM_DISTRO="unknown"
_PLATFORM_PKG=""

case "$_PLATFORM_OS" in
  Darwin)
    _PLATFORM_DISTRO="macos"
    command -v brew >/dev/null 2>&1 && _PLATFORM_PKG="brew"
    ;;
  Linux)
    if [ -f /etc/arch-release ]; then
      _PLATFORM_DISTRO="arch"
      _PLATFORM_PKG="pacman"
    elif [ -f /etc/debian_version ]; then
      _PLATFORM_DISTRO="debian"
      _PLATFORM_PKG="apt"
    else
      _PLATFORM_DISTRO="linux"
    fi
    ;;
esac

# 向後相容：部分 script 內部邏輯使用 OS_NAME
OS_NAME="$_PLATFORM_OS"

# platform_supported tag1 tag2 ...
# Tags: all, darwin, linux, linux:apt, linux:pacman
platform_supported() {
  for _ps_tag in "$@"; do
    case "$_ps_tag" in
      all)          return 0 ;;
      darwin)       [ "$_PLATFORM_OS" = "Darwin" ] && return 0 ;;
      linux)        [ "$_PLATFORM_OS" = "Linux" ] && return 0 ;;
      linux:apt)    [ "$_PLATFORM_DISTRO" = "debian" ] && return 0 ;;
      linux:pacman) [ "$_PLATFORM_DISTRO" = "arch" ] && return 0 ;;
    esac
  done
  return 1
}

# platform_guard "tool_name" tag1 tag2 ...
# Exit 0 if platform not supported (graceful skip)
platform_guard() {
  _pg_name="$1"; shift
  if ! platform_supported "$@"; then
    echo "[SKIP] $_pg_name: 當前平台不支援 ($_PLATFORM_OS/$_PLATFORM_DISTRO)"
    exit 0
  fi
}

# is_installed cmd
is_installed() { command -v "$1" >/dev/null 2>&1; }

# skip_installed "Tool Name"
skip_installed() { echo "[SKIP] $1: 已安裝"; exit 0; }
