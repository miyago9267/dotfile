#!/bin/sh
set -e

OS_NAME="$(uname)"
if [ "$OS_NAME" = "Darwin" ]; then
  DEFAULT_ANDROID_HOME="$HOME/Library/Android/sdk"
  CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
else
  DEFAULT_ANDROID_HOME="$HOME/Android/Sdk"
  CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
fi

ANDROID_HOME="${ANDROID_HOME:-$DEFAULT_ANDROID_HOME}"
mkdir -p "$ANDROID_HOME"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "🔧 下載 Android Command-line Tools..."
curl -Lo "$TMP_DIR/cmdline-tools.zip" "$CMDLINE_URL"
unzip -q "$TMP_DIR/cmdline-tools.zip" -d "$TMP_DIR"
mkdir -p "$ANDROID_HOME/cmdline-tools"
rm -rf "$ANDROID_HOME/cmdline-tools/latest"
mv "$TMP_DIR/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
chmod +x "$ANDROID_HOME/cmdline-tools/latest/bin"/*

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [ -x "$SDKMANAGER" ]; then
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "platform-tools" >/dev/null 2>&1 || true
else
  echo "⚠️ 找不到 sdkmanager，可稍後手動執行" >&2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/setup_env_snippets.sh" ]; then
  "$SCRIPT_DIR/setup_env_snippets.sh" android
fi

echo "✅ Android SDK 就緒 (ANDROID_HOME=$ANDROID_HOME)"
